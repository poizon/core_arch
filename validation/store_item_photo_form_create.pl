use utf8;
{
	fields => ['file', 'id'],
	checks => [
		[qw/file id/] => is_required('Поле обязательно к заполнению'),
		file => is_like( qr/^[a-zA-Z0-9\.\_\-\s]+$/, 'Имя файла содержит недопустимые символы' )
	]
}