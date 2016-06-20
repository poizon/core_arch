package admin::news;

use Dancer ':syntax';
use Helpers;

prefix '/admin/news';

# List
get '/' => sub {
	my $in     = params;
	my $filter = $in->{filter};

	my $criteria->{site_id} = vars->{site}->{site_id};
	$criteria->{title} = { like => "%$filter%" } if $filter;

	my $limit = config->{per_page}->{news} || 20;
	my $total = quick_count('news', $criteria);
	my $pager = pager($limit, $total);

	my @news = quick_select(
		'news', $criteria, {
			columns  => [ qw(title hidden news_id date) ],
			order_by => { desc => 'date' },
			limit    => $pager->offset,
			offset   => $pager->from
		}
	);
	
	return redirect '/admin/news/add' unless @news || $filter;

	template 'admin/news/index', {
		news   => \@news,
		pager  => $pager,
		title  => loc('Новости')
	};
};

any ['get', 'post'] => qr{/((\d+)/)?(add|edit)} => sub {
	my @args   = splat;
	my $action = pop @args;
	my $id     = pop @args || 0;
	
	my $title = $action eq 'add' ? loc('Добавить новость') : loc('Изменить');
	
	my $news;
	# Draw form only when requested via GET
	if (request->method() eq 'GET') {
		if ($action eq 'edit') {

			$news = quick_select('news', {
				news_id => $id,
				site_id => vars->{site}->{site_id}
			})
				or return redirect '/admin/news'; # Not found
		}

		return template 'admin/news/add', {
			news  => $news,
			title => $title
		};
	}
	# else - via POST

	my $in    = params;
	my $data  = validator($in, 'news_form.pl');
	   $news  = $data->{result};

	$data->{valid}
		or return template 'admin/news/add', {
			error => loc('Ошибка'),
			news  => $data->{result},
			title => $title
		};

	my $params = $data->{result};

	if ($action eq 'add') {
		quick_insert(
			'news', {
				site_id => vars->{site}->{site_id},
				title   => $params->{title},
				preview => $params->{preview},
				body    => $params->{body},
				date    => $params->{date}
			}
		);
		$id = last_insert_id();
	} else {
		quick_update(
			'news', {
				news_id => $id,
				site_id => vars->{site}->{site_id}
			}, {
				title   => $params->{title},
				body    => $params->{body},
				preview => $params->{preview},
				date    => $params->{date},
			}
		);
	}

	my $redirect_url = "/admin/news";
	$redirect_url   .= "/$id/edit" if $params->{action} eq 'apply';
	
	redirect $redirect_url;
};

true;

