use utf8;
{
	fields => ['cart_item_id', 'quantity'],
	checks => [
		['cart_item_id', 'quantity'] => is_required('Поле обязательно к заполнению'),
		quantity => is_like( qr/^\d+$/, 'Поле должно содержать только цифры' )
	]
}