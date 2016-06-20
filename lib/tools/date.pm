package tools::date;

use Dancer ':syntax';

### Date format routines

# COUNTRY_CODE => [ YEAR_MONTH_DAY, DATE_SEPARATOR, WEEK_START ]
my $DATE_FORMATS = {
	us      => [ 'mdy', '/', 7 ],
	ca      => [ 'mdy', '/', 7 ],
	il      => [ 'dmy', '/', 7 ],
	default => [ 'dmy', '.', 1 ],
};

# $iso_date = iso_date_from($any_date)
# convert dates to ISO 8601 date - YYYY-MM-DD

sub iso_date_from {
	my $date = shift or return;

	my @parts = split /\W+/, $date, 3;
	map { $parts[$_] //= 0 } 0 .. 2;

	# https://ru.wikipedia.org/wiki/Календарная_дата
	# http://www.tetran.ru/SiteContent/Details/25

	my $format = $DATE_FORMATS->{ vars->{site}->{country} || "default" } || $DATE_FORMATS->{default};

	# Reorder parts
	@parts = @parts[2, 1, 0] if $format->[0] eq 'dmy';
	@parts = @parts[2, 0, 1] if $format->[0] eq 'mdy';
	@parts = @parts[0, 2, 1] if $format->[0] eq 'ydm';

	return sprintf '%04d-%02d-%02d', @parts;
}

# Validate ISO 8601 (YYYY-MM-DD) date
# Return error message for invalid dates and undef when data is valid.
sub validate_date {
	my @parts = split '-', shift; # ISO 8601 date - YYYY-MM-DD

	return 'Invalid date'
		if $parts[1] < 1
		|| $parts[1] > 12
		|| $parts[2] < 1
		|| $parts[2] > 31;

	# Strict checks
	# $parts[2] > ( 30 + (13/3 + $parts[1] * 13/12 ) % 2 )
	# $parts[1] == 2 && $parts[2] > 28 + !($parts[0] % 4) - !($parts[0] % 100) + !($parts[0] % 400)

	return;
}

sub prepare_date_info {
	my @datapicker = ();
	my @formatter  = ();

	my $format = $DATE_FORMATS->{ vars->{site}->{country} || "default" } || $DATE_FORMATS->{default};

	for my $char ( split(//, $format->[0]) ) {
		if ($char eq 'y') {
			push(@datapicker, 'yyyy');
			push(@formatter,  '%Y');
		}
		elsif ($char eq 'm') {
			push(@datapicker, 'mm');
			push(@formatter,  '%m');
		}
		elsif ($char eq 'd') {
			push(@datapicker, 'dd');
			push(@formatter,  '%d');
		}
	}

	my ($mday, $mon, $year) = (localtime(time))[3, 4, 5];

	return {
		datepicker => join($format->[1], @datapicker),
		formatter  => join($format->[1], @formatter),
		week_start => $format->[2],
		current    => sprintf("%d-%02d-%02d", $year + 1900, $mon + 1, $mday)
	};

}

true;
