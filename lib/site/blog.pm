package site::blog;

use Dancer ':syntax';
use Helpers;

prefix '/blog';

get '/' => sub {

	my $limit  = config->{per_page}->{blog} // 10;

	my $total_posts = quick_count(
		'blog_posts', {
			site_id => vars->{site}->{site_id},
			hidden  => 0,
		}
	);

	my $pager  = pager($limit, $total_posts);
	my $offset = $pager->from // 0;
	
	my $posts  = database->selectall_arrayref(
		qq{
			SELECT
				p.post_id, title, p.date, p.body, COUNT(comment_id) comments
			FROM
				blog_posts p
					LEFT JOIN
				blog_comments c ON p.post_id = c.post_id
			WHERE
				p.site_id = ?
				AND hidden = 0
			GROUP BY p.post_id
			ORDER BY date DESC
			LIMIT ? OFFSET ?;
		},
		{ Slice => {} },
		vars->{site}->{site_id}, $limit, $offset,
	);

	map {
		$_->{'announce'} = $_->{'body'} # TODO cut when necessary
	} @$posts;

	render_template(
		'blog/index', {
			title => loc('Blog'),
			posts => $posts,
			pager => $pager,
		}
	);
};


get qr{/(\d+)/?} => sub {

	my @args = splat;
	my $id   = pop @args || 0;

	my $item = quick_select(
		'blog_posts', {
			post_id => $id,
			hidden  => 0,
			site_id => vars->{site}->{site_id},
	});

	my @comments = ();

	if ($item) {
		@comments = quick_select(
			'blog_comments', {
				post_id  => $id,
			}, {
				order_by => 'date',
			}
		);
	}
	else {
		status 404; # Not found
	}

	render_template(
		'blog/item', {
			title    => $item->{title} // loc('Post not found'),
			item     => $item,
			comments => \@comments,
			status   => status,
		}
	);
};


post qr{/(\d+)/?} => sub {
	my @args = splat;
	my $id   = pop @args || 0;

	my @comments = ();

	# Check for existence and visibility
	my $item = quick_select('blog_posts', {
		post_id => $id,
		site_id => vars->{site}->{site_id},
		hidden  => 0,
	});

	if ($item) {
		# Item found
		my $in   = params;
		my $data = validator($in, 'comment_form.pl');
		   $item = $data->{result};

		$data->{valid}
			or return render_template 'blog/item', {
				title   => $item->{'title'},
				item    => $item,
				comment => $data->{result},
				error   => loc('Ошибка'),
			};

		my $params = $data->{result};

		my $formatter = format_date('%F %T'); # YYYY-mm-dd HH:MM:SS - DATETIME in MySQL
		my $now = $formatter->(time);

		quick_insert('blog_comments', {
			site_id => vars->{site}->{site_id},
			post_id => $id,
			name    => $params->{name},
			body    => $params->{body},
			email   => $params->{email},
			date    => $now,
		});

		@comments = quick_select(
			'blog_comments', {
				post_id  => $id,
			}, {
				order_by => 'date',
			}
		);

	}
	else {
		status 404; # Not found
	}

	render_template(
		'blog/item', {
			title    => $item->{title} // loc('Post not found'),
			item     => $item,
			comments => \@comments,
			status   => status,
		}
	);

};

true;
