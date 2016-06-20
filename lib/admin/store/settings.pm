package admin::store::settings;

use Dancer ':syntax';
use Helpers;

prefix '/admin/store/settings';

get '/' => sub {
	my @order_data = quick_select(
		'store_order_data', {
			site_id => vars->{site}->{site_id},
		}, {
			order_by => 'data_id',
		}
	);
	
	template 'admin/store/settings', {
		title      => loc('Настройки'),
		currencies => $currencies,
		order_data => \@order_data,
	};
};

post '/' => sub {
	quick_update(
		'sites', {
			site_id => vars->{site}->{site_id}
		}, {
			store_imgsize_category => params->{store_imgsize_category},
			store_imgsize_product  => params->{store_imgsize_product}
		}
	);
	redirect '/admin/store/settings';
};

true;