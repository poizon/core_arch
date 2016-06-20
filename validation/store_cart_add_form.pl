use utf8;
{
	fields => [qw/id param/],
	checks => [
		[qw/id/] => is_required('Поле обязательно к заполнению'),
		id => is_like( qr/^\d+$/, 'Ошибка' )
	]
}
