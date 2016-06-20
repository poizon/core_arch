use utf8;
{
	fields => ['folder_name', 'new_folder_name'],
	checks => [
		['folder_name', 'new_folder_name'] => is_required('Поле обязательно к заполнению'),
		new_folder_name => is_like( qr/^[a-zA-Z0-9\-\_\s]+$/, 'Имя содержит недопустимые символы')
	],
}