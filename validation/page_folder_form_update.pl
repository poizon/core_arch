use utf8;
{
	fields => ['title', 'id'],
	checks => [
		[qw/title id/] => is_required('Поле обязательно к заполнению'),
		id => is_like( qr/^\d+$/, 'Ошибка' )
	]
}