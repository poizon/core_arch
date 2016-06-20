#!/usr/bin/perl
use strict;
use utf8;
use Time::HiRes qw/time/;
use Net::IDN::Encode ':all';

=head1 NAME

migrate.pl - Database migration script

=head1 DESCRIPTION

Copy data from old database to new one with changing data structure during copying.

=head1 SYNOPSIS

  ./migrate.pl [options]

=head1 OPTIONS

=over 4

=item B<--from-dsn> DSN

=item B<--to-dsn>   DSN

=item B<--from-user> username

=item B<--to-user>   username

=item B<--from-password> pa$$w0rd

=item B<--to-password>   pa$$w0rd

Override Data Source Names (DSN), usernames or passwords for databases

=item B<-s> path, B<--src> path, B<--source> path

=item B<-d> path, B<--dst> path, B<--destination> path

Copy photos from C<source> to C<destination>.

Default values are C<foto> and C<public/gallery> respectively.

=item B<-e>, B<--empty-tables>

Empty existing tables in new database before migration starts

=item B<-?>, B<-h>, B<--help>,

Print a brief help message and exit.

=item B<-m>, B<--man>, B<--manual>

Prints the manual page and exit.

=item B<-v>, B<--verbose>

Be verbose.

=item B<--timing>

Enable timing.

=back

=cut

# prototype
sub print_items_found_if_verbose($$$);

use DBI;
use File::Copy;
use File::Path 'make_path';
use Dancer::Serializer::JSON;
use PHP::Serialization::XS qw/unserialize/;
use HTML::Entities qw/decode_entities/;

# Customization via cli
use Getopt::Long;

# Default values
my $from_dsn = 'DBI:mysql:okis';
my   $to_dsn = 'DBI:mysql:okis2';

map { $_ = 'root' } my (
    $from_user, $from_password,
      $to_user,   $to_password,
);

my $src_path = 'foto';
my $dst_path = 'public/gallery';

my $src_store_path = 'store';
my $dst_store_path = 'public/store';


map { $_ = '' } my (
    $empty_tables,
    $need_help, $need_manual, $verbose, $timing
);

my $exchange_rate = 28;

GetOptions(
	'from-dsn=s'      => \$from_dsn,
	  'to-dsn=s'      =>   \$to_dsn,
	'from-user=s'     => \$from_user,
	  'to-user=s'     =>   \$to_user,
	'from-password=s' => \$from_password,
	  'to-password=s' =>   \$to_password,

	     'source|src=s' => \$src_path,
	'destination|dst=s' => \$dst_path,

	     'source_store|srcs=s' => \$src_store_path,
	'destination_store|dsts=s' => \$dst_store_path,

    'empty-tables'    => \$empty_tables,

    'exchange-rate'    => \$exchange_rate,

    'help|?'  => \$need_help,
    'manual'  => \$need_manual,
    'verbose' => \$verbose,
    'timing'  => \$timing
);

use Pod::Usage qw( pod2usage );
pod2usage(1)
    if $need_help;
pod2usage('verbose' => 2)
    if $need_manual;


# Payload
$|=1 && print 'Connecting... ' if $verbose;
my $old = DBI->connect($from_dsn, $from_user, $from_password)
	or die 'Can not connect to DB: ' . DBI->errstr;
$old->{'mysql_enable_utf8'} = 1;
$old->do('SET NAMES utf8');

my $new = DBI->connect(  $to_dsn,   $to_user,   $to_password)
	or die 'Can not connect to DB: ' . DBI->errstr;
$new->{'mysql_enable_utf8'} = 1;
$new->do('SET NAMES utf8');
$new->do('SET FOREIGN_KEY_CHECKS = 0');

print "OK\n" if $verbose;
#my $total_time = time();

# Truncate tables
# see http://stackoverflow.com/questions/8641703/how-do-i-truncate-tables-properly
if ( $empty_tables ) {
	print 'Truncating tables: ' if $verbose;
	map {
		$new->do(
			q{
				TRUNCATE TABLE
			}
			. $new->quote_identifier($_)
		);
		print "$_ " if $verbose;
	} qw(
		sites_meta       sites
		blog_comments    blog_posts
		forum_posts      forum_topics
		pages            pages_folders
		gallery_photos   gallery_albums
		payments         payments_domains
		domains          domains_queue    domains_reg
		affiliate_stat   affiliate_users  affiliate_sites
		form_info        form_questions   form_question_options
		store_item       store_item_param store_item_param_value
		store_item_more  store_item_info  store_coupon     store_item_photo
		store_category   store_order      store_order_item store_checkout
		store_order_data store_category_relations
		users events menu news blocks
	);
	print "\n" if $verbose;
}

my $sth = $old->prepare(
	q{
		SELECT *
		FROM site 
		LEFT JOIN store USING (domainid)
		ORDER BY count DESC, id
	}
);

$sth->execute;

while (my $site = $sth->fetchrow_hashref) {
	# Iterate sites

	next if $site->{domen} eq 'okis.ru';
	next unless $site->{email};
	my $user_email = lc($site->{email});
	$user_email =~ s/\s+//g;
	my $time = time();

	# old.site.pid can be 0
	my $affiliate_id = $site->{pid} || 0;
	$new->do(
		q{
			INSERT INTO affiliate_users
			(affiliate_id, email, password, regdate)
			VALUES (?, ?, ?, ?)
		},
		{},
		$site->{id}, $user_email, $site->{password},
			$site->{regdate},
	);

	my $site_id = 0;

	# Search for existing user by email
	my $user_id = 0;
	unless ($user_id = $new->selectrow_array(
			q{
				SELECT user_id
				  FROM users
				 WHERE email = ?
			},
			{},
			$user_email,
		)
	) {
		# Create new user when he not exists
		$new->do(
			q{
				INSERT INTO users
				(email, password, lang, regdate,
					affiliate_id, tz, balance)
				VALUES (?, ?, ?, ?, ?, ?, ?)
			},
			{},
			$user_email, $site->{password}, 'ru', $site->{regdate},
				$affiliate_id || undef, 'Europe/Moscow', sprintf("%.2f", $site->{balans} / $exchange_rate),
		);
		$user_id = $new->last_insert_id(undef, undef, undef, undef);
	} # if new user

	my $domainid = $site->{domainid};

	# All templates that not in [300, 504] go to 349 template
	my $shablon = $site->{shablon};
	$shablon = 349 if !$site->{shablon} || $site->{shablon} > 504 || $site->{shablon} < 300;

	# Create site
	$new->do(
		q{
			INSERT INTO sites
			(user_id, regdate, template, title, subtitle,
				sharing_widget, noads, meta_header, default_page,
				store_currency, css, stat_tracking, paid_till, package)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, "index.html", ?, ?, ?, FROM_UNIXTIME(?), ?)
		},
		{},
		$user_id, $site->{regdate}, "okis/$shablon",
			$site->{tel} // '', $site->{slogon} // '',
			$site->{social}, $site->{noads}, $site->{meta} // '',
			$site->{currency} // '', $site->{css},
			$site->{counters} // '', $site->{hosting} || 0, $site->{hosting} ? 'Pro' : ''
	);

	$site_id = $new->last_insert_id(undef, undef, undef, undef);

	printf
		"%7d. %s created for user %s\n",
		$site_id, $site->{domen}, $user_id
		if $verbose;

	# Store more fields to sites_meta
	$new->do(
		q{
			INSERT INTO sites_meta
			(site_id, html, advTop, advBottom, advNews, advMenu)
			VALUES (?, ?, ?, ?, ?, ?)
		},
		{},
		$site_id, $site->{template} // '', $site->{advTop},
			$site->{advBottom}, $site->{advNews}, $site->{advMenu},
	);

	$site->{domen} =~ s/^\s+|\s+$//g;
	# Create domain
	$new->do(
		q{
			INSERT INTO domains
			(site_id, ascii, unicode)
			VALUES (?, ?, ?)
		},
		{},
		$site_id, $site->{domen}, domain_to_unicode($site->{domen})
	);

	my $domain_id = $new->last_insert_id(undef, undef, undef, undef);

	# and store it as default domain for site
	$new->do(
		q{
			UPDATE sites
			   SET default_domain = ?
			 WHERE site_id = ?
		},
		{},
		$domain_id, $site_id,
	);

	# Folder
	my $folders = $old->selectall_arrayref(
		q{
			SELECT *
			  FROM folders
			 WHERE domainid = ?
			 ORDER BY id
		},
		{ Slice => {} },
		$domainid,
	);

	print_items_found_if_verbose $folders, 'folders', $time if $verbose;

	my $folders_insert = q{
		INSERT INTO pages_folders
		(site_id, title)
		VALUES
	};
	$folders_insert .= join(',', ('(?, ?)') x @$folders);

	my @folders_insert_values = ();
	foreach my $folder ( @$folders ) {
		push(@folders_insert_values,
			$site_id, $folder->{title} // '',
		);
	} # foreach folder
	$new->do($folders_insert, {}, @folders_insert_values) if @$folders;

	my $new_folders = $new->selectall_arrayref(
		q{
			SELECT *
			  FROM pages_folders
			 WHERE site_id = ?
		},
		{ Slice => {} },
		$site_id,
	);

	# map old.folder.title to new.folder.folder_id
	my %folder_id_by_title = map { $_->{title} => $_->{folder_id}} @$new_folders;


	### Gallery
	# albums
	my $gallery_album_list = $old->selectall_arrayref(
		q{
			SELECT *
			  FROM gallery_album
			 WHERE domainid = ?
			 ORDER BY album_id
		},
		{ Slice => {} },
		$domainid,
	);

	print_items_found_if_verbose $gallery_album_list, 'gallery albums', $time if $verbose;

	my %dst_path_by_new_album_id = ();

	my $src_full_path = "$src_path/$domainid";
	   $src_full_path =~ s/_F$//;

	my $gallery_album_insert = q{
		INSERT INTO gallery_albums
		(album_id, site_id, title)
		VALUES
	};
	$gallery_album_insert .= join(',', ('(?, ?, ?)') x @$gallery_album_list);

	my @gallery_album_insert_values = ();
	foreach my $gallery_album ( @$gallery_album_list ) {
		push(@gallery_album_insert_values,
			$gallery_album->{album_id},
			$site_id,
			decode_entities($gallery_album->{title} // ''),
		);

		# Make dir for album
		if ( -d $src_full_path ) {
			my  $dst_full_path = join
				'/',
				$dst_path,
				split('', sprintf('%03d', substr $site_id, 0, 3)),
				$site_id,
				$gallery_album->{album_id};

			make_path $dst_full_path;
			$dst_path_by_new_album_id{ $gallery_album->{album_id} } = $dst_full_path;
		}
	} # foreach gallery_album
	$new->do($gallery_album_insert, {}, @gallery_album_insert_values) if @$gallery_album_list;

	if ( scalar(@$gallery_album_list) ) {
		# photos
		my $gallery_photos = $old->selectall_arrayref(
			q{
				SELECT *
				  FROM gallery_photo
				 WHERE domainid = ?
				 ORDER BY photo_id
			},
			{ Slice => {} },
			$domainid,
		);
	
		print_items_found_if_verbose $gallery_photos, 'gallery photos', $time if $verbose;
	
		my %new_photo_id_by_old_one  = (); # map old photo_id to new one
	
		foreach my $gallery_photo ( @$gallery_photos ) {
			$new->do(
				q{
					INSERT INTO gallery_photos
					(site_id, filename, title, album_id, sort)
					VALUES (?, ?, ?, ?, ?)
				},
				{},
				$site_id,
					$gallery_photo->{filename} // '',
					decode_entities($gallery_photo->{title} // ''),
					$gallery_photo->{album_id} // 0,
					$gallery_photo->{sort} // 0
			);
			$new_photo_id_by_old_one{ $gallery_photo->{photo_id} }
				= $new->last_insert_id(undef, undef, undef, undef);
	
			# Copy photos
			my $dst_full_path = $dst_path_by_new_album_id{ $gallery_photo->{album_id} // 0 };
			copy
				"$src_full_path/" . $gallery_photo->{filename},
				"$dst_full_path/" . $gallery_photo->{filename}
				if -f "$src_full_path/" . $gallery_photo->{filename};
		} # foreach gallery_photo

		# process cover_id
		foreach my $gallery_album ( @$gallery_album_list ) {
			$new->do(
				q{
					UPDATE gallery_albums
					   SET cover_id = ?
					 WHERE album_id = ?
				},
				{},
				$new_photo_id_by_old_one{ $gallery_album->{cover_id} } // 0,
					$gallery_album->{album_id},
			);
		} # while iterate %hash
	}


	# Menu
	my $menu_list = $old->selectall_arrayref(
		q{
			SELECT *
			  FROM menu
			 WHERE domainid = ?
			 ORDER BY id
		},
		{ Slice => {} },
		$domainid,
	);

	print_items_found_if_verbose $menu_list, 'menu items', $time if $verbose;

	my %menu_id_by_id = (); # map old.menu.id to new.menu.menu_id

	foreach my $menu ( @$menu_list ) {
		next if $menu->{sub} && !$menu_id_by_id{ $menu->{sub} };
		my $url = $menu->{url} || '';
		$url =~ s/^\s+//;
		$url =~ s/\s+$//;
		$url = '/' . $url if $url =~ /\.html$/ && $url !~ /^(\/|http)/;
		$new->do(
			q{
				INSERT INTO menu
				(site_id, parent_id, url, title)
				VALUES (?, ?, ?, ?)
			},
			{},
			$site_id,
				$menu_id_by_id{ $menu->{sub} } // 0,
				$url,
				$menu->{txt} // '',
		);
		$menu_id_by_id{ $menu->{id} } = $new->last_insert_id(undef, undef, undef, undef);
	} # foreach menu


	# News
	my $news_list = $old->selectall_arrayref(
		q{
			SELECT id, title, text, data, anons
			  FROM news
			 WHERE domainid = ?
			 ORDER BY id
		},
		{ Slice => {} },
		$domainid,
	);

	print_items_found_if_verbose $news_list, 'news', $time if $verbose;

	my $news_insert = q{
		INSERT INTO news
		(news_id, site_id, date, title, body, preview)
		VALUES
	};
	$news_insert .= join(',', ('(?, ?, ?, ?, ?, ?)') x @$news_list);

	my @news_insert_values = ();
	foreach my $news ( @$news_list ) {
		push(@news_insert_values,
			$news->{id}, $site_id, $news->{data},
			$news->{title} // '', $news->{text} // '', $news->{anons} || undef
		);
	} # foreach news
	$new->do($news_insert, {}, @news_insert_values) if @$news_list;

	# Pages
	my $pages = $old->selectall_arrayref(
		q{
			SELECT page, h1, title, body, dir, keywords, descriptions
			  FROM pages
			 WHERE domainid = ?
			 ORDER BY id
		},
		{ Slice => {} },
		$domainid,
	);

	print_items_found_if_verbose $pages, 'pages', $time if $verbose;

	while ( my @pages_chunk = splice(@$pages, 0, 100) ) {
		my $pages_insert = q{
			INSERT INTO pages
			(site_id, meta_title, title, url, body, folder_id, meta_keywords, meta_description)
			VALUES
		};
		$pages_insert .= join(',', ('(?, ?, ?, ?, ?, ?, ?, ?)') x @pages_chunk);

		my @pages_insert_values = ();
		foreach my $page ( @pages_chunk ) {
			push(@pages_insert_values,
				$site_id,
				$page->{title}, 
				$page->{h1},
				$page->{page}, 
				$page->{body} // '',
				$folder_id_by_title{ $page->{dir} },
				$page->{keywords},
				$page->{descriptions}
			);
		}
		$new->do($pages_insert, {}, @pages_insert_values);
	}


	######### Store

	my $src_store_full_path = "$src_store_path/$domainid";
	   $src_store_full_path =~ s/_F$//;

	# Make dir for store pics
	my $dst_store_full_path = '';
	if ( -d $src_store_full_path ) {
		$dst_store_full_path = join
			'/',
			$dst_store_path,
			split('', sprintf('%03d', substr $site_id, 0, 3)),
			$site_id;

		make_path $dst_store_full_path;
	}

	# categories
	my $store_categories = $old->selectall_arrayref(
		q{
			SELECT *
			  FROM store_category
			 WHERE domainid = ?
			 ORDER BY category_id
		},
		{ Slice => {} },
		$domainid,
	);

	print_items_found_if_verbose $store_categories, 'store categories', $time if $verbose;
	next unless scalar(@$store_categories);

	my $store_categories_insert = q{
		INSERT INTO store_category
		(category_id, site_id, title, body, cover, hidden)
		VALUES
	};
	$store_categories_insert .= join(',', ('(?, ?, ?, ?, ?, ?)') x @$store_categories);

	my @store_categories_insert_values = ();
	foreach my $store_category ( @$store_categories ) {
		push(@store_categories_insert_values,
			$store_category->{category_id},
			$site_id,
			#$store_category->{parent_id} // 0,
			$store_category->{title} // '',
			$store_category->{text} // '',
			$store_category->{image} // '',
			1 - $store_category->{active},
		);
	} # foreach store_category
	$new->do($store_categories_insert, {}, @store_categories_insert_values) if @$store_categories;

	foreach my $store_category ( @$store_categories ) {
		my $filename = $store_category->{image} // '';
		copy
			"$src_store_full_path/$filename",
			"$dst_store_full_path/$filename"
			if -f "$src_store_full_path/$filename";
	} # foreach store_category
	
	# item photo
	my $store_item_photos = $old->selectall_arrayref(
		q{
			SELECT *
			  FROM store_item_photo
			 WHERE domainid = ?
			 ORDER BY sort, photo_id
		},
		{ Slice => {} },
		$domainid,
	);

	print_items_found_if_verbose $store_item_photos, 'store item photos', $time if $verbose;

	my $store_photos_insert = q{
		INSERT INTO store_item_photo
		(item_id, filename)
		VALUES
	};

	my $items_covers = {};
	my $item_photo_cnt = 0;
	my @store_photos_insert_values = ();
	foreach my $store_item_photo ( @$store_item_photos ) {
		my $item_id = $store_item_photo->{item_id} // 0;
		if ($items_covers->{$item_id}) {
			push(@store_photos_insert_values,
				$item_id,
				$store_item_photo->{filename} // '',
			);
			$item_photo_cnt++;
		}
		else {
			$items_covers->{$item_id} = $store_item_photo->{filename} // '';
		}
	} # foreach store_item_photo
	$store_photos_insert .= join(',', ('(?, ?)') x $item_photo_cnt);
	$new->do($store_photos_insert, {}, @store_photos_insert_values) if $item_photo_cnt;

	$src_store_full_path .= '/original';
	foreach my $store_item_photo ( @$store_item_photos ) {
		my $filename = $store_item_photo->{filename} // '';
		copy
			"$src_store_full_path/$filename",
			"$dst_store_full_path/$filename"
			if -f "$src_store_full_path/$filename";
	} # foreach store_item_photo

	# items
	my $store_items = $old->selectall_arrayref(
		q{
			SELECT *
			  FROM store_item
			 WHERE domainid = ?
				AND category_id > 0
			 ORDER BY item_id
		},
		{ Slice => {} },
		$domainid,
	);

	print_items_found_if_verbose $store_items, 'store items', $time if $verbose;
	next unless scalar(@$store_items);

	my $store_items_insert = q{
		INSERT INTO store_item
		(item_id, site_id, title,
			cover, description, body,
			price, price_sale, hidden, sort)
		VALUES
	};
	$store_items_insert .= join(',', ('(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)') x @$store_items);

	my @store_items_insert_values = ();
	foreach my $store_item ( @$store_items ) {
		my $price_sale = $store_item->{price_sale} // 0;
		push(@store_items_insert_values,
			$store_item->{item_id},
			$site_id,
			decode_entities($store_item->{title} // ''),
			$items_covers->{ $store_item->{item_id} } // '',
			decode_entities($store_item->{description} // ''),
			decode_entities($store_item->{text} // ''),
			$store_item->{price} // 0,
			$price_sale eq '0.00' ? undef : $price_sale,
			1 - $store_item->{active},
			$store_item->{sort} // 0,
		);
	} # foreach store_item
	$new->do($store_items_insert, {}, @store_items_insert_values) if @$store_items;
	
	# item info
	my $store_item_infos = $old->selectall_arrayref(
		q{
			SELECT *
			  FROM store_item_info
			 WHERE domainid = ?
			 ORDER BY sort
		},
		{ Slice => {} },
		$domainid,
	);

	print_items_found_if_verbose $store_item_infos, 'store item infos', $time if $verbose;

	my $store_infos_insert = q{
		INSERT INTO store_item_info
		(item_id, name, value)
		VALUES
	};
	$store_infos_insert .= join(',', ('(?, ?, ?)') x @$store_item_infos);

	my @store_infos_insert_values = ();
	foreach my $store_item_info ( @$store_item_infos ) {
		push(@store_infos_insert_values,
			$store_item_info->{item_id} // 0,
			$store_item_info->{name}  // '',
			$store_item_info->{value} // '',
		);
	} # foreach store_item_info
	$new->do($store_infos_insert, {}, @store_infos_insert_values) if @$store_item_infos;

	my $store_catrel_insert = q{
		INSERT INTO store_category_relations
		(category_id, item_id)
		VALUES
	};

	my $category_relations = 0;
	my @store_catrel_insert_values = ();
	foreach my $store_item ( @$store_items ) {
		next unless $store_item->{category_id};
		$category_relations++;
		push(@store_catrel_insert_values,
			$store_item->{category_id},
			$store_item->{item_id}
		);
	} # foreach store_item
	$store_catrel_insert .= join(',', ('(?, ?)') x $category_relations);
	$new->do($store_catrel_insert, {}, @store_catrel_insert_values) if @store_catrel_insert_values;
	
	# Set redirect if show_index option is true
	$new->do("INSERT INTO redirects SET site_id = ?, source = ?, destination = ?", undef,
		$site_id, "/", "/store") if $site->{show_index};

	# coupons
	my %coupon_id_by_promocode_id = (); # map old.store_promocode.promocode_id to new.store_coupon.coupon_id
	my $store_promocodes = $old->selectall_arrayref(
		q{
			SELECT *
			  FROM store_promocode
			 WHERE domainid = ?
			 ORDER BY promocode_id
		},
		{ Slice => {} },
		$site->{domen},
	);

	print_items_found_if_verbose $store_promocodes, 'store promocodes/coupons', $time if $verbose;

	foreach my $store_promocode ( @$store_promocodes ) {
		$new->do(
			q{
				INSERT INTO store_coupon
				(site_id, code, limit, used, date_start, date_end, title)
				VALUES (?, ?, ?, ?, ?, ?, ?)
			},
			{},
			$site_id,
				$store_promocode->{code},
				$store_promocode->{limit},
				$store_promocode->{used},
				$store_promocode->{date_start},
				$store_promocode->{date_end},
				$store_promocode->{code},
		);
		$coupon_id_by_promocode_id{ $store_promocode->{promocode_id} }
			= $new->last_insert_id(undef, undef, undef, undef);

	} # foreach store_coupon

	if ( scalar(@$store_promocodes) ) {
		# promocode/coupon rules
		my $store_promocode_rules = $old->selectall_arrayref(
			q{
				SELECT *
				  FROM store_promocode_rule
				 WHERE domainid = ?
				  AND sale > 0
				  AND type in (1, 3)
				 ORDER BY rule_id
			},
			{ Slice => {} },
			$domainid,
		);

		print_items_found_if_verbose $store_promocode_rules, 'store promocode/coupon rules', $time if $verbose;

		foreach my $store_promocode_rule ( @$store_promocode_rules ) {
			my $type = $store_promocode_rule->{type};
			$type = 2 if $store_promocode_rule->{type} == 3;

			$new->do(
				q{
					UPDATE store_coupon
					  SET type = ?, discount = ?
					 WHERE coupon_id = ?
				},
				# backticks around limit are required to prevent syntax error
				{},
				$type,
					$store_promocode_rule->{sale},
					$coupon_id_by_promocode_id{ $store_promocode_rule->{promocode_id} } // 0,
			);
		} # foreach store_promocode_rule
	}

	# orders
	my $store_orders = $old->selectall_arrayref(
		q{
			SELECT *
			  FROM store_order
			 WHERE domainid = ?
			 ORDER BY order_id
		},
		{ Slice => {} },
		$domainid,
	);

	print_items_found_if_verbose $store_orders, 'store orders', $time if $verbose;

	my %new_order_id_by_old_one  = (); # map old order_id to new one

	my $ru = {
		name    => 'Имя',
		address => 'Адрес',
		comment => 'Комментарий',
	};
	foreach my $store_order ( @$store_orders ) {
		my $data = { map { $ru->{$_} => $store_order->{$_} } grep { $store_order->{$_} } keys %$ru };
		$data = $data ? Dancer::Serializer::JSON::to_json($data, { pretty => 0 }) : '';
		$new->do(
			q{
				INSERT INTO store_order
				(site_id, email, phone, data, qty, amount,
					promocode_id, promocode, promocode_discount,
					date, status)
				VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
			},
			{},
			$site_id,
				$store_order->{email},
				$store_order->{phone},
				$data,
				$store_order->{qty},
				$store_order->{amount},
				$coupon_id_by_promocode_id{ $store_order->{promocode_id} } // 0,
				$store_order->{promocode},
				$store_order->{promocode_discount},
				$store_order->{date},
				$store_order->{status} + 1,
		);
		$new_order_id_by_old_one{ $store_order->{order_id} }
			= $new->last_insert_id(undef, undef, undef, undef);
	} # foreach store_order

	# order items
	if ( scalar(@$store_orders) ) {
		my $store_order_items = $old->selectall_arrayref(
			q{
				SELECT *
				  FROM store_order_item
				 WHERE domainid = ?
				 ORDER BY id
			},
			{ Slice => {} },
			$domainid,
		);

		print_items_found_if_verbose $store_order_items, 'store order items', $time if $verbose;

		my $store_order_insert = q{
			INSERT INTO store_order_item
			(order_id, item_id, title, description, params, price, qty)
			VALUES
		};
		$store_order_insert .= join(',', ('(?, ?, ?, ?, ?, ?, ?)') x @$store_order_items);

		my @store_order_insert_values = ();
		foreach my $store_order_item ( @$store_order_items ) {
			my $params = $store_order_item->{params} || '';
			if ($params) {
				$params = unserialize($store_order_item->{params});
				$params = { map { $_->{name} => $_->{param} } @$params };
			}
			$params = Dancer::Serializer::JSON::to_json($params, { pretty => 0, utf8 => 0 })
				if $params && ref $params eq 'HASH';
			utf8::decode($params);
			push(@store_order_insert_values,
				$new_order_id_by_old_one{ $store_order_item->{order_id} } // 0,
				$store_order_item->{item_id} // 0,
				$store_order_item->{title} // '',
				$store_order_item->{description} // '',
				$params,
				$store_order_item->{price} // 0,
				$store_order_item->{qty} // 0,
			);
		} # foreach store_order_item
		$new->do($store_order_insert, {}, @store_order_insert_values) if @$store_order_items;

		$new->do(
			q{
				INSERT INTO store_order_data
				(site_id, title, required, hidden)
				VALUES (?, 'Фамилия Имя', 1, 0),
				(?, 'Адрес доставки', 1, 0),
				(?, 'Комментарий', 1, 0)
			},
			{},
			$site_id,
				$site_id,
				$site_id,
		);
	}

	# item more
	my $store_item_mores = $old->selectall_arrayref(
		q{
			SELECT *
			  FROM store_item_more
			 WHERE domainid = ?
			 ORDER BY more_id
		},
		{ Slice => {} },
		$domainid,
	);

	print_items_found_if_verbose $store_item_mores, 'store item more', $time if $verbose;

	my %new_more_id_by_old_one = (); # map old.store_item_more.more_id to new one

	foreach my $store_item_more ( @$store_item_mores ) {
		$new->do(
			q{
				INSERT INTO store_item_more
				(item_id, parent_id)
				VALUES (?, ?)
			},
			{},
			$new_more_id_by_old_one{ $store_item_more->{  item_id} } // 0,
			$new_more_id_by_old_one{ $store_item_more->{parent_id} } // 0,
		);
		$new_more_id_by_old_one{ $store_item_more->{more_id} }
			= $new->last_insert_id(undef, undef, undef, undef);
	} # foreach store_item_more

	# item_param
	my $store_item_params = $old->selectall_arrayref(
		q{
			SELECT *
			  FROM store_item_param
			 WHERE domainid = ?
			 ORDER BY param_id
		},
		{ Slice => {} },
		$domainid,
	);

	print_items_found_if_verbose $store_item_params, 'store item params', $time if $verbose;

	my %new_param_id_by_old_one = (); # map old.store_item_param.item_param_id to new one

	foreach my $store_item_param ( @$store_item_params ) {
		$new->do(
			q{
				INSERT INTO store_item_param
				(item_id, name, sort)
				VALUES (?, ?, ?)
			},
			{},
			$store_item_param->{item_id} // 0,
				$store_item_param->{name } // '',
				$store_item_param->{sort } // 0,
		);
		$new_param_id_by_old_one{ $store_item_param->{param_id} }
			= $new->last_insert_id(undef, undef, undef, undef);
		next unless $store_item_param->{value};
		$new->do(
			q{
				INSERT INTO store_item_param_value
				(param_id, item_id, value)
				VALUES (?, ?, ?)
			},
			{},
			$new_param_id_by_old_one{ $store_item_param->{param_id} },
			$store_item_param->{item_id} // 0,
			$store_item_param->{value} // '',
		);
	} # foreach store_item_param

	if ( scalar(@$store_item_params) ) {
		# item param value
		my $store_item_param_values = $old->selectall_arrayref(
			q{
				SELECT *
				  FROM store_item_param_value
				 WHERE domainid = ?
				 ORDER BY value_id
			},
			{ Slice => {} },
			$domainid,
		);

		print_items_found_if_verbose $store_item_param_values, 'store item param values', $time if $verbose;

		my $store_item_param_insert = q{
			INSERT INTO store_item_param_value
			(param_id, item_id, value)
			VALUES
		};
		$store_item_param_insert .= join(',', ('(?, ?, ?)') x @$store_item_param_values);

		my @store_item_param_insert_values = ();
		foreach my $store_item_param_value ( @$store_item_param_values ) {
			push(@store_item_param_insert_values,
				$new_param_id_by_old_one{ $store_item_param_value->{param_id} } // 0,
				$store_item_param_value->{item_id} // 0,
				$store_item_param_value->{value} // '',
			);
		} # foreach store_item_param_value
		$new->do($store_item_param_insert, {}, @store_item_param_insert_values) if @$store_item_param_values;
	}

} # while sites
$sth->finish();

# Partners => Affiliate stat
my $partners = $old->selectall_arrayref(
	q{
		SELECT *
		  FROM partners
		 ORDER BY pid
	},
	{ Slice => {} },
);

print_items_found_if_verbose $partners, 'partner portions', time() if $verbose;

my $partners_insert = q{
	INSERT INTO affiliate_stat
	(affiliate_id, sum, date, title)
	VALUES
};
$partners_insert .= join(',', ('(?, ?, ?, ?)') x @$partners);

my @partners_insert_values = ();
foreach my $partner ( @$partners ) {
	push(@partners_insert_values,
		$partner->{pid} // 0,
		sprintf("%.2f", $partner->{sum} / $exchange_rate),
		$partner->{date}, $partner->{site}
	);
} # foreach partner
$new->do($partners_insert, {}, @partners_insert_values) if @$partners;

$new->do('SET FOREIGN_KEY_CHECKS = 1');

$new->do(qq{ UPDATE sites SET css = REPLACE(css, "url('file", "url('/file") });
$new->do(qq{ UPDATE sites SET css = REPLACE(css, "url('img", "url('/img") });
$new->do(qq{ UPDATE sites SET css = REPLACE(css, 'url("img', 'url("/img') });
$new->do(qq{ UPDATE sites SET css = REPLACE(css, 'url("file', 'url("/file') });
$new->do(qq{ UPDATE sites SET css = REPLACE(css, 'url(file', 'url(/file') });
$new->do(qq{ UPDATE sites SET css = REPLACE(css, 'url(img', 'url(/img') });

$new->do(qq{ UPDATE pages SET body = REPLACE(body, '"../', '"/') });
$new->do(qq{ UPDATE pages SET body = REPLACE(body, "'../", "'/") });

$new->do(qq{ UPDATE sites_meta SET advTop = REPLACE(advTop, '"../', '"/') });
$new->do(qq{ UPDATE sites_meta SET advTop = REPLACE(advTop, "'../", "'/") });

$new->do(qq{ UPDATE sites_meta SET advBottom = REPLACE(advBottom, '"../', '"/') });
$new->do(qq{ UPDATE sites_meta SET advBottom = REPLACE(advBottom, "'../", "'/") });

$new->do(qq{ UPDATE sites_meta SET advNews = REPLACE(advNews, '"../', '"/') });
$new->do(qq{ UPDATE sites_meta SET advNews = REPLACE(advNews, "'../", "'/") });

$new->do(qq{ UPDATE sites_meta SET advMenu = REPLACE(advMenu, '"../', '"/') });
$new->do(qq{ UPDATE sites_meta SET advMenu = REPLACE(advMenu, "'../", "'/") });

$new->do(qq{ UPDATE news SET preview = REPLACE(preview, "'../", "'/") });
$new->do(qq{ UPDATE news SET preview = REPLACE(preview, '"../', '"/') });

$new->do(qq{ UPDATE news SET body = REPLACE(body, "'../", "'/") });
$new->do(qq{ UPDATE news SET body = REPLACE(body, '"../', '"/') });

$new->do(qq{ UPDATE sites_meta SET html = REPLACE(html, "'../", "'/") });
$new->do(qq{ UPDATE sites_meta SET html = REPLACE(html, '"../', '"/') });

$new->do(qq{ UPDATE sites_meta SET html = REPLACE(html, '/shablons/', '/templates/okis/') });
$new->do(qq{ UPDATE pages SET body = REPLACE(body, '/shablons/', '/templates/okis/') });

$new->disconnect;
$old->disconnect;

#printf( "Total time: %.2f.\n", $total_time - time() ) if $verbose;

# Prints a message
sub print_items_found_if_verbose($$$) {
	my ( $list, $named, $time ) = @_;

	print
		' ' x 9 # indent
		. ( scalar(@$list) || 'no' )
		. " $named "
		. ( $timing ? sprintf(" (%.3f sec.)", time() - $time) : '' ) 
		. "\n";
}
