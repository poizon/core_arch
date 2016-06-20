package admin::store::coupons;

use Dancer ':syntax';
use Helpers;

prefix '/admin/store/coupons';

get '/' => sub {
	my $limit = config->{per_page}->{coupons} || 20;
	my $total = quick_count("store_coupon", { site_id => vars->{site}->{site_id} });
	my $pager = pager($limit, $total);

	my @coupons = quick_select(
		'store_coupon', {
			site_id  => vars->{site}->{site_id}
		}, {
			order_by => { desc => 'coupon_id' },
			limit    => $pager->offset,
			offset   => $pager->from
		}
	);

	template 'admin/store/coupons/index', {
		coupons => \@coupons,
		title   => loc("Промокоды"),
		pager   => $pager
	};
};

## Add Coupon

get '/add' => sub {
	template 'admin/store/coupons/add', {
		title => loc("Промокоды")
	};
};

post '/add' => sub {
	return redirect '/admin/store'
		if !vars->{site}->{premium} || vars->{site}->{package} ne 'Business';

	my $in   = params;
	my $data = validator($in, 'store_coupon_form_create.pl');

	$data->{valid}
		or return template 'admin/store/coupons/add', {
			error => loc('Ошибка'),
			    p => $data->{result},
		};
	my $params = $data->{result};
	$params->{discount} = 100 if $params->{type} eq 'REL' && $params->{discount} > 100;

	quick_insert(
		'store_coupon', {
			site_id    => vars->{site}->{site_id},
			code       => $params->{code},
			title      => $params->{title},
			discount   => $params->{discount},
			type       => $params->{type},
			date_start => $params->{date_start} || undef,
			date_end   => $params->{date_end} || undef,
			limit      => $params->{limit} || 0,
		}
	);
	redirect '/admin/store/coupons';
};

## Edit coupon

get '/:id/edit' => sub {
	my $coupon = quick_select(
		'store_coupon', {
			coupon_id => params->{id},
			site_id   => vars->{site}->{site_id}
		}
	);

	template 'admin/store/coupons/edit', {
		title => loc("Промокоды"),
		    p => $coupon
	};
};

post '/:id/edit' => sub {
	return redirect '/admin/store'
		if !vars->{site}->{premium} || vars->{site}->{package} ne 'Business';

	my $in   = params;
	my $data = validator($in, 'store_coupon_form_update.pl');

	$data->{valid}
		or return template 'admin/store/coupons/edit', {
			error => loc('Ошибка'),
			    p => $data->{result}
		};
	my $params = $data->{result};
	$params->{discount} = 100 if $params->{type} == 1 && $params->{discount} > 100;

	quick_update(
		'store_coupon', {
			coupon_id  => $params->{id},
			site_id    => vars->{site}->{site_id}
		}, {
			title      => $params->{title},
			code       => $params->{code},
			discount   => $params->{discount},
			type       => $params->{type},
			used       => $params->{used} || 0,
			date_start => $params->{date_start} || undef,
			date_end   => $params->{date_end} || undef,
			limit      => $params->{limit} || 0,
		}
	);
	redirect '/admin/store/coupons';
};

true;
