package site;

use Dancer ':syntax';
use Dancer::Plugin::Thumbnail;
use Helpers;

use site::blog;
use site::events;
use site::news;
use site::forms;
use site::seo;
use site::store;
use site::gallery;
#use site::editor;
use site::compatibility;

prefix '/';

get '/resize/:from' => sub {
	return if config->{environment} eq 'production';
	my $file = "$Bin/../public/" . params->{from} . "/" . params->{file};
	my $params = {};
	$params->{w} = params->{width} if params->{width};
	$params->{h} = params->{height} if params->{height};
	$params->{w} = 150 unless scalar keys %$params;
	return resize $file, $params if -e $file;
	status 404;
};

any qr{.*} => sub {
	my $url = _get_url();
	
	# Check for existing or block
	if (!vars->{site}->{site_id} || vars->{site}->{blocked}) {
		status 404 if vars->{site}->{blocked}; # todo: FIX IT (temp solution for domains)
		return template "error", {}, { layout => undef };
	} 
	
	# Check for disabled site
	return 
		template "error", { 
			title   => loc("Сайт временно отключен"),
			message => vars->{site}->{disable} 
		}, { 
			layout => undef 
		} 
			if vars->{site}->{disable};
	
	# Check for default page
	return redirect "/" if $url && $url eq vars->{site}->{default_page};
	
	# Render default empty page
	if (!$url && !vars->{site}->{default_page}) {
		return render_template(
			'index', {
				title   => vars->{site}->{domain},
				body    => loc("default.homepage"),
				noindex => 1
			}
		);
	}
	
	my $page = quick_select(
		'pages', {
			site_id => vars->{site}->{site_id},
			url     => $url || vars->{site}->{default_page},
			hidden  => 0
		}
	);
	
	status 404 unless $page || config->{compatibility} && config->{sape};

	render_template(
		'index', {
			title   => $page->{meta_title} || $page->{title} // loc('Ничего не найдено'),
			body    => $page->{body} // loc('Страница, которую вы читаете, не существует'),
			noindex => $page->{noindex},
			header  => $page->{title},
			
			meta_desc     => $page->{meta_description},
			meta_keywords => $page->{meta_keywords}
		}
	);
};

sub _get_url {
	my $url = request->path;
	$url =~ s/^\/|\/$//g;
	return $url;
}

true;
