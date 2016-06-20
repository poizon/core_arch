package admin::store::payments;

use Dancer ':syntax';
use Helpers;

prefix '/admin/store/payments';


get '/' => sub {
	my @paymethods_params = quick_select(
		'store_checkout', {
			site_id => vars->{site}->{site_id}
		}
	);

	template 'admin/store/payments', {
		title      => loc('Платежи'),
		paymethod  => { map { $_->{param_name} => $_->{param_value} } @paymethods_params },
	};
};

post '/' => sub {
	return redirect '/admin/store'
		if !vars->{site}->{premium} || vars->{site}->{package} ne 'Business';

	my $params     = params;
	my $paymethod  = $params->{paymethod}; #  || ''
	my $pay_params = tools::store::get_paymethod_params_names($paymethod);
	for my $param_name (@$pay_params) {
		my $id = quick_lookup(
			'store_checkout', {
				site_id    => vars->{site}->{site_id},
				paymethod  => $paymethod,
				param_name => $param_name,
			}, 'param_id'
		);

		if ($id) {
			# exists, update
			quick_update(
				'store_checkout', {
					param_id    => $id,
				}, {
					param_value => $params->{$param_name}, # || ''
				}
			);
		}
		else {
			# insert
			quick_insert(
				'store_checkout', {
					site_id     => vars->{site}->{site_id},
					paymethod   => $paymethod,
					param_name  => $param_name,
					param_value => $params->{$param_name}, #  || ''
				}
			);
		}
	}

	redirect '/admin/store/payments';
};
