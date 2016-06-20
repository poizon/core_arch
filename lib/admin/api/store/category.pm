package admin::api::store::category;

use Dancer ':syntax';
use Helpers;

use Dancer::Plugin::REST;
prepare_serializer_for_format;

prefix '/admin/api/store/category';

del '/:id.:format' => sub {
    my $in   = params;
    my $data = validator($in, 'id_field.pl');

    $data->{valid}
        or return to_json {
            error  => loc('Ошибка'),
            fields => $data->{result}
        };
    my $params = $data->{result};

    quick_delete( # return '0E0' if no rows deleted
        'store_category', {
            category_id => $params->{id},
            site_id     => vars->{site}->{site_id}
        }
    );

    quick_delete( # TODO: there is not check for site_id
        'store_category_relations', {
            category_id => $params->{id}
        }
    );

    status_ok { result => 'ok' };
};


post '/move.:format' => sub {
    return to_json { status => loc('Ничего не найдено') } unless params->{id};

    my $element = quick_select(
        'store_category', {
            site_id     => vars->{site}->{site_id},
            category_id => params->{id},
        }
    );
    return to_json { status => loc('Ничего не найдено') } unless $element;

    if ($element->{parent_id} != params->{new_parent}) {
        quick_update(
            'store_category', {
                category_id => $element->{category_id},
            }, {
                parent_id   => params->{new_parent},
            }
        );
    }
    _store_sort_update('store_category', 'category_id');
};

post '/sort/items.:format' => sub {
    _store_sort_update('store_item', 'item_id');
};

post '/move/items.:format' => sub {
    my $in = params;
    my $id = $in->{category_id} || undef;
    my $to = $in->{to_category_id} || undef;

    if ($id && $to) {

        # remove link $to category already
        sql(qq{
            DELETE sr2
            FROM store_category_relations sr2
            INNER JOIN store_category_relations sr1 USING (item_id)
            INNER JOIN store_item i USING (item_id)
            WHERE i.site_id = ? AND sr1.category_id = ? AND sr2.category_id = ?
        }, vars->{site}->{site_id}, $id, $to );

        # move from category to category
        sql(qq{
            UPDATE store_category_relations scr
            JOIN store_item i USING (item_id)
            SET scr.category_id = ?
            WHERE i.site_id = ? AND scr.category_id = ?
        }, $to, vars->{site}->{site_id}, $id);


    } elsif(!$id && $to) {

        # move from unsorted to category
        sql(qq{
            INSERT INTO store_category_relations(category_id, item_id)
                SELECT ?, i.item_id
                FROM store_item i
                LEFT JOIN store_category_relations scr USING (item_id)
                WHERE i.site_id = ?
                GROUP BY i.item_id, scr.category_id
                HAVING COUNT(scr.category_id) = 0
        }, $to, vars->{site}->{site_id});

    } elsif($id && !$to) {

        # move from category to unsorted
        sql(qq{
            DELETE store_category_relations
            FROM store_category_relations
            INNER JOIN store_item USING (item_id)
            WHERE site_id = ? AND category_id = ?
        }, vars->{site}->{site_id}, $id );

    }

    status_ok { result => 'ok' };
};

sub _store_sort_update {
    my ($table, $id)  = @_;
    my $in = params;
    my @ids = split(',', $in->{ids} || '');

    return to_json { error => loc('Ошибка') } unless @ids;

    my $items_count = quick_count(
        $table, {
            $id     => \@ids,
            site_id => vars->{site}->{site_id},
    });

    return to_json { error => loc('Ошибка') } if $items_count != @ids;

    my $update_sql = "INSERT INTO $table ($id, sort) VALUES "
        . join(',', ('(?, ?)') x @ids)
        . ' ON DUPLICATE KEY UPDATE `sort`=VALUES(`sort`)';

    my @update_params = ();
    my $priority = $in->{offset} || 0;
    push(@update_params, $_, $priority++) for @ids;

    sql($update_sql, @update_params);

    status_ok { result => 'ok' };
};

true;
