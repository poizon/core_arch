package tools::store;

use Dancer ':syntax';
use Helpers;
use CGI::Struct::XS;

sub params_to_struct {
	my $params = shift;
	return unless ref $params eq 'HASH';
	return CGI::Struct::XS::build_cgi_struct($params);
}

sub get_cart {
	my $items = session->{cart} || {};
	my $qty   = 0;
	   $qty  += $_->{qty} for values %$items;
	return {
		items => $items,
		qty   => $qty
	}
}

### Finance

sub get_currency_code {
	return vars->{site}->{store_currency} || config->{default_currency} || "RUB";
}

sub get_currency {
	my $code = get_currency_code();
	return $currencies->{$code}->{symbol} || vars->{site}->{store_currency};
}

sub get_price {
	my $sum = shift or return;
	my $result = "";
	
	#$sum = sprintf("%.2f", $sum * vars->{site}->{store_pricefactor}) 
	#	if vars->{site}->{store_pricefactor};
	
	my $code = get_currency_code();
	my $currency = $currencies->{$code};
	my $symbol = $currency->{symbol};
	
	$result .= $symbol if !$currency->{reverse} && $symbol;
	$result .= $sum;
	$result .= " " . $symbol if $currency->{reverse} && $symbol;
	
	return $result;
}

### Categories

sub get_category {
	my $category_id = shift or return;
	return quick_select(
		'store_category', {
			category_id => $category_id,
			site_id     => vars->{site}->{site_id}
		}
	);
}

sub get_categories {
	my $access = shift // 'admin';
	my $parent = shift;
	
	my $where  = "WHERE site_id = ?";
	   $where .= " AND store_category.hidden = 0" if $access eq 'site';
	   $where .= " AND parent_id = $parent" if defined $parent;
	
	my $categories = sql_select(qq{
		SELECT store_category.*, COUNT(scr.category_id) count
		  FROM store_category
		  LEFT JOIN store_category_relations scr USING (category_id) $where
		 GROUP BY category_id
		 ORDER BY sort, category_id
	}, vars->{site}->{site_id});

	return $categories;
}

### Products

sub get_items {
	my $access      = shift // 'admin';
	my $category_id = shift;
	my $order       = shift // 'store_item.sort';
	
	my $where  = "WHERE site_id = ?";
	   $where .= " AND category_id = ?" if $category_id;
	   $where .= " AND store_item.hidden = 0" if $access eq 'site';

	return $category_id ?
		sql_select(qq{
			SELECT store_item.*
			  FROM store_item
			 RIGHT JOIN store_category_relations USING (item_id) $where
			 ORDER BY $order
		}, vars->{site}->{site_id}, $category_id)
	:
		sql_select(qq{
			SELECT store_item.*, COUNT(category_id) c
			  FROM store_item
			  LEFT JOIN store_category_relations USING (item_id) $where
			 GROUP BY item_id, category_id
			HAVING c = 0
			 ORDER BY $order
		}, vars->{site}->{site_id});
}

sub get_default_item_params {
	my $id = shift;

	my $rows = sql_select(qq{
		SELECT p.item_id, param_id, value_id, name, value, price
		  FROM store_item_param p
		  LEFT JOIN store_item_param_value v USING(param_id)
		 WHERE p.item_id=$id
	});

	my %params;
	for (@$rows) {
		$params{$_->{param_id}} = $_ unless exists $params{$_->{param_id}};
	}
	$params{$_} = [ @{$params{$_}}{qw/name value price/} ] for keys %params;
	return [ values %params ];
}

### Get product information

sub get_item_data {
	my $access = shift // 'admin';
	my $id = shift;

	my $item = quick_select(
		'store_item', {
			site_id => vars->{site}->{site_id},
			item_id => $id
		}
	) or return;

	my @photos = quick_select(
		'store_item_photo', {
			item_id  => $id,
			hidden   => 0
		}, {
			order_by => 'photo_id'
		}
	);

	$item->{related}    = tools::store::get_related_items($access, $id);
	$item->{params}     = tools::store::get_item_params($id);
	$item->{categories} = tools::store::get_item_categories($id);
	$item->{info}       = tools::store::get_item_info($id);
	$item->{photos}     = \@photos;

	return $item;
}

sub get_item_info {
	my $id = shift;
	my @info = quick_select(
		'store_item_info', {
			item_id  => $id
		}, {
			order_by => 'info_id'
		}
	);
	return \@info;
}

sub get_item_categories {
	my $item_id = shift;

	return sql_select(qq{
		SELECT c.category_id, c.title
		  FROM store_category c
		  LEFT JOIN store_category_relations scr USING (category_id)
		 WHERE c.site_id = ? AND scr.item_id = ?
		 ORDER BY c.category_id
	}, vars->{site}->{site_id}, $item_id);
}

sub get_item_params {
	my $id = shift;

	my @params = quick_select(
		'store_item_param', {
			item_id  => $id,
		}, {
			order_by => 'item_id',
		}
	);

	my @values = ();
	@values = quick_select(
		'store_item_param_value', {
			param_id  => [ map { $_->{param_id} } @params ],
		}
	) if @params;

	my $values_hash = {};
	push @{$values_hash->{ $_->{param_id} }}, $_ for @values;
	$_->{param_values} = $values_hash->{ $_->{param_id} } || [] for @params;

	return \@params;
}

sub get_related_items {
	my $access = shift // 'admin';
	my $id = shift or return;
	my $sql = $access eq 'site' ? 'AND store_item.hidden = 0' : '';


	my $related_products = sql_select(qq{
		SELECT store_item.*
		  FROM store_item_more
		  JOIN store_item USING (item_id)
		 WHERE parent_id = ? AND site_id = ? $sql
		 ORDER BY more_id
	}, $id, vars->{site}->{site_id});

	return $related_products;
}

### Payments

our %PAYMETHODS = (
	robokassa => [qw/
		robokassa_mrh_login
		robokassa_mrh_pass1
		robokassa_mrh_pass2
	/],
);

sub get_paymethod_params_names {
	my ($method_name) = @_;

	return $PAYMETHODS{ $method_name } || [];
}

sub get_available_paymethods {
	my @paymethods_data = quick_select(
		'store_checkout', {
			site_id => vars->{site}->{site_id}
		}
	);

	my $check_params = {};
	for my $paymethod (keys %PAYMETHODS) {
		$check_params->{ $paymethod } = { map { $_ => 1 }  @{ $PAYMETHODS{$paymethod} } };
	}

	my %paymethods = ();
	for my $data (@paymethods_data) {
		my $paymethod = $data->{paymethod};
		my $name      = $data->{param_name};

		next unless $check_params->{ $paymethod };
		next unless $check_params->{ $paymethod }->{ $name };
		next unless $data->{param_value};
		$paymethods{ $paymethod }{ $name } = $data->{param_value};
	}

	# filter incomplete data & invalid conditions:
	for my $method (keys %paymethods) {
		delete $paymethods{ $method }
			if keys %{ $paymethods{ $method } } < @{ $PAYMETHODS{ $method } };
	}

	return \%paymethods;
}

### Cover upload

sub upload_cover {
	my ($table, $id_name, $id, $old_cover) = @_;

	my $cover = upload('cover');
	my $cover_filename = $cover->{filename};

	my $file_path = "$Bin/../public/store/" . vars->{site}->{dir};
	make_path($file_path) if ! -e $file_path;

	$cover_filename = pick_filename($cover_filename, $file_path) if -e "$file_path/$cover_filename";

	unlink "$file_path/$old_cover" if $old_cover;
	$cover->copy_to("$file_path/$cover_filename");

	quick_update(
		$table, {
			$id_name => $id,
		}, {
			cover    => $cover_filename,
		}
	);
}

true;
