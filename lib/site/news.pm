package site::news;

use Dancer ':syntax';
use Helpers;

prefix '/news';

get '/' => sub {
	my $limit  = config->{per_page}->{news} // 15;
	
	my $criteria = { site_id => vars->{site}->{site_id}, hidden => 0 };
	my $total_news = quick_count('news', $criteria);
	my $pager = pager($limit, $total_news);

	my @news = quick_select(
		'news', $criteria, {
			order_by => { desc => 'date' },
			limit    => $limit,
			offset   => $pager->from,
		}
	);

	render_template 'news/index', {
		title => loc('Новости'),
		list  => \@news,
		pager => $pager,
	};
};

get '/rss/?' => sub {
	my @news = quick_select(
		'news', {
			site_id => vars->{site}->{site_id},
			hidden  => 0,
		}, {
			order_by => { desc => 'date' },
			limit    => config->{per_page}->{news} // 50,
		}
	);

	template "templates/rss", { list => \@news }, { layout => undef };
};

get '/:news_id' => sub {
	my $item = quick_select(
		'news', {
			news_id => params->{news_id},
			hidden  => 0,
			site_id => vars->{site}->{site_id}
		}
	);
	
	status 404 unless $item;

	render_template 'news/item', {
		title  => $item->{title} // loc('Ничего не найдено'),
		item   => $item,
		status => status
	};
};

true;
