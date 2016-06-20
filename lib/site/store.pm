package site::store;

use Dancer ':syntax';
use Helpers;
use MIME::Base64;

use site::store::cart;
use site::store::payments;
use site::store::export;

use tools::store;

prefix '/store';

get '/' => sub {
	render_template('store/index', {
		title      => loc("Интернет-магазин"),
		categories => tools::store::get_categories('site', 0),
		cart       => tools::store::get_cart(),
		currency   => tools::store::get_currency(),
		items      => tools::store::get_items('site')
	});
};

# Category page
get qr{/category/(\d+)/?} => sub {
	my ($category_id) = splat;

	return redirect '/store'
		if params->{order} && !grep { params->{order} eq $_ } qw/title price/;

	my $category = tools::store::get_category($category_id);

	render_template('store/category', {
		category   => $category,
		title      => $category->{title},
		cart       => tools::store::get_cart(),
		currency   => tools::store::get_currency(),
		categories => tools::store::get_categories('site', $category_id),
		items      => tools::store::get_items('site', $category_id, params->{order})
	});
};

# Product page
get '/item/:id/?' => sub {
	my $item = tools::store::get_item_data('site', params->{id});
	return redirect '/store' if !$item || $item->{hidden};

	render_template('store/item', {
		title    => $item->{title},
		item     => $item,
		currency => tools::store::get_currency(),
		cart     => tools::store::get_cart(),
	});
};

### Delivery
get '/delivery/select/?' => sub {
	my @delivery = quick_select(
		'store_delivery', {
			site_id => vars->{site}->{site_id}
		}
	);
	render_template 'store/delivery', {
		title    => loc('Доставка'),
		delivery => \@delivery,
		currency => tools::store::get_currency(),
	};
};

post '/delivery/select/?' => sub {

	my $delivery = quick_select(
		'store_delivery', {
			site_id     => vars->{site}->{site_id},
			delivery_id => params->{delivery_id},
		}
	) or return redirect '/store/delivery/select';

	quick_update(
		'store_order', {
			site_id  => vars->{site}->{site_id},
			order_id => session->{order_id},
		}, {
			amount => \"amount + $delivery->{price}",
			delivery_title => $delivery->{title},
			delivery_price => $delivery->{price},
		}
	);

	my $available_paymethods = tools::store::get_available_paymethods();
	redirect keys %$available_paymethods ?
		'/store/paymethod/select' :
		'/store/order/complete';
};

### Order Complete
get '/order/complete/?' => sub {
	my $order = _get_order(session->{order_id});
	$order->{data} = from_json($order->{data}, { utf8 => 0 });
	my @items = quick_select('store_order_item', { order_id => $order->{order_id} });
	$_->{params_decoded} = from_json($_->{params}, { utf8 => 0 }) for @items;
	my $stash = { order => $order, items => \@items };
        
	if ($order->{promocode}) {
		my $coupon = quick_select('store_coupon', { code => $order->{promocode} });
		$stash->{coupon} = $coupon if $coupon;
	}

	# Prepare email
	my $subject = loc('Заказ на сайте %1 2%', [ vars->{site}->{domain}, 
        vars->{site}->{store_order_prefix} . $order->{order_id} . 
	vars->{site}->{store_order_suffix}];
	utf8::encode($subject); # remove utf8 flag to have bytes
	$subject = '=?UTF-8?B?' . encode_base64($subject) . '?=';

	my $body = template 'email/order', $stash, { layout => undef };

	if (config->{environment} eq 'production') {
		email {
			from    => $order->{email},
			to      => vars->{site}->{email},
			subject => $subject,
			body    => $body,
			type    => 'html'
		};

		email {
			from    => vars->{site}->{email},
			to      => $order->{email},
			subject => $subject,
			body    => $body,
			type    => 'html'
		};
	}

	my $confirmation = vars->{site}->{store_confirmation} ||
		loc('Ваш заказ принят. В ближайшее время с вами свяжутся.');
	$confirmation = $body if config->{environment} ne 'production';

	render_template 'index', {
		title => loc("Интернет-магазин"),
		body  => $confirmation
	};
};

sub _get_order {
	my $id = shift or return;
	return quick_select(
		'store_order', {
			site_id  => vars->{site}->{site_id},
			order_id => $id
		}
	);
}


true;
