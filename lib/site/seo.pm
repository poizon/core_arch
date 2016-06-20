package site::seo;

use Dancer ':syntax';
use Helpers;

prefix '/';

get '/sitemap.xml' => sub {
	content_type 'text/xml';

	# Pages
	my @pages = quick_select(
		'pages', {
			site_id => vars->{site}->{site_id},
			hidden  => 0,
			noindex => 0,
		}, {
			columns  => [ qw/url/ ]
		}
	);

	# Blog
	my @posts = quick_select(
		'blog_posts', {
			site_id => vars->{site}->{site_id},
			hidden  => 0,
		}, {
			columns  => [ qw/post_id/ ],
			order_by => { desc => 'date' }
		}
	);

	# News
	my @news = quick_select(
		'news', {
			site_id => vars->{site}->{site_id},
			hidden  => 0,
		}, {
			columns  => [ qw/news_id/ ],
			order_by => { desc => 'date' }
		}
	);

	# Store_Items
	my @store_items = quick_select(
		'store_item', {
			site_id => vars->{site}->{site_id},
			hidden  => 0,
		}, {
			columns  => [ qw/item_id/ ],
			order_by => { asc => 'item_id' }
		}
	);

	# Store_Categories
	my @store_categories = quick_select(
		'store_category', {
			site_id => vars->{site}->{site_id},
			hidden  => 0,
		}, {
			columns  => [ qw/category_id/ ],
			order_by => { asc => 'category_id' }
		}
	);


	template 'sitemap', {
		pages  => \@pages, # regular pages
		posts  => \@posts, # blog posts
		news   => \@news,  # news
		store_items => \@store_items, # store_items
		store_categories => \@store_categories, # store_category
	}, {
		layout => undef
	};
};


get '/robots.txt' => sub {
	content_type 'text/plain';
	template 'robots', {}, { layout => undef };
};

true;
