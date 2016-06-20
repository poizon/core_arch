use utf8;
{
	fields => ['name', 'descr', 'reply_email', 'finish_message', 'site_id', 'options', 'nocaptcha'],
	checks => [
		['name', 'reply_email', 'site_id'] => is_required('Поле обязательно к заполнению'),
		site_id     => is_like( qr/^\d+$/, 'Ошибка' ),
		nocaptcha   => is_like( qr/^1|0$/, 'Ошибка' ),
		reply_email => sub { check_email($_[0], "Пожалуйста укажите корректный e-mail") }
	],
}
