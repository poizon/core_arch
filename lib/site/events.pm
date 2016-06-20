package site::events;

use Dancer ':syntax';
use Helpers;

use Calendar::Simple qw/ calendar /;
use List::Util qw/ minstr maxstr max /;

prefix '/';

# $calendar = get_calendar({ year => $year, month => month })
sub get_calendar {
	my $args = shift;
	my $calendar; # for return

	# Detect current date
	my $formatter =  format_date('%F'); # YYYY-mm-dd - the ISO 8601 date format
	my $today     = $formatter->(time);
	my ( $today_year, $today_month, $today_day ) = split '-', $today;
	$calendar->{'today'}     = $today;
	$calendar->{'today_day'} = $today_day;

	# Get year and month or use today
	my $year =  int( $args->{'year'}  // $today_year  );
	my $month = int( $args->{'month'} // $today_month );
	$calendar->{'is_current_year'}  = 1 if $year  == $today_year;
	$calendar->{'is_current_month'} = 1 if $month == $today_month;

	my $month_prev = ($month - 2) % 12 + 1;
	my $month_next =  $month      % 12 + 1;

	# TODO get more precise method
	my $week_starts_at
		= ( session 'lang' eq 'en' )
		? 0  # Sunday
		: 1; # Monday

	# days of week: ( su mo tu we... )
	my @two_week_days = ( split ' ', loc('su mo tu we th fr sa') ) x 2;
	my @weekdays = splice @two_week_days, $week_starts_at, 7;
	$calendar->{'weekdays'} = \@weekdays;

	# calendar: [ [ x x x 1 2 3 4], [ 5 6 7 8...], ... ]
	my $cal = calendar($month, $year, $week_starts_at);
	$calendar->{'calendar'} = $cal;
	# maximal number of day in last week
	$calendar->{'days_in_month'} = max grep { defined } @{$cal->[$#$cal]};

	# copy
	$calendar->{'year'}  = $year;
	$calendar->{'month'} = $month;

	$calendar->{'month_prev'} = $month_prev;
	$calendar->{'month_next'} = $month_next;

	my @monthnames
		= qw( none
			January February March
			April May June
			July August September
			October November December
		);

	$calendar->{'monthname'}      = $monthnames[ $month ];
	$calendar->{'monthname_prev'} = $monthnames[ $month_prev ];
	$calendar->{'monthname_next'} = $monthnames[ $month_next ];

	return $calendar;
}


# @non_empty_days = find_events($calendar, @events);
sub find_events {
	my $calendar    = shift or return;
	my $year        = $calendar->{'year'};
	my $month       = $calendar->{'month'};
	my $month_start = sprintf('%04d-%02d-01',   $year, $month);
	my $month_end   = sprintf('%04d-%02d-%02d', $year, $month, $calendar->{'days_in_month'});

	my @events = @_;
	my @days_with_events = ( 0 ) x 31; # maximal number

	foreach my $event ( @events ) {
		# Last 2 digits of event span in this month
		my $day_start = substr maxstr( $month_start, $event->{'date_start'} ), 8, 2;
		my $day_end   = substr minstr( $month_end,   $event->{'date_end'  } ), 8, 2;
		#debug "day span: $event->{'date_start'}..$event->{'date_end'  } => $day_start..$day_end";

		$days_with_events[$_] = 1 for ( $day_start .. $day_end );
		#unshift @days_with_events, 1; # move days and add flag for existence of @days_with_events
	}

	return @days_with_events;
}


# Events for day
get qr{/calendar/(\d+)/(\d+)/(\d+)/?} => sub {
	my ( $year, $month, $day ) = splat;
	my $limit  = config->{per_page}->{events} // 10;

	my $criteria = {
		site_id => vars->{site}{site_id},
		hidden  => 0,
		date_start => { 'le' => sprintf('%04d-%02d-%02d', $year, $month, $day) },
		date_end   => { 'ge' => sprintf('%04d-%02d-%02d', $year, $month, $day) },
	};

	my $total_events = quick_count(
		'events', $criteria,
	);

	my $pager  = pager($limit, $total_events);
	my $offset = $pager->from;

	my @events = quick_select(
		'events', $criteria, {
			order_by => 'date_start',
			limit    => $limit,
			offset   => $offset,
		}
	);

	my $calendar = get_calendar({
		month => $month,
		year  => $year,
	});

	my @non_empty_days = find_events($calendar, @events);

	render_template(
		'events/index', {
			title              => loc('Calendar'),
			events             => \@events,
			calendar           => $calendar,
			days_with_events   => \@non_empty_days,
			pager              => $pager,
		}
	);
};


# Events for month
get qr{/calendar/(\d+)/(\d+)/?} => sub {
	my ( $year, $month ) = splat;
	my $limit  = config->{per_page}->{events} // 10;

	my $criteria = {
		site_id => vars->{site}{site_id},
		hidden  => 0,
		date_start => { 'le' => sprintf('%04d-%02d-31', $year, $month) },
		date_end   => { 'ge' => sprintf('%04d-%02d-01', $year, $month) },
	};

	my $total_events = quick_count(
		'events', $criteria,
	);

	my $pager  = pager($limit, $total_events);
	my $offset = $pager->from;

	my @events = quick_select(
		'events', $criteria, {
			order_by => 'date_start',
			limit    => $limit,
			offset   => $offset,
		}
	);

	debug 'lang = ' . session 'lang';
	my $calendar = get_calendar({
		month => $month,
		year  => $year,
	});

	my @non_empty_days = find_events($calendar, @events);

	render_template(
		'events/index', {
			title    => loc('Calendar'),
			events   => \@events,
			calendar => $calendar,
			pager    => $pager,
			days_with_events => \@non_empty_days,
		}
	);
};


# Events for year
get qr{/calendar/(\d+)/?} => sub {
	my ( $year ) = splat;
	my $limit = config->{per_page}->{events} // 10;

	my $criteria = {
		site_id => vars->{site}{site_id},
		hidden  => 0,
		date_start => { 'le' => sprintf('%04d-12-31', $year) },
		date_end   => { 'ge' => sprintf('%04d-01-01', $year) },
	};

	my $total_events = quick_count(
		'events', $criteria,
	);

	my $pager  = pager($limit, $total_events);
	my $offset = $pager->from;

	my @events = quick_select(
		'events', $criteria, {
			order_by => 'date_start',
			limit    => $limit,
			offset   => $offset,
		}
	);

	render_template(
		'events/index', {
			title  => "$year - " . loc('Calendar'),
			events => \@events,
			pager  => $pager,
			year   => $year,
			months => [qw(
				January February March
				April May June
				July August September
				October November December
			)],
		}
	);
};


# Upcoming events
get qr{/calendar/?} => sub {

	my $calendar = get_calendar;

	my $limit  = config->{per_page}->{events} // 10;

	my $criteria = {
		site_id => vars->{site}{site_id},
		hidden  => 0,
		date_end   => { 'ge' => $calendar->{'today'} },
	};

	my $total_events = quick_count(
		'events', $criteria,
	);

	my $pager  = pager($limit, $total_events);
	my $offset = $pager->from;

	my @events = quick_select(
		'events', $criteria, {
			order_by => 'date_start',
			limit    => $limit,
			offset   => $offset,
		}
	);

	my @non_empty_days = find_events($calendar, @events);

	render_template(
		'events/index', {
			title    => loc('Calendar'),
			events   => \@events,
			pager    => $pager,
			calendar => $calendar,
			days_with_events => \@non_empty_days,
		}
	);
};


# All-time events
get '/events' => sub {

	my $limit  = config->{per_page}->{events} // 10;

	my $criteria = {
		site_id => vars->{site}{site_id},
		hidden  => 0,
	};

	my $total_events = quick_count(
		'events', $criteria,
	);

	my $pager  = pager($limit, $total_events);
	my $offset = $pager->from;

	my @events = quick_select(
		'events', $criteria, {
			order_by => 'date_start',
			limit    => $limit,
			offset   => $offset,
		}
	);

	render_template(
		'events/index', {
			title  => loc('All-time events'),
			events => \@events,
			pager  => $pager,
		}
	);
};


get qr{/events/(\d+)/?} => sub {

	my @args = splat;
	my $id   = pop @args || 0;

	my $item = quick_select('events', {
		event_id => $id,
		site_id  => vars->{site}{site_id}
	})
		or status 404; # Not found

	render_template(
		'events/item', {
			title => $item->{title} // loc('Event not found'),
			item  => $item,
			#// loc('The requested event was not found.'),
			# <a href="/calendar">See upcoming events</a>.'),
			status => status,
		}
	);
};

true;
