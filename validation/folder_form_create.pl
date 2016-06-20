use utf8;
{
	fields => ['folder_name', 'folder'],
	checks => [
		['folder_name'] => is_required('Поле обязательно к заполнению'),
		folder_name => is_like( qr/^[a-zA-Z0-9\_\-\s]+$/, 'Имя содержит недопустимые символы' )
	]
}