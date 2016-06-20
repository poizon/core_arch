package admin::events;

use Dancer ':syntax';
use Helpers;

prefix '/admin/events';

# List
get '/' => sub {
	my @events = quick_select(
		"events", {
			site_id => vars->{site}->{site_id}
		}, {
			columns  => [ qw(title hidden event_id date_start date_end) ]	
		}
	);

	template 'admin/events/index', {
		events => \@events,
		title  => loc("Events")
	};
};

# Draw and process create/update form
any ['get', 'post'] => qr{/((\d+)/)?(add|edit)} => sub {

	my @args = splat;
	my $action = pop @args;
	my $id = pop @args || 0;

	my $title  = $action eq 'add' ? loc('New Event') : loc('Edit');
	my $event;

	# Draw form only when requested via GET
	if ( request->method() eq 'GET' ) {
		if ( $action eq 'edit' ) {

			$event = quick_select(
				'events', {
					event_id => $id,
					site_id  => vars->{site}->{site_id}
				}
			) or return redirect '/admin/events'; # Not found
		}

		return template 'admin/events/add', {
			event  => $event,
			title  => $title
		};
	}
	# else - via POST

	my $in    = params;
	my $data  = validator($in, 'event_form.pl');
	   $event = $data->{result};

	$data->{valid}
		or return template 'admin/events/add', {
			error  => loc('Ошибка'),
			event  => $data->{result},
			title  => $title
		};

	my $params = $data->{result};

	if ( $action eq 'add' ) {
		quick_insert(
			'events', {
				site_id     => vars->{site}->{site_id},
				title       => $params->{title},
				desc_short  => $params->{desc_short},
				desc_full   => $params->{desc_full},
				date_start  => $params->{date_start},
				date_end    => $params->{date_end},
				location    => $params->{location}
			}
		);
	}
	else {
		quick_update(
			'events', {
				event_id   => $id,
				site_id    => vars->{site}->{site_id}
			}, {
				title      => $params->{title},
				desc_short => $params->{desc_short},
				desc_full  => $params->{desc_full},
				date_start => $params->{date_start},
				date_end   => $params->{date_end},
				location   => $params->{location},
			}
		);
	}

	redirect '/admin/events';
};

true;
