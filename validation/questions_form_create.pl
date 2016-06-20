use utf8;
{
	fields => [ 'type','question','descr','priority','is_required' ],
	checks => [
			['type', 'question', 'priority', 'is_required'] => is_required('Поле обязательно к заполнению'),
			type	       => is_like( qr/^text|textarea|select|checkbox|radio|file$/, 'Ошибка' ),
			priority    => is_like( qr/^\d+$/, 'Ошибка' ),
			is_required => is_like( qr/^0|1$/, 'Ошибка' ),
	],
}
