package admin;

use Dancer ':syntax';
use Helpers;
use tools::date;

use admin::api;
use admin::news;
use admin::blog;
use admin::gallery;
use admin::menu;
use admin::pages;
use admin::files;
use admin::store;
use admin::events;
use admin::forms;
use admin::settings;

prefix '/';

get "/admin" => sub { 
	my $redirect = "admin/pages";
	$redirect .= "?tutorial" if defined params->{tutorial};
	redirect $redirect;
	
	# TODO: dashboard
};

get "/admin/logout" => sub {
	session 'user_id' => undef;
	redirect "http://" . config->{appdomain} . "/account/logout"
};

# Set language
get '/admin/language/:lang' => sub {
	session lang => params->{lang};
	redirect request->referer // '/admin/';
};

get "/signin/:lang/:hash" => sub {
	session lang => params->{lang};
	return redirect "/admin" if session->{user_id};
	return redirect "http://" . config->{appdomain} unless params->{hash};
	my $date = tools::date::prepare_date_info()->{current} . (localtime)[2];
	
	my $checksum = md5_hex(
		vars->{site}->{site_id},
		vars->{site}->{user_id},
		config->{salt},
		$date
	);
	
	return redirect "http://" . config->{appdomain}
		if $checksum ne params->{hash};
		
	quick_insert("logs", { 
		ip => request->remote_address, 
		ua => request->user_agent, 
		domain => request->host 
	}) unless params->{'skip-log'};	
		
	session user_id => vars->{site}->{user_id};
	my $redirect = "/admin";
	$redirect   .= '?tutorial' if defined params->{tutorial};
	redirect $redirect;
};

true;
