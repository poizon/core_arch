use utf8;
{
	fields => ['phone', 'email', 'promocode'],
	filters => [
		# Trim spaces
		qr/.+/ => filter('trim'),
	],
	checks => [
		['phone', 'email'] => is_required('Поле обязательно к заполнению'),
		email => sub { check_email($_[0], "Пожалуйста укажите корректный e-mail") }
	]
}
