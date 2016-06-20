package admin::blog;

use Dancer ':syntax';
use Helpers;

prefix '/admin/blog';

get '/' => sub {
	my $in       = params;
	my $filter   = $in->{filter} // '';

	my $and_where_clause = '';
	my @bind_params = vars->{site}->{site_id};

	if ($filter) {
		$and_where_clause = qq{
			AND (
				title 	LIKE ?
				OR body LIKE ?
			)
		};
		my $count = () = $and_where_clause =~ /\?/g; # count ?s
		push @bind_params, ("%$filter%") x $count;
	}

	my $blog_posts = database->selectall_arrayref(
		qq{
			SELECT
				post_id, title, body, date, hidden
			FROM
				blog_posts
			WHERE
				site_id = ?
				$and_where_clause
		},
		{ Slice => {} },
		@bind_params
	);

	template 'admin/blog/index', {
		blog_posts => $blog_posts,
		filter     => $filter,
		title      => loc('Blog'),
	};

};

# Draw and process create/update form
any ['get', 'post'] => qr{/((\d+)/)?(add|edit)} => sub {

	my @args   = splat;
	my $action = pop @args;
	my $id     = pop @args || 0;

	my $title  = $action eq 'add' ? loc('New Post') : loc('Edit');
	my $blog_post;

	# Draw form only when requested via GET
	if ( request->method() eq 'GET' ) {
		if ( $action eq 'edit' ) {

			$blog_post  = quick_select('blog_posts', {
				post_id => $id,
				site_id => vars->{site}->{site_id}
			})
				or return redirect '/admin/blog'; # Not found
		}

		return template 'admin/blog/add', {
			post   => $blog_post,
			title  => $title
		};
	}
	# else - via POST
	debug 'POST';
	my $in        = params;
	my $data      = validator($in, 'blog_form.pl');
	   $blog_post = $data->{result};

	$data->{valid}
		or return template 'admin/blog/add', {
			blog_post => $data->{result},
			error  => loc('Ошибка'),
			title  => $title
		};

	my $params = $data->{result};

	if ( $action eq 'add' ) {
		quick_insert('blog_posts', {
			site_id => vars->{site}->{site_id},
			title   => $params->{title},
			body    => $params->{body},
			date    => $params->{date},
		});
	}
	else {
		quick_update('blog_posts', {
			post_id  => $id,
			site_id  => vars->{site}->{site_id}
		}, {
			title    => $params->{title},
			body     => $params->{body},
			date     => $params->{date},
		});
	}

	redirect '/admin/blog';
};

# Comments
get '/comments' => sub {
	my $in       = params;
	my $filter   = $in->{filter} // '';

	my $and_where_clause = '';
	my @bind_params = vars->{site}->{site_id};

	if ($filter) {
		$and_where_clause = qq{
			AND (
				name     LIKE ?
				OR email LIKE ?
				OR body  LIKE ?
			)
		};
		my $count = () = $and_where_clause =~ /\?/g; # count ?s
		push @bind_params, ("%$filter%") x $count;
	}

	my $blog_comments = database->selectall_arrayref(
		qq{
			SELECT
				comment_id, name, email, body, date
			FROM
				blog_comments
			WHERE
				site_id = ?
				$and_where_clause
		},
		{ Slice => {} },
		@bind_params
	);

	template 'admin/blog/comments/index', {
		comments => $blog_comments,
		filter   => $filter,
		title    => loc('Comments'),
	};

};

true;

