use utf8;
{
	fields => ['title', 'body', 'date'],
	filters => [
		# Trim spaces
		qr/.+/ => filter('trim'),

		# Convert dates to MySQL format YYYY-MM-DD
		'date' => \&tools::date::iso_date_from,
	],
	checks => [
		['title', 'body', 'date'] => is_required('Поле обязательно к заполнению'),
		'date' => \&tools::date::validate_date,
	]
}