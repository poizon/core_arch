package admin::store;

use Dancer ':syntax';
use Helpers;
use tools::store;

use admin::store::orders;
use admin::store::products;
use admin::store::categories;
use admin::store::coupons;
use admin::store::delivery;
use admin::store::payments;
use admin::store::settings;

prefix '/admin/store';

get '/' => sub {
	redirect '/admin/store/products';
};

true;
