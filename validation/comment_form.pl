use utf8;
{
	fields => [qw/ name email body /],
	filters => [
		# Trim spaces
		qr/.+/ => filter('trim'),
	],
	checks => [
		[qw/ name email body /] => is_required('Поле обязательно к заполнению'),
		email => sub { check_email($_[0], "Пожалуйста укажите корректный e-mail") }
	]
}