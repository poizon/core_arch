package admin::api::store;

use Dancer ':syntax';
use Helpers;

use admin::api::store::category;
use admin::api::store::products;
use admin::api::store::orders;
use admin::api::store::delivery;

use Dancer::Plugin::REST;

prepare_serializer_for_format;
prefix '/admin/api/store';

### Store CRUD API

post '/fields.:format' => sub {
	content_type 'application/json';
	my $title   = params->{title};
	my $data_id = params->{data_id};
	return to_json { result => 'error' } unless $title;
	return unless vars->{site}->{premium} && vars->{site}->{package} eq 'Business';
	
	if ($data_id) {
		quick_update(
			'store_order_data', {
				site_id => vars->{site}->{site_id},
				data_id => $data_id,
			}, {
				title => $title,
			}
		);
	} else {
		quick_insert(
			'store_order_data', {
				site_id  => vars->{site}->{site_id},
				title    => $title,
				required => 1,
				hidden   => 0,
			}
		);
		$data_id = last_insert_id();
	}

	status_ok { result => 'ok', data_id => $data_id };
};

post '/currency.:format' => sub {
	my $in   = params;
	my $data = validator($in, 'store_currency_form_update.pl');

	$data->{valid}
		or return to_json {
			error  => loc('Ошибка'),
			fields => $data->{result}
		};
	my $params = $data->{result};

	# TODO: add compatibility mode

	quick_update(
		'sites', {
			site_id => vars->{site}->{site_id}
		}, {
			store_currency => $params->{currency_code}
		}
	);

	status_ok { result => 'ok' };
};

post '/confirmation.:format' => sub {
	quick_update(
		'sites', {
			site_id => vars->{site}->{site_id}
		}, {
			store_confirmation => params->{confirmation}
		}
	);
	status_ok { result => 'ok' };
};

post '/id_format.:format' => sub {
	quick_update(
		'sites', {
			site_id => vars->{site}->{site_id}
		}, {
			store_order_suffix => params->{suffix},
			store_order_prefix => params->{prefix}
		}
	);
	status_ok { result => 'ok' };
};

true;
