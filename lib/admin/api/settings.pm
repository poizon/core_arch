package admin::api::store;

use Dancer ':syntax';
use Helpers;

use Dancer::Plugin::REST;
prepare_serializer_for_format;
prefix '/admin/api/settings';

post '/css.:format' => sub {
	quick_update(
		'sites', {
			site_id => vars->{site}->{site_id}
		}, {
			css => params->{css}
		}
	);

	status_ok { result => 'ok' };
};

post '/html.:format' => sub {
	return status_ok { result => 'premium' }
		if !config->{compatibility} || !vars->{site}->{premium};
	
	if ( quick_lookup("sites_meta", { site_id => vars->{site}->{site_id} }, "option_id") ) {
		quick_update(
			'sites_meta', {
				site_id => vars->{site}->{site_id}
			}, {
				html => params->{html}
			}
		);
	} 
	else {
		quick_insert(
			'sites_meta', {
				site_id => vars->{site}->{site_id},
				html    => params->{html}
			}
		);
	}

	status_ok { result => 'ok' };
};

true;