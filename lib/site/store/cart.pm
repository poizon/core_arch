package site::store::cart;

use Dancer ':syntax';
use MIME::Base64;

use Helpers;
use tools::store;

prefix '/store/cart';

### API methods

# params:
# 	id: Int
#	param: [[name, val, price], [name, val, price]]
post '/item/?' => sub {
	my $body = request->body || "{}";

	my $in   = from_json $body;
	my $data = validator($in, 'store_cart_add_form.pl');
	$data->{valid}
		or return to_json {
			error  => loc('Ошибка'),
			fields => $data->{result}
		};
	my $params = $data->{result};
	unless (exists $params->{param}) {
		my $item_params = tools::store::get_default_item_params($params->{id});
		$params->{param} = $item_params;
	}
	my $cart   = tools::store::get_cart()->{items};
	my $cart_item_id = md5_hex($body);

	if ($cart->{$cart_item_id}) {
		$cart->{$cart_item_id}{qty} += 1;
	} else {
		$cart->{$cart_item_id} = {
			id    => $params->{id},
			param => $params->{param},
			qty   => 1
		};
	}
	session cart => $cart;
	$cart = tools::store::get_cart();

	return to_json { cart_items_cnt => $cart->{qty} };
};

put '/item/?' => sub {
	my $in = params;

	my $data = validator($in, 'store_item_quantity_update_form.pl');
	$data->{valid}
		or return to_json {
			error  => loc('Ошибка'),
			fields => $data->{result},
		};
	my $params = $data->{result};
	my $cart   = tools::store::get_cart()->{items};

	$cart->{ $params->{cart_item_id} }{qty} = $params->{quantity}
		if $cart->{ $params->{cart_item_id} };

	session cart => $cart;

	return to_json { result => 'ok'	};
};

del '/item/:cart_item_id/?' => sub {
	content_type 'application/json';

	my $cart = tools::store::get_cart()->{items};
	delete $cart->{ params->{cart_item_id} }
		or return to_json { error => loc('Ничего не найдено') };

	session cart => $cart;

	return to_json { result => 'ok' };
};

# Cart page
any '/' => sub {
	my $cart = tools::store::get_cart()->{items};

	my @items;
	my $total_price = 0;

	while ( my ($cart_item_id, $value) = each %$cart ) {
		my $item = quick_select('store_item', {
			item_id => $value->{id},
			site_id => vars->{site}->{site_id},
			hidden  => 0,
		});

		next unless $item;

		$item->{item_price}  = _get_price( $item, $value->{param} );
		$item->{total_price} = $value->{qty} * $item->{item_price};

		$item->{params}  = $value->{param};
		$item->{qty}     = $value->{qty};
		$item->{cart_id} = $cart_item_id;

		push @items, $item;
		$total_price += $item->{total_price};
	}

	my @store_data = quick_select('store_order_data', {
			site_id => vars->{site}->{site_id},
			hidden  => 0,
		}, {
			order_by => 'data_id',
		}
	);

	my $stash = {
		   total_price => $total_price,
		 check_coupons => scalar @{_get_available_coupons()},
		          cart => tools::store::get_cart(),
		      currency => tools::store::get_currency(),
		         items => \@items,
		        fields => \@store_data,
		         title => loc("Корзина")
	};

	return render_template('store/cart', $stash) if request->method eq 'GET';

	my $in = params;
	my %info_in = map { $_ => $in->{$_} } qw/phone email promocode/;

	my $data = validator(\%info_in, 'store_order_create.pl');
	my $fields = _validate_fields(\@store_data, $in);
	if (!$data->{valid} || !$fields->{valid}) {
		$stash->{error} = loc('Ошибка');
		$stash->{p}     = $data->{result};
		$stash->{f}     = {
			err   => $fields->{err},
			value => $fields->{value},
		};

		return render_template 'store/cart', $stash;
	}
	my $params = $data->{result};

	if (keys %$cart == 0) {
		$stash->{error} = loc('Ошибка');
		return render_template 'store/cart', $stash;
	}

	my $packed_data = { map { $_->{title} => $fields->{value}->{$_->{data_id}} || '' } @store_data };
	$packed_data = $packed_data ? to_json($packed_data, { pretty => 0 }) : '';

	# Start database transaction:
	database->begin_work;
	quick_insert('store_order', {
		site_id   => vars->{site}->{site_id},
		email     => $params->{email},
		phone     => $params->{phone},
		data      => $packed_data,
		promocode => $params->{promocode} || '',
		qty       => 0,
		amount    => 0,
		status    => 1,
	});
	my $order_id     = last_insert_id();
	my $order_params = { amount => 0, qty => 0 };

	for my $cart_item (values %$cart) {
		my $item = quick_select(
			'store_item', {
				site_id => vars->{site}->{site_id},
				item_id => $cart_item->{id},
				hidden  => 0,
			}
		);
		next unless $item;

		my $item_price = _get_price( $item, $cart_item->{param} );
		$order_params->{amount} += $item_price * $cart_item->{qty};
		$order_params->{qty}    += $cart_item->{qty};

		my %item_params = map { $_->[0] => $_->[1] } @{ $cart_item->{param} };
		quick_insert(
			'store_order_item', {
				price       => $item_price,
				item_id     => $item->{item_id},
				qty         => $cart_item->{qty},
				order_id    => $order_id,
				title       => $item->{title},
				description => $item->{description},
				params      => to_json \%item_params
			}
		);
	}

	if ($params->{promocode}) {
		my ($coupon_id, $discount) = _get_sale($params->{promocode}, $order_params->{amount});
		if ($coupon_id && $discount) {
			$order_params->{amount}            -= $discount;
			$order_params->{promocode_discount} = $discount;
		}
	}

	quick_update(
		'store_order', {
			site_id  => vars->{site}->{site_id},
			order_id => $order_id
		}, $order_params
	);
	database->commit;

	session cart => undef if config->{environment} eq 'production';

	### REDIRECT
	session 'order_id' => $order_id;

	my $deliveries_cnt = quick_count('store_delivery', { site_id => vars->{site}->{site_id} });
	return redirect '/store/delivery/select' if $deliveries_cnt;

	my $available_paymethods = tools::store::get_available_paymethods();
	return redirect '/store/paymethod/select' if keys %$available_paymethods;

	return redirect '/store/order/complete';
};

sub _get_sale {
	my ($promocode, $total_amount) = @_;

	return unless $promocode && $total_amount;
	my $coupons = _get_available_coupons();

	for my $coupon (@$coupons) {
		if ($coupon->{code} eq $promocode) {
			my $total = $coupon->{type} eq 'ABS' ?
				$coupon->{discount} >= $total_amount ?
					$total_amount : $coupon->{discount} :
				$coupon->{discount} * $total_amount / 100.0;

			quick_update(
				'store_coupon', {
					site_id   => vars->{site}->{site_id},
					coupon_id => $coupon->{coupon_id},
				}, {
					used      => \'used + 1',
				}
			);
			return ($coupon->{coupon_id}, $total);
		}
	}
	return (0, 0);
}

sub _get_available_coupons {
	return [] unless vars->{site}->{premium} && vars->{site}->{package} eq 'Business';
	my $coupons = sql_select(qq{
		SELECT * FROM store_coupon
		WHERE site_id  = ? AND
		    (date_start <= CURDATE() OR date_start IS NULL) AND
		    (date_end   >= CURDATE() OR date_end IS NULL) AND
		    `limit`     > `used`
	}, vars->{site}->{site_id});

	return $coupons;
}

sub _get_price {
	my ($item, $params) = @_;
	my $price = $item->{price_sale} // $item->{price};
	$price += ($_->[2] || 0) for @$params;
	return $price;
}

sub _validate_fields {
	my ($fields, $in) = @_;
	my $params = params2hash($in);
	$params = $params->{fields} || {};
	my $res = {
		valid => 1,
		err   => {},
		value => {},
	};
	return $res unless @$fields;
	for my $field (@$fields) {
		my $value = $params->{$field->{data_id}} || '';
		$res->{value}->{$field->{data_id}} = $value;
		if (!$value && $field->{required}) {
			$res->{err}->{$field->{data_id}} = 'Поле обязательно к заполнению';
			$res->{valid} = 0;
		}
	}
	return $res;
}

true;
