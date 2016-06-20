use utf8;
{
	fields  => [qw/title code limit date_start date_end type discount used id/],
	filters => [
			# Convert dates to MySQL format YYYY-MM-DD
			'date_start' => \&tools::date::iso_date_from,
			'date_end'   => \&tools::date::iso_date_from,
	],
	checks => [
		[ qw/title code type discount id/ ] => is_required('Поле обязательно к заполнению'),
		limit      => is_like( qr/^\d+$/, 'Поле должно содержать только цифры' ),
		used       => is_like( qr/^\d+$/, 'Поле должно содержать только цифры' ),
		id         => is_like( qr/^\d+$/, 'Поле должно содержать только цифры' ),
		type       => is_like( qr/^1|2$/, 'Ошибка' ),
		date_start => is_like( qr/^(\d{4}-\d{2}-\d{2})?$/, 'Дата указана некорректно' ),
		date_end   => is_like( qr/^(\d{4}-\d{2}-\d{2})?$/, 'Дата указана некорректно' ),
		discount   => is_like( qr/^[\.\d]+$/, 'Поле должно содержать только цифры' ),
	],
}
