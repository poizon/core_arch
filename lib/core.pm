package core;

use Dancer ':syntax';
use Helpers;
use tools::date;

use admin;
use site;

set layout => "admin";

hook 'before' => sub {
	my ($path, $uid) = ( request->path, session->{user_id} );
	return if $path =~ m:/admin/logout:;
	return redirect "http://" . config->{appdomain} . "/login"
		if !$uid && $path =~ m:^/admin/: && config->{environment} eq 'production';

	my $site = sql_row(
		qq{
			SELECT
				s.*, s.paid_till > NOW() premium,
				u.lang, u.country, u.email,
				d1.unicode domain,
				d2.unicode default_domain, d2.ascii ascii_domain,
				TO_DAYS(CURRENT_DATE) - TO_DAYS(s.regdate) age
			FROM sites s
				LEFT JOIN domains d1 ON d1.site_id   = s.site_id
				LEFT JOIN domains d2 ON d2.domain_id = s.default_domain
				LEFT JOIN users   u  ON u.user_id    = s.user_id
			WHERE
				d1.ascii = ?
		}, _get_domain()
	);
	$site->{dir} = site_dir($site->{site_id});
	var site => $site;

	# redirect to default domain
	return redirect "http://" . $site->{default_domain} . $path
		if $site->{domain} && $site->{domain} ne $site->{default_domain};

	return redirect '/'
		if $path ne '/' && ( !$site->{site_id} || $site->{blocked} );

	return if $path =~ m:^/(admin|signin):i;

	if ($site->{disable}) {
		redirect '/' if $path ne '/';
	} elsif ($site->{premium}) {
		# redirect service
		my $destination = quick_lookup(
			"redirects", {
				site_id => $site->{site_id},
				source  => $path
			}, "destination"
		);
		redirect $destination, 301 if $destination;
	}
};

hook 'before_template' => sub {
	my $tokens = shift;
	my $domain = vars->{site}->{domain} // _get_domain();

	$tokens->{lang} = session->{lang} || vars->{site}->{lang} || config->{default_lang};
	$tokens->{path} = [ split '/', request->path ];
	$tokens->{date} = tools::date::prepare_date_info();

	#$tokens->{blocks}   = { map { $_->{place_id} => $_->{body} } quick_select('blocks', { site_id => vars->{site}->{site_id} }) };
	#$tokens->{can_edit} = vars->{site}->{user_id} == (session('user_id') || 0) || config->{environment} ne 'production';

	$tokens->{languages}   = $languages;
	$tokens->{production}  = config->{environment} eq 'production' ? true : false;
	$tokens->{internal}    = $domain =~ config->{appdomain} ? true : false;
	$tokens->{get_price}   = sub { tools::store::get_price(@_) };
	$tokens->{admin_theme} = session->{theme} || config->{theme} || 'adminflare';
};

# Temporary solution for errors
hook 'before_error_init' => sub {
	my $self = shift;
	open FD, ">>errors.txt";
	print FD $self->{message}, request->host, request->uri;
	print FD "\n", "=" x 20, "\n";
	close FD;
};

sub _get_domain {
	my $domain = lc(request->host);
	$domain =~ s/:\d+$//;
	$domain =~ s/^www\.//;
	return $domain;
}

true;
