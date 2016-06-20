package tools::templates;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use tools::I18N;

use FindBin qw/$Bin $RealBin/;
use Exporter();
use base 'Exporter';
our @EXPORT = qw(render_template);

sub render_template {
	my $name  = shift;
	my $stash = shift;

	$stash->{menu} = _build_menu();
	$stash->{meta_title} = _get_title($stash->{title});
	
	my $layout = (split('/', vars->{site}->{template}))[0];
	$stash->{news} = _get_news() if $layout eq "okis";
	
	if (config->{compatibility}) {
		$stash->{meta} = database->quick_select("sites_meta", { site_id => vars->{site}->{site_id} });
		$stash->{sape} = _get_sape() if config->{sape};
		$stash->{linkfeed} = _get_linkfeed() if config->{linkfeed};
		return _parse_html($name, $stash) if $stash->{meta}->{html};
	}
	
	template "templates/$layout/$name", $stash, { layout => "templates/$layout" };
}

sub _get_title {
	my $title = shift;
	return vars->{site}->{title} || vars->{site}->{domain} unless $title;
	$title .= " / " . vars->{site}->{title} if vars->{site}->{title};
	return $title;
}

sub _get_linkfeed {
	require tools::linkfeed;
	my $linkfeed_client = linkfeed->new(
		user    => config->{linkfeed},
		host    => vars->{site}->{domain},
		charset => 'utf-8',
		db_dir  => $Bin . "/../public/linkfeed",
		multi_site  => true,
		request_uri => request->uri
	);
	return $linkfeed_client->return_links(); 
}

sub _get_sape {
	require tools::SAPE;
	my $sape = new SAPE::Client(
		user    => config->{sape},
		host    => vars->{site}->{ascii_domain},
		charset => 'utf-8',
		db_dir  => $Bin . "/../public/sape",
		multi_site  => true,
		request_uri => request->uri
	);
	return $sape->return_links();
}

sub _parse_html {
	my $template = shift;
	my $stash    = shift;

	my ($html, $site) = ( \$stash->{meta}->{html}, vars->{site} );
	my $layout = { layout => undef };

	my $content  = template "ads/cpc", {}, $layout;
	   $content .= template "templates/okis/$template", $stash, $layout;

	_replace($html, '%h1%', $stash->{header} || $stash->{title});
	_replace($html, '%bottom_menu%');
	_replace($html, '%meta%', _get_meta_tags($stash));
	_replace($html, '%counters%', $site->{stat_tracking});
	_replace($html, '%css%', $site->{css});
	_replace($html, '%adv_top%', $stash->{meta}->{advTop});
	_replace($html, '%adv_bottom%', $stash->{meta}->{advBottom});
	_replace($html, '%title%', $stash->{title});
	_replace($html, '%content%', $content);
	_replace($html, '%news%', template("templates/okis/news/sidebar", $stash, $layout));
	_replace($html, '%copyright%', template("ads/copyright", $stash, $layout));
	_replace($html, '%menu%', template("templates/okis/menu", $stash, $layout));

	return $$html;
}

sub _get_meta_tags {
	my $stash = shift;
	my $site  = vars->{site};
	my $meta  = $site->{meta_header};
	
	$meta .= "\n\n<meta name='robots' content='noindex,nofollow'>" if $stash->{noindex} || $site->{noindex};
	$meta .= "\n\n<link rel='shortcut icon' href='" . $site->{favicon} . "'/>" if $site->{favicon};
	
	my $description = $stash->{meta_desc} || $site->{meta_description};
	my $keywords    = $stash->{meta_keywords} || $site->{meta_keywords};
	
	$meta .= "\n\n<meta name='description' content='$description'>" if $description;
	$meta .= "\n\n<meta name='keywords' content='$keywords'>" if $keywords;
	
	$meta .= "\n" . '<link rel="stylesheet" type="text/css" href="/assets/stylesheets/froala_style.min.css"/>';
	
	return $meta;
}

sub _replace {
	my $html = shift or return;
	my $find = shift or return;
	my $str  = shift // '';
	$$html  =~ s/$find/$str/g;
}

sub _get_news {
	my @news = database->quick_select(
		'news', {
			site_id  => vars->{site}->{site_id},
			hidden   => 0
		}, {
			order_by => { desc => 'date' },
			limit    => 5,
			columns  => [ qw/news_id date title preview/ ]
		}
	);
	return \@news;
}

sub _build_menu {
	my @menu = database->quick_select(
		'menu', {
			site_id  => vars->{site}->{site_id},
			hidden   => 0,
		}, {
			order_by => 'priority'
		}
	);

	my %childs = ();
	push @{ $childs{$_->{parent_id}} }, $_ for @menu;

	my $menu = $childs{0} || [];
	$_->{submenu} = $childs{ $_->{menu_id} } || [] for @$menu;
	return $menu;

}

true;
