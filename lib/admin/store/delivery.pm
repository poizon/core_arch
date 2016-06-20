package admin::store::delivery;

use Dancer ':syntax';
use Helpers;

prefix '/admin/store/delivery';

### Delivery
get '/' => sub {
	my @deliveries = quick_select(
		'store_delivery', {
			site_id => vars->{site}->{site_id},
		}
	);
	template 'admin/store/delivery/index', {
		title      => loc('Доставка'),
		deliveries => \@deliveries,
	};
};

get '/create/?' => sub {
	template 'admin/store/delivery/add', {
		title    => loc('Доставка'),
	};
};

post '/create/?' => sub {
	my $in   = params;
	my $data = validator($in, 'store_delivery_form.pl');

	$data->{valid}
		or return template 'admin/store/delivery/add', {
				currency => vars->{site}->{store_currency},
			     error => loc('Ошибка'),
			         p => $data->{result},
		};
	my $params = $data->{result};
	quick_insert(
		'store_delivery', {
			site_id => vars->{site}->{site_id},
			title   => $params->{title},
			body	=> $params->{body},
			price   => $params->{price},
		}
	);
	my $delivery_id = last_insert_id();
	return redirect "/admin/store/delivery/$delivery_id/edit/"
		if params->{action} eq 'apply';
	redirect '/admin/store/delivery';
};

get '/:id/edit/?' => sub {
	my $in   = params;
	my $data = validator($in, 'id_field.pl');

	$data->{valid} or return redirect '/admin/store/delivery';
	my $params = $data->{result};

	my $item = quick_select(
		'store_delivery', {
			site_id     => vars->{site}->{site_id},
			delivery_id => $params->{id},
		}
	);
	return redirect '/admin/store/delivery' unless $item;

	template '/admin/store/delivery/edit', {
		title    => loc('Доставка'),
		item	 => $item
	};
};

post '/:id/edit/?' => sub {
	my $in   = params;
	my $data = validator($in, 'store_delivery_form.pl');

	my $params = $data->{result};

	my $item = quick_select(
		'store_delivery', {
			site_id     => vars->{site}->{site_id},
			delivery_id => $params->{id},
		}
	);

	$data->{valid}
		or return template 'admin/store/delivery/edit', {
			item => $item,
			p    => $data->{result},
		};

	quick_update(
		'store_delivery', {
			site_id     => vars->{site}->{site_id},
			delivery_id => $params->{id}
		}, {
			title       => $params->{title},
			body        => $params->{body},
			price       => $params->{price},
		}
	);

	return redirect "/admin/store/delivery/$in->{id}/edit/"
		if params->{action} eq 'apply';
	redirect '/admin/store/delivery';
};
