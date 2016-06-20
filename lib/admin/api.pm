package admin::api;

use Dancer ':syntax';
use Helpers;

use admin::api::pages;
use admin::api::gallery;
use admin::api::files;
use admin::api::store;
use admin::api::settings;

use Dancer::Plugin::REST;
prepare_serializer_for_format;

prefix '/admin/api';

## News
post '/news/:id/hide.:format' => sub { _hide('news', 'news_id') };
post '/news/:id/show.:format' => sub { _show('news', 'news_id') };

del '/news/:id.:format' => sub { _delete('news', 'news_id') };

## Events
post '/events/:id/hide.:format' => sub { _hide('events', 'event_id') };
post '/events/:id/show.:format' => sub { _show('events', 'event_id') };

del '/events/:id.:format' => sub { _delete('events', 'event_id') };

## Blogs
post '/blog/:id/hide.:format' => sub { _hide('blog_posts', 'post_id') };
post '/blog/:id/show.:format' => sub { _show('blog_posts', 'post_id') };

del '/blog/:id.:format' => sub { _delete('blog_posts', 'post_id') };
del '/blog/comments/:id.:format' => sub { _delete('blog_comments', 'comment_id') };

## Pages
post '/page/:id/hide.:format' => sub { _hide('pages', 'page_id') };
post '/page/:id/show.:format' => sub { _show('pages', 'page_id') };

del '/page/:id.:format' => sub { _delete('pages', 'page_id') };
del '/page/folder/:id.:format' => sub { _delete('pages_folders', 'folder_id') };

## Gallery
post '/gallery/album/:id/hide.:format' => sub { _hide('gallery_albums', 'album_id') };
post '/gallery/album/:id/show.:format' => sub { _show('gallery_albums', 'album_id') };

post '/gallery/album/:album_id/photo/:id/hide.:format' => sub { _hide('gallery_photos', 'photo_id') };
post '/gallery/album/:album_id/photo/:id/show.:format' => sub { _show('gallery_photos', 'photo_id') };

## Store
post '/store/category/:id/hide.:format' => sub { _hide('store_category', 'category_id') };
post '/store/category/:id/show.:format' => sub { _show('store_category', 'category_id') };

del '/store/coupon/:id.:format' => sub { _delete('store_coupon', 'coupon_id') };

## Forms
del '/forms/:id.:format' => sub { _delete('form_info', 'form_id') };

## Store settings
post '/store/settings/:id/hide.:format' => sub { _hide('store_order_data', 'data_id') };
post '/store/settings/:id/show.:format' => sub { _show('store_order_data', 'data_id') };

post '/store/settings/:id/required_on.:format'  => sub { _required('store_order_data', 'data_id', 1) };
post '/store/settings/:id/required_off.:format' => sub { _required('store_order_data', 'data_id', 0) };

del '/store/settings/:id.:format' => sub { _delete('store_order_data', 'data_id') };

## Routines

sub _show {
	my ($table, $id) = @_;
	quick_update($table, { $id => params->{id}, site_id => vars->{site}->{site_id} }, { hidden => 0 });
	status_ok { result => 'ok' };
}

sub _hide {
	my ($table, $id) = @_;
	quick_update($table, { $id => params->{id}, site_id => vars->{site}->{site_id} }, { hidden => 1 });
	status_ok { result => 'ok' };
}

sub _required {
	my ($table, $id, $value) = @_;
	quick_update($table, { $id => params->{id}, site_id => vars->{site}->{site_id} }, { required => $value });
	status_ok { result => 'ok' };
}

sub _delete {
	my ($table, $id) = @_;
	quick_delete($table, { $id => params->{id}, site_id => vars->{site}->{site_id} });
	status_ok { result => 'ok' };
}

true;
