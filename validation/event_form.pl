use utf8;
{
	fields => ['title', 'desc_short', 'desc_full', 'date_start', 'date_end', 'location'],
	filters => [
		# Trim spaces
		qr/.+/ => filter('trim'),

		# Convert dates to MySQL format YYYY-MM-DD
		qr/^date_/ => \&tools::date::iso_date_from,
	],
	checks => [
		['title', 'desc_short'] => is_required('Поле обязательно к заполнению'),
		qr/^date_/ => \&tools::date::validate_date,
	]
}