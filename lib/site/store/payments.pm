package site::store::payments;

use Dancer ':syntax';
use Helpers;
use tools::store;

prefix '/store';

our %PAYMETHODS = %tools::store::PAYMETHODS;

get '/paymethod/select/?' => sub {
	render_template 'store/payments/method_select', {
		paymethods => tools::store::get_available_paymethods()
	}
};

post '/paymethod/select/?' => sub {
	my $order = quick_select(
		'store_order', {
			site_id  => vars->{site}->{site_id},
			order_id => session('order_id')
		}
	);

	if (params->{paymethod_name} eq 'robokassa') {
		my %paymethod_params = _get_paymethod_params('robokassa');
		my $crc = md5_hex(
			$paymethod_params{robokassa_mrh_login} . ':' .
			$order->{amount} . ':' .
			$order->{order_id} . ':' .
			$paymethod_params{robokassa_mrh_pass1}
		);
		my $order_description = $order->{comment} ||
			'Order #' . $order->{order_id} . ' from ' . vars->{site}->{domain} . '\'s e-store.';
		return render_template 'store/payments/robokassa', {
			MrhLogin       => $paymethod_params{robokassa_mrh_login},
			OutSum         => $order->{amount},
			InvId          => $order->{order_id},
			Desc           => $order_description,
			SignatureValue => $crc,
		};
	}

	render_template 'store/payments/method_not_found', {};
};

### REDIRECT URL's

get '/payments/fail/?' => sub {
	render_template 'store/payments/fail';
};

### ROBOKASSA REDIRECT's

post '/payments/robokassa/result/?' => sub {
	my $params    = params;
	my %paymethod = _get_paymethod_params('robokassa');
	my $result    = loc('Incorrect sign passed');

	my $order = quick_select(
		'store_order', {
			order_id => $params->{'InvId'},
			site_id  => vars->{site}->{site_id}
		}
	) or return $result;

	$params->{'SignatureValue'} = uc($params->{'SignatureValue'});
	my $my_crc = uc(md5_hex(
		$params->{OutSum} . ':' .
		$params->{InvId} . ':' .
		$paymethod{robokassa_mrh_pass2}
	));

	if ($params->{'SignatureValue'} eq $my_crc) {
		$result = 'OK';
		quick_update(
			'store_order', {
				order_id => $params->{'InvId'},
				site_id  => vars->{site}->{site_id}
			}, {
				status   => 3
			}
		);
	}

	return $result;
};

get '/payments/robokassa/success/?' => sub {
	my $params    = params;
	my %paymethod = _get_paymethod_params('robokassa');

	$params->{'SignatureValue'} = uc($params->{'SignatureValue'});
	my $my_crc = uc(md5_hex(
		$params->{'OutSum'} . ':' .
		$params->{'InvId'} . ':' .
		$paymethod{'robokassa_mrh_pass1'}
	));
	my $result = $my_crc eq $params->{'SignatureValue'}
					? loc('The Payment has been Successfully Completed')
					: loc('Incorrect sign passed');

	render_template 'store/payments/success', {
		result => $result
	};
};

### Local methods

sub _get_paymethod_params {
	my ($method_name) = @_;

	return unless $PAYMETHODS{$method_name};

	my @paymethods_data = quick_select(
		'store_checkout', {
			site_id   => vars->{site}->{site_id},
			paymethod => $method_name,
		}
	);
	my %paymethod_params = map { $_->{param_name} => $_->{param_value} } @paymethods_data;

	return %paymethod_params;
}

### Public methods



true;
