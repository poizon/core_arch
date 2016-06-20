package admin::api::store::delivery;

use Dancer ':syntax';
use Helpers;

use Dancer::Plugin::REST;
prepare_serializer_for_format;

prefix '/admin/api/store/delivery';

post '/freedelivery.:format' => sub {
    my $in   = params;
    my $data = validator($in, 'store_freedelivery_form.pl');

    $data->{valid}
        or return to_json {
            error  => loc('Ошибка'),
            fields => $data->{result}
        };
    my $params = $data->{result};

    quick_update(
        'sites', {
            site_id => vars->{site}->{site_id}
        }, {
            store_freedelivery => $params->{store_freedelivery}
        }
    );

    status_ok { result => 'ok' };
};

del '/freedelivery.:format' => sub {
    quick_update(
        'sites', {
            site_id => vars->{site}->{site_id}
        }, {
            store_freedelivery => 'null',
        }
    );
    status_ok { result => 'ok' };
};

del '/:id.:format' => sub {
    my $in   = params;
    my $data = validator($in, 'id_field.pl');

    $data->{valid}
        or return to_json {
            error  => loc('Ошибка'),
            fields => $data->{result}
        };
    my $p = $data->{result};

    quick_delete(
        'store_delivery', {
            site_id     => vars->{site}->{site_id},
            delivery_id => $p->{id}
        }
    );

    status_ok { result => 'ok' };
};

true;
