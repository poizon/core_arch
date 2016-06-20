package admin::api::store::orders;

use Dancer ':syntax';
use Helpers;

use Dancer::Plugin::REST;

prepare_serializer_for_format;
prefix '/admin/api/store/orders';

put '/:id/status' => sub {
    quick_update(
        'store_order', {
            site_id  => vars->{site}->{site_id},
            order_id => params->{id}
        }, {
            status   => params->{status}
        }
    );

    return to_json { result => 'ok' };
};

del '/:order_id/items/:id.:format' => sub {
    quick_delete(
        'store_order_item', {
            id       => params->{id},
            order_id => params->{order_id}
        }
    );
    _recalculate_order_amount(params->{order_id});

    status_ok { result => 'ok' };
};

post '/:order_id/items/:id/set-qty.:format' => sub {
    quick_update(
        'store_order_item', {
            id       => params->{id},
            order_id => params->{order_id}
        }, {
            qty      => params->{qty}
        }
    );
    _recalculate_order_amount(params->{order_id});

    my $item = quick_select('store_order_item', { id => params->{id} });

    status_ok { result => 'ok', amount => $item->{price} * params->{qty} };
};

sub _recalculate_order_amount {
    my ($order_id) = @_;

    sql(qq{
        UPDATE store_order o
            SET amount = (
                SELECT COALESCE(SUM(qty * price), 0)
                    FROM store_order_item i
                WHERE i.order_id = ?
            )
        WHERE o.order_id = ? AND o.site_id = ?
    }, $order_id, $order_id, vars->{site}->{site_id});
}

true;
