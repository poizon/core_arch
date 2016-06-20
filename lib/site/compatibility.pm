package site::compatibility;

use Dancer ':syntax';
use Helpers;

prefix undef;

return true unless config->{compatibility};

# Gallery
get '/newfotogalery.0.html' => sub {
	forward '/gallery';
};

get '/newfotogalery.:id.html' => sub {
	forward '/gallery/album/'. params->{id};
};

get '/fotogalery.0.html' => sub {
	forward '/gallery';
};

get '/fotogalery.:id.html' => sub {
	forward '/gallery/album/'. params->{id};
};

# Store
get '/store.0.html' => sub {
	forward '/store';
};

get '/store.cart.html' => sub {
	redirect '/store/cart';
};

get '/store.category:id.html' => sub {
	forward '/store/category/'. params->{id};
};

get '/store.item:id.html' => sub {
	forward '/store/item/'. params->{id};
};

# News
get '/allnews.:page.html' => sub {
	forward '/news', { page => params->{page} };
};

get '/rss.php' => sub {
	forward '/news/rss';
};

get qr{/news\.(\d+?)\..+?\.html} => sub {
	my @args = splat;
	my $id   = pop @args || 0;
	forward '/news/'. $id;
};

get '/map.site.html' => sub {
	my $cond = { site_id => vars->{site}->{site_id}, hidden => 0 };

	my @pages      = quick_select('pages', $cond, { columns => [ qw/title url/ ] });
	my @news       = quick_select('news', $cond, { columns => [ qw/title news_id/ ] });
	my @albums     = quick_select('gallery_albums', $cond, { columns => [ qw/title album_id/ ] });
	
	my @products   = quick_select('store_item', $cond, { columns => [ qw/title item_id/ ] });
	my @categories = quick_select('store_category', $cond, { columns => [ qw/title category_id/ ] });

	$_->{url} = "/news/$_->{news_id}" for @news;
	$_->{url} = "/store/item/$_->{item_id}" for @products;
	$_->{url} = "/store/category/$_->{category_id}" for @categories;
	$_->{url} = "/gallery/album/$_->{album_id}" for @albums;

	render_template('map', {
		sitemap => [
			{ list  => \@pages,    title => loc('Страницы') },
			{ list  => \@news,     title => loc('Новости')  },
			{ list  => \@albums,   title => loc('Галерея')  },
			
			{ list  => \@products, title => loc('Товары') },
			{ list  => \@categories },
		],
	});
};

true;
