package admin::store::orders;

use Dancer ':syntax';
use Helpers;

our %STATUSES = (
	'NEW'     => 'Новый',
	'PENDING' => 'В обработке',
	'DONE'    => 'Завершен',
	'FAIL'    => 'Отменен',
);

prefix '/admin/store/orders';

get '/' => sub {
	my $status   = params->{status};
	my $criteria = { site_id => vars->{site}->{site_id} };
	$criteria->{status} = $status if $status;

	my $limit = config->{per_page}->{orders} || 30;
	my $total = quick_count('store_order', $criteria);
	my $pager = pager($limit, $total);
	my $site = quick_select('sites',{ site_id => vars->{site}->{site_id} } );

	my @orders = quick_select(
		'store_order',
		$criteria, {
			limit    => $limit,
			offset   => $pager->from || 0,
			order_by => { desc => 'order_id' },
		}
	);

	return redirect '/admin/store' unless @orders;

	my @items = quick_select(
		'store_order_item', {
			order_id => [ map { $_->{order_id} } @orders ],
		}
	);

	my $items = {};
	push @{$items->{ $_->{order_id} }}, $_ for @items;
	$_->{items} = $items->{ $_->{order_id} } || [] for @orders;

	template 'admin/store/orders/index', {
		title    => loc("Заказы"),
		orders   => \@orders,
		statuses => \%STATUSES,
		site     => $site,
		pager    => $pager,
	};
};

get '/:id' => sub {
	my $order = quick_select(
		'store_order', {
			site_id  => vars->{site}->{site_id},
			order_id => params->{id},
		}
	);

	my @products = quick_select(
		'store_order_item', {
			order_id => $order->{order_id},
		}, {
			order_by => 'item_id',
		}
	);

	my $fields = from_json($order->{data}, { utf8 => 0 });
	$_->{params_decoded} = from_json($_->{params}, { utf8 => 0 }) for @products;

	template 'admin/store/orders/view', {
		title    => loc("Заказы"),
		order    => $order,
		fields   => $fields,
		products => \@products,
		statuses => \%STATUSES,
	};
};

true;
