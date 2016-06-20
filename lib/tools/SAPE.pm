=pod
SAPE.ru - Интеллектуальная система купли-продажи ссылок

Perl-клиент

Вебмастеры! Не нужно ничего менять в этом файле!
Все настройки - через параметры при вызове кода.
Читайте: http://help.sape.ru/

По всем вопросам обращайтесь на support@sape.ru

SAPE          - базовый класс
SAPE::Client  - класс для вывода обычных ссылок
SAPE::Context - класс для вывода контекстных ссылок
=cut

# #############################################################################
# SAPE (base) #################################################################
# #############################################################################

package SAPE;
use strict;

our $VERSION = '1.2.5'; 

BEGIN {
	local $INC{'CGI.pm'} = 1; # нет необходимости в модуле CGI, так что эмулируем его наличие
	require CGI::Cookie;
}
use Encode ();
use Fcntl qw(:flock :seek);
use File::stat;
use JSON::XS;
use LWP::UserAgent;
use MIME::Base64 ();

use constant {
	SERVER_LIST       => [ qw(dispenser-01.saperu.net dispenser-02.saperu.net) ], # серверы выдачи ссылок SAPE
	CACHE_LIFETIME    => 60 * 60, # время жизни кэша для файлов данных
	CACHE_RELOADTIME  => 10 * 60, # таймаут до следующего обновления файла, если прошлая попытка не удалась
};

our %Globals = ();

# user                    => хэш пользователя SAPE
# host                    => (необязательно) имя хоста, для которого выводятся ссылки
# request_uri             => (необязательно) адрес запрашиваемой страницы, по умолчанию: $ENV{REQUEST_URI}
# multi_site              => (необязательно) включить поддержку нескольких сайтов в одной директории
# verbose                 => (необязательно) выводить ошибки в HTML-код
# charset                 => (необязательно) кодировка для выдачи ссылок: windows-1251 (по умолчанию), utf-8, koi8-r, cp866 и т.д.
# socket_timeout          => (необязательно) таймаут при получении данных от сервера SAPE, по умолчанию: 6
# force_show_code         => (необязательно) всегда показывать код SAPE для новых страниц, иначе - только для робота SAPE
# db_dir                  => (необязательно) директория для файлов данных, по умолчанию: $ENV{DOCUMENT_ROOT}/<user>
# ignore_case             => (необязательно) регистронезависимый режим работы, использовать на свой страх и риск!
# show_counter_separately => (необязательно) показывать ли JS-код отдельно от выводимого контента
sub new {
	my $class = shift;
	my %options = @_ == 1 ? (host => shift) : @_;
	
	return SAPE::Client->new(@_) # !!! только для совместимости с SAPE.pm младше версии 1.0 !!!
		if $class eq 'SAPE';
	
	# получить user из пути к модулю, если не указан в качестве параметра
	($options{user}) = map { m!([^/]+)/SAPE\.pm! && $1 } grep { /SAPE\.pm/ } keys %INC
		unless $options{user};
	
	my $self = bless {
		user                    => $options{user},
		host                    => $ENV{HTTP_HOST} || $ENV{HOSTNAME},
		request_uri             => $ENV{REQUEST_URI} || $options{uri}, # !!! только для совместимости с SAPE.pm младше версии 1.0 !!!
		multi_site              => 0,
		verbose                 => 0,
		charset                 => 'utf-8',
		socket_timeout          => 6,
		force_show_code         => 0,
		db_dir                  => "$ENV{DOCUMENT_ROOT}/$options{user}",
		ignore_case             => 0,
		show_counter_separately => 0,
		%options
	}, $class;
	
	!$self->{$_} and die qq|SAPE.pm error: missing parameter "$_" in call to "new"!|
		foreach qw(user host request_uri charset socket_timeout);
	
	# считать URI со слешом в конце и без него альтернативными
	$self->{request_uri_alt} = substr($self->{request_uri}, -1) eq '/'
		? substr($self->{request_uri}, $[, -1)
		: $self->{request_uri} . '/';
	
	# убрать лишнее из имени хоста
	$self->{host} =~ s!^(http://(www\.)?|www\.)!!g;
	
	# проверяем признаки робота SAPE
	my %cookies = CGI::Cookie->fetch;
	if ($self->{is_our_bot} = $cookies{sape_cookie} && $cookies{sape_cookie}->value eq $self->{user}) {
		if ($self->{debug} = $cookies{sape_debug} && $cookies{sape_debug}->value == 1) {
			# для удобства дебага саппортом
			$self->{verbose} = 1;
			$self->{options} = \%options;
			$self->{server_request_uri} = $self->{request_uri}; # = $ENV{REQUEST_URI}
		}
		$self->{force_update_db} = $cookies{sape_updatedb} && $cookies{sape_updatedb}->value == 1;
	}
	
	$self->{request_uri} = lc $self->{request_uri}
		if $self->{ignore_case};

	$self->load_data;
	
	return $self;
}

sub _get_full_user_agent_string {
	shift->USER_AGENT . ' ' . $VERSION;
}

sub _debug_output {
	my $json = JSON::XS->new()->encode(pop);
	'<!-- <sape_debug_info>' . MIME::Base64::encode_base64(Encode::encode("UTF-8", $json), '') . '</sape_debug_info> -->';
}

sub load_data {
	my $self = shift;
	my $db_file = $self->_get_db_file;
	
	my $data;
	
	my $stat = -f $db_file ? stat $db_file : undef;
	if (
		$self->{force_update_db}
		|| (
			!$self->{is_our_bot} 
			&& (
				!$stat
				|| $stat->size == 0
				|| $stat->mtime < time - CACHE_LIFETIME
			)	 
		)
	) {
		# файл не существует или истекло время жизни файла => необходимо загрузить новые данные
		
		open my $fh, '>>', $db_file
			or return $self->raise_error("Нет доступа на запись к файлу данных ($db_file): $!. Выставите права 777 на папку.");
		if (flock $fh, LOCK_EX | LOCK_NB) {
			# экслюзивная блокировка файла удалась => можно производить загрузку
			
			my $ua = LWP::UserAgent->new;
			$ua->agent($self->USER_AGENT . ' ' . $VERSION);
			$ua->timeout($self->{socket_timeout});
			
			my $data_raw;
			my $path = $self->_get_dispenser_path;
			foreach my $server (@{ &SERVER_LIST }) {
			    my $data_url = "http://$server/$path";
			    my $response = $ua->get($data_url);
			    if ($response->is_success) {
			        $data_raw = $response->content;
			        return $self->raise_error($data_raw)
			            if substr($data_raw, $[, 12) eq 'FATAL ERROR:';
			        $data = $self->parse_data(\$data_raw)
			        	or return $self->raise_error("Ошибка чтения JSON: $@");
			        last;
			    }
			}
			
			if ($data && $self->check_data($data)) {
			    # данные получены успешно
			    seek $fh, 0, SEEK_SET;
			    truncate $fh, 0;
			    print $fh $data_raw;
			    close $fh;
			} else {
			    # данные не получены вообще или получены неверные => пометить файл для повторого обновления
			    close $fh;
			    utime $stat->atime, time - CACHE_LIFETIME + CACHE_RELOADTIME, $db_file
			        if $stat;
			}
		}
	}
	
	unless ($data) {
		# данные не загружены => загрузить из файла данных
		local $/;
		open my $fh, '<', $db_file
			or return $self->raise_error("Не удаётся произвести чтение файла данных ($db_file): $!");
		my $data_raw = <$fh>;
		close $fh;
		return unless $data_raw;
		$data = $self->parse_data(\$data_raw)
			or return $self->raise_error("Ошибка парсинга JSON: $!");
	}
	
	$self->set_data($data);
}

sub parse_data {
	my ($self, $data) = @_;
	eval { JSON::XS->new->utf8->decode($$data); }
}

sub check_data {
	my ($self, $data) = @_;
	$data->{__for_user__} eq $self->{user};
}

sub set_data {
	my ($self, $data) = @_;
	
	if ($self->{ignore_case}) {
		$data->{ (lc $_) } = delete $data->{$_}
			foreach keys %$data;
	}
	
	if (ref $data->{__sape_links__} eq 'HASH') {
		if ($data->{__sape_links__}->{ $self->{request_uri} }) {
			$data->{__sape_links_page__} = $data->{__sape_links__}->{ $self->{request_uri} };
			push @{ $data->{__sape_links_page__} }, @{ $data->{__sape_links__}->{ $self->{request_uri_alt} } }
				if $data->{__sape_links__}->{ $self->{request_uri_alt} };
		} else {
			$data->{__sape_links_page__} = $data->{__sape_links__}->{ $self->{request_uri_alt} };
		}
	}
	
	$data->{__sape_links_page__} ||= $data->{__sape_new_url__}
		if $self->{is_our_bot} || $self->{force_show_code};
	
	$self->{data} = $data;
}

sub raise_error {
	my ($self, $error) = @_;
	
	$error = "SAPE ERROR: $error $self->{host}$self->{request_uri}";
	#$error = Encode::decode($self->{charset}, $error);

	if ($self->{verbose}) {
		$self->{_error} = qq|<p style="color: red; font-weight: bold;">$error</p>|;
		eval {
			Encode::from_to($self->{_error}, 'windows-1251', $self->{charset})
			    unless $self->{charset} eq 'windows-1251';
		};
	} else {
		#binmode STDERR, ":encoding(UTF-8)";
		warn $error;
		$self->{_error} = ' ';
	}
	
	return;
}

sub _return_obligatory_page_content {
	!$SAPE::page_obligatory_output_shown++
		? shift->{data}->{__sape_page_obligatory_output__} || ''
		: '';
}

# вернуть JS-код (работает только при show_counter_separately = 1)
sub return_counter {
	my $self = shift;
	$self->{show_counter_separately} = 1;
	$self->_return_obligatory_page_content;
}

# #############################################################################
# SAPE::Client ################################################################
# #############################################################################

package SAPE::Client;
use strict;
use base qw(SAPE);

use constant {
	USER_AGENT => 'SAPE_Client Perl',
};

# Обработка html для массива ссылок.
sub _return_array_links_html {
	my ($self, $html, %options) = @_;
	
	$html = Encode::encode($self->{charset}, $html)
		if $self->{charset} ne 'utf-8';
	
	if ($self->{is_our_bot}) {
		$html = "<sape_noindex>$html</sape_noindex>";
		if ($options{is_block_links}) {
			$options{$_} ||= 0
				foreach qw(nof_links_requested nof_links_displayed nof_obligatory nof_conditional);
			$html = '<sape_block nof_req="' . $options{nof_links_requested}
						. '" nof_displ="' . $options{nof_links_displayed}
						. '" nof_oblig="' . $options{nof_obligatory} 
						. '" nof_cond="' . $options{nof_conditional} . '">'
						. $html
						. '</sape_block>';
		}
	}
	
	return $html;
}

# Финальная обработка html перед выводом ссылок.
sub _return_html {
	my ($self, $html) = @_;
	
	unless ($self->{show_counter_separately}) {
		$html = $self->_return_obligatory_page_content . $html;
	}
	
	if ($self->{debug}) {
		$html .= $self->_debug_output({ user_agent => $self->_get_full_user_agent_string });
		$html .= $self->_debug_output({ %$self });
	}
	
	return $html;
}

# Вывод ссылок в обычном виде - текст с разделителем.
# => (необязательно) число ссылок для вывода в этом блоке
# as_block => (необязательно) выводить ли в виде блока
sub return_links {
	my $self = shift;
	my $n = shift;
	my $offset = @_ % 2 == 0 ? 0 : shift; # !!! offset - только для обратной совместимости !!!
	my %options = @_;
	
	return $self->{_error}
		if $self->{_error};
	
	return $self->return_block_links($n, $offset, %options)
		if ($options{as_block} ||= $self->{data}->{__sape_show_only_block__})
			&& $self->{data}->{__sape_block_tpl__};
	
	my $links_page = $self->{data}->{__sape_links_page__};
	if (ref $links_page eq 'ARRAY') {
		# загружен список ссылок => вывести нужное число
		$n ||= scalar @$links_page;
		splice @$links_page, $[, $offset
			if $offset;
		return $self->_return_html($self->_return_array_links_html(join($self->{data}->{__sape_delimiter__}, splice @$links_page, $[, $n)));
	} else {
		# загружен простой текст => вывести его как есть
		return $self->_return_html($links_page . $self->_return_array_links_html(''));
	}
}

# Вывод ссылок в виде блока.
# => (необязательно) число ссылок для вывода в этом блоке
# block_no_css => (необязательно) переопределяет запрет на вывод CSS в коде страницы: 0 - выводить CSS
# block_orientation => (необязательно) переопределяет ориентацию блока: 1 - горизонтальная, 0 - вертикальная
# block_width => (необязательно) переопределяет ширину блока: 'auto', '[?]px', '[?]%', '[?]' - любое значение по спецификации CSS
sub return_block_links {
	my $self = shift;
	my $n = shift;
	my $offset = @_ % 2 == 0 ? 0 : shift; # !!! offset - только для обратной совместимости !!!
	my %options = @_;
	
	return $self->{_error}
		if $self->{_error};
	
	%options = (
		block_no_css      => 0,
		block_orientation => 1,
		block_width       => '',
		($self->{data}->{__sape_block_tpl_options__} ? %{ $self->{data}->{__sape_block_tpl_options__} } : ()),
		%options
	);
	
	my $links_page = $self->{data}->{__sape_links_page__};
	if (ref $links_page ne 'ARRAY') {
		# загружен простой текст => вывести его как есть + инфо о блоке
		return $self->_return_html($links_page . $self->_return_array_links_html('', is_block_links => 1));
	} elsif (!$self->{data}->{__sape_block_tpl__}) {
		return $self->_return_html('');
	}
	
	my $n_requested = $n && $n > @$links_page ? $n : 0;
	
	# выборка ссылок
	$n = scalar @$links_page
		unless $n && $n <= @$links_page;
	splice @$links_page, $[, $offset
		if $offset;
	
	# подсчет числа опциональных блоков
	my $nof_conditional = $self->{data}->{__sape_block_ins_itemconditional__} && $n_requested > @$links_page
		? $n_requested - scalar @$links_page
		: 0;
	
    # если нет ссылок и вставных блоков, то ничего не выводим
	return $self->_return_html($self->_return_array_links_html(
		'',
		is_block_links      => 1,
		nof_links_requested => $n_requested,
		nof_links_displayed => 0,
		nof_obligatory      => 0,
		nof_conditional     => 0)
	) unless @$links_page || $self->{data}->{__sape_block_ins_itemconditional__} || $nof_conditional;
	
	my $html;
	
	# делаем вывод стилей (только один раз) - или не выводим их вообще, если так задано в параметрах
	$html .= $self->{data}->{__sape_block_tpl__}->{css}
		unless $options{block_no_css} || $SAPE::Globals{block_css_shown}++;
	
	# вставной блок в начале всех блоков
	$html .= $self->{data}->{__sape_block_ins_beforeall__}
		if $self->{data}->{__sape_block_ins_beforeall__} && !$SAPE::Globals{block_ins_beforeall_shown}++;
    
	# вставной блок в начале блока
	$html .= $self->{data}->{__sape_block_ins_beforeblock__}
		if $self->{data}->{__sape_block_ins_beforeblock__};
	
	# получаем шаблоны в зависимости от ориентации блока
	my $block_tpl_parts = $self->{data}->{__sape_block_tpl__}->{ $options{block_orientation} };
	(my $item_tpl_full = $block_tpl_parts->{item_container}) =~ s/\{item\}/$block_tpl_parts->{item}/g;
	
	my $items = '';
	my $nof_items_total = @$links_page;
	
	foreach my $link_html (splice @$links_page, $[, $n) {
		$link_html =~ s/^\s+|\s+$//g;
		my ($url, $domain, $header) = $link_html =~ m!<a href="(https?://([^"/]+)[^"]*)"[^>]*>[\s]*([^<]+)</a>!i;
		$header = ucfirst $header;
		$domain = $self->{data}->{__sape_block_uri_idna__}->{$domain}
			if ref $self->{data}->{__sape_block_uri_idna__} eq 'HASH' && $self->{data}->{__sape_block_uri_idna__}->{$domain};
		
		my $item = $item_tpl_full;
		$item =~ s/{header}/$header/g;
		$item =~ s/{text}/$link_html/g;
		$item =~ s/{url}/$domain/g;
		$item =~ s/{link}/$url/g;
		$items .= $item;
	}
	
	# вставной обязательный элемент в блоке
	if ($self->{data}->{__sape_block_ins_itemobligatory__}) {
		($items .= $block_tpl_parts->{item_container}) =~ s/{item}/$self->{data}->{__sape_block_ins_itemobligatory__}/g;
		++$nof_items_total;
	}
	
	# вставные опциональные элементы в блоке
	if ($nof_conditional) {
		for (my $i = 0; $i < $nof_conditional; ++$i, ++$nof_items_total) {
			($items .= $block_tpl_parts->{item_container}) =~ s/{item}/$self->{data}->{__sape_block_ins_itemconditional__}/g;
		}
	}
	
	if ($items ne '') {
		($html .= $block_tpl_parts->{block}) =~ s/{items}/$items/g;
		
		$html =~ s#{td_width}# $nof_items_total ? int(100 / $nof_items_total) : 0 #eg;
		$html =~ s#{block_style_custom}#style="width: $options{block_width}!important;"#g
			if $options{block_width};
	}
	
	# вставной блок в конце блока
	$html .= $self->{data}->{__sape_block_ins_afterblock__}
		if $self->{data}->{__sape_block_ins_afterblock__};
	
	# заполняем оставшиеся модификаторы значениями
	delete @options{ qw(block_no_css block_orientation block_width) };
	$html =~ s/\{$_\}/$options{$_}/g
		foreach keys %options;
	
	# очищаем незаполненные модификаторы
	$html =~ s/\{[a-z\d_\-]+\}/ /g;
	
	return $self->_return_html($self->_return_array_links_html($html,
		is_block_links      => 1,
		nof_links_requested => $n_requested,
		nof_links_displayed => $n,
		nof_obligatory      => $self->{data}->{__sape_block_ins_itemobligatory__} + 1,
		nof_conditional     => $nof_conditional,
	));
}

# !!! только для совместимости с SAPE.pm младше версии 1.0 !!!
sub get_links {
	my ($self, %options) = @_;
	return $self->return_links($options{count});
}

sub _get_db_file {
	my $self = shift;
	return "$self->{db_dir}/" . ($self->{multi_site} ? "$self->{host}." : '') . 'links.json';
}

sub _get_dispenser_path {
	my $self = shift;
	return "code.php?user=$self->{user}&host=$self->{host}&format=json&charset=$self->{charset}&no_slash_fix=true&" . time;
}

# #############################################################################
# SAPE::Context ###############################################################
# #############################################################################

package SAPE::Context;
use strict;
use base qw(SAPE);

use Symbol 'gensym';

use constant {
	USER_AGENT  => 'SAPE_Context Perl',
	FILTER_TAGS => { a => 1, textarea => 1, select => 1, script => 1, style => 1, label => 1, noscript => 1, noindex => 1, button => 1 },
};

# Записать информацию для отладки.
# => (необязательно) пояснение к данным (ключ)
# => данные
sub _debug_action_append {
	my $self = shift;
	return
		unless $self->{debug};
	my $key = @_ % 2 == 0 ? shift : undef;
	my $data = shift;
	
	$self->{debug_actions} ||= [ $self->_get_full_user_agent_string ];
	$data = $$data
		if ref $data eq 'SCALAR';
	push @{ $self->{debug_actions} }, defined($key) ? { $key => $data } : $data;
}

# Вывод отладочной информации.
sub _debug_action_output {
	my $self = shift;
	$self->{debug} && $self->{debug_actions} && @{ $self->{debug_actions} }
		? $self->_debug_output(delete $self->{debug_actions})
		: '';
}

# Вывод контекстных ссылок во фрагменте HTML-документа, переданном в качестве параметра.
# => текст для поиска и замены ссылок в нём (может быть простым скаляром *или* ссылкой на скаляр - для экономии памяти)
sub replace_in_text_segment {
	my $self = shift;
	my $is_text_ref = ref $_[0] eq 'SCALAR';
	my $text_ref = $is_text_ref
		? $_[0]
		: \$_[0];
	
	if ($self->{_error}) {
		$$text_ref .= $self->{_error};
		$is_text_ref
			? return
			: return $$text_ref;
	}
	
	$$text_ref = Encode::decode($self->{charset}, $$text_ref)
		if $self->{charset} ne 'utf-8';
	
	$self->_debug_action_append('START: replace_in_text_segment');
	$self->_debug_action_append('argument for replace_in_text_segment' => $$text_ref);
	
	my $links_page = $self->{data}->{__sape_links_page__};
	
	if (ref $links_page eq 'ARRAY') {
		if (@$links_page) {
			# загружен непустой список ссылок на странице => произвести поиск и замену
			
			my $text_new; # контейнер для обработанного текста
			my @tags_filtered; # стек открытых фильтруемых тегов
			
			foreach my $text_part (split '<', $$text_ref) {
				if (defined $text_new) {
				    # часть до первого тэга уже обработали => текущая часть начинается с названия тэга
				    my ($is_closing, $tag_name) = $text_part =~ m!(/)?([A-Za-z0-9]+)!;
				    $tag_name = lc $tag_name;
					$self->_debug_action_append(($is_closing ? 'close' : 'open') . ' tag' => $tag_name);
					
				    if ($is_closing && @tags_filtered && $tags_filtered[$#tags_filtered] eq $tag_name) {
				        # закрывается фильтруемый тэг => убрать из стека
				        pop @tags_filtered;
						$self->_debug_action_append('deleted from tags_filtered' => $tag_name);
						$self->_debug_action_append('start replacement')
							unless @tags_filtered;
	
				    } elsif (!$is_closing && !@tags_filtered && FILTER_TAGS->{$tag_name}) {
				        # открывается фильтруемый тэг => добавить в стек
				        push @tags_filtered, $tag_name;
						$self->_debug_action_append('added to tags_filtered, stop replacement' => $tag_name);
				    }
				}
				
				unless (@tags_filtered) {
				    # список фильтруемых тэгов пуст => производим обработку части
				    my ($tag, $content) = $text_part =~ /^(?:(.+)>)?(.*)$/s;
				    my $regexps_page = $self->{data}->{__sape_words_regexps__};
				    for (my $i = 0; $i < @$regexps_page; ++$i) {
				        if ($content =~ s/$regexps_page->[$i]/$links_page->[$i]/) {
				            # нашлось совпадение, сделана замена => убрать ссылку из дальнейшей обработки
							$self->_debug_action_append('replaced' => $regexps_page->[$i] . ' --- ' . $links_page->[$i]);
				            splice @$links_page, $i, 1;
				            splice @$regexps_page, $i, 1;
				            --$i;
				        }
				    }
				    $text_part = ($tag ? "$tag>" : '') . $content;
				}
				
				$text_new .= (defined $text_new ? '<' : '') . $text_part;
			}
			
			$$text_ref = $text_new;
		
		} else {
			$self->_debug_action_append('No words for page');
		}
	}
	
	if ($self->{is_our_bot} || $self->{force_show_code} || $self->{debug}) {
		# пометить участок текста для индексирования роботом SAPE
		$$text_ref = "<sape_index>$$text_ref</sape_index>";
		$$text_ref .= $self->{data}->{__sape_new_url__}
			if $self->{data}->{__sape_new_url__};
	}
	
	$self->_debug_action_append('Not replaced' => [ @$links_page ])
		if ref $links_page eq 'ARRAY' && @$links_page;
	
	$self->_debug_action_append('END: replace_in_text_segment');
	$$text_ref .= $self->_debug_action_output
		unless (caller(1))[3] eq __PACKAGE__ . '::replace_in_page';
	
	$$text_ref = Encode::encode($self->{charset}, $$text_ref)
		if $self->{charset} ne 'utf-8';
	
	$is_text_ref
		? return
		: return $$text_ref;
}

# Вывод контекстных ссылок в целом HTML-документе, переданном в качестве параметра или полученном через перехват вызовов print.
# => (необязательно) текст для поиска и замены ссылок в нём (может быть простым скаляром *или* ссылкой на скаляр - для экономии памяти)
# 1. Параметр "текст" передан? Заменяет внутри блоков <sape_index> ... </sape_index> при их наличии либо внутри <body> ... </body>.
# 2. Параметров нет? Переопределяет стандартную функцию print, накапливает документ в буфере и выполняет пункт 1.
sub replace_in_page {
	my $self = shift;
	
	unless (@_) {
		$self->_debug_action_append('START: replace_in_page (override print)');
		
		# вызов без параметров
		die q|SAPE.pm error: mod_perl is not yet supported for replace_in_page, please, contact author of this module in case you really need it.|
			if $ENV{MOD_PERL};
		
		# готовим буфер для выводимого текста
		$self->{text} = '';
		
		# сохраняем стандартный обработчик вывода (дескриптор STDOUT)
		$self->{fh} = select;
		$self->{fh_stdout} = *STDOUT;
		
		# устанавливаем собственный обработчик вывода
		my $fh_new = gensym;
		tie *$fh_new, ref $self, $self;
		select $fh_new;
		*STDOUT = *$fh_new;
		
		return;
	}
	
	# дочитать параметры
	my $is_text_ref = ref $_[0] eq 'SCALAR';
	my $text_ref = $is_text_ref
		? $_[0]
		: \$_[0];
	
	$self->_debug_action_append('START: replace_in_page with parameter: ' . ($is_text_ref ? 'ref to SCALAR' : 'plain text (not recommended)'))
		unless (caller(1))[3] eq __PACKAGE__ . '::_tie_close';
	
	# вывод обязательного блока
	if (!$self->{show_counter_separately} and my $obligatory_page_content = $self->_return_obligatory_page_content) {
		$$text_ref =~ s!(</body>)!$obligatory_page_content$1!i;
	}
	
	# поиск и замена ссылок в тексте из буфера перед выводом
	if ($self->{data}->{__sape_links_page__}) {
		# заменить текст внутри блоков <sape_index> ... </sape_index>
		my $cnt_parts = $$text_ref =~ s!
			<sape_index>(.*?)</sape_index>
		!
			my $text = $1;
			$self->replace_in_text_segment($text);
		!egisx;
		
		if ($cnt_parts) {
			$self->_debug_action_append('Split by <sape_index> cnt_parts=' => $cnt_parts);
			
		} else {
			# или внутри <body> ... </body>, если не найдены <sape_index> ... </sape_index>
			$cnt_parts = $$text_ref =~ s!
				(<body[^>]*>)(.*?)(</body>)
			!
				my $text = $2;
				$1 . $self->replace_in_text_segment($text) . $3;
			!eisx;
			
			$self->_debug_action_append($cnt_parts ? 'Split by BODY' : 'Cannot split by BODY');
		}
	
	} elsif ($self->{is_our_bot} || $self->{force_show_code} || $self->{debug}) {
		# пометить участок текста для индексирования роботом SAPE
		$$text_ref .= $self->{data}->{__sape_new_url__}
			if $self->{data}->{__sape_new_url__};
	
	} else {
		# спрятать блоки <sape_index> ... </sape_index> от стороннего наблюдателя
		$$text_ref =~ s!<sape_index>(.*?)</sape_index>!!gi;
		
		$self->_debug_action_append('No words for page');
	}
	
	$self->_debug_action_append('STOP: replace_in_page');
	$$text_ref .= $self->_debug_action_output;
	
	$is_text_ref
		? return
		: return $$text_ref;
}

# !!! только для совместимости с SAPE.pm младше версии 1.2 !!!
sub replace_in_page_text {
	shift->replace_in_page(@_);
}

sub TIEHANDLE {
	return $_[$#$_];
} 

sub WRITE {
	my $self = shift;
	my $data = substr($_[0], $_[2] || 0, $_[1]);
	my $length = length $data;
	$self->PRINT($data);
	return $length;
}

sub PRINT {
	my $self = shift;
	$self->{text} .= join $,, @_;
}

sub PRINTF {
	my $self = shift;
	my $format = shift;
	$self->PRINT(sprintf($format, @_));
}

sub READ {}

sub READLINE {}

sub GETC {}

sub _tie_close {
	my $self = shift;
	
	# непосредственая замена ссылок в буфере
	$self->replace_in_page(\$self->{text});
	
	$self->_debug_action_append('STOP: replace_in_page (override print)');
	
	# вывод текста из буфера через ранее сохранённый стандартный обработчик вывода
	no strict 'refs'; # избегаем предупреждений про main::STDOUT
	*STDOUT = $self->{fh_stdout};
	my $fh = *{ $self->{fh} };
	CORE::print $fh (delete $self->{text});
};

sub CLOSE { &_tie_close }

sub UNTIE { &_tie_close }

sub DESTROY { &_tie_close }

sub _get_db_file {
	my $self = shift;
	return "$self->{db_dir}/" . ($self->{multi_site} ? "$self->{host}." : '') . 'words.json';
}

sub _get_dispenser_path {
	my $self = shift;
	return "code_context.php?user=$self->{user}&host=$self->{host}&format=json&charset=$self->{charset}&no_slash_fix=true";
}

sub set_data {
	my ($self, $data) = @_;
	
	$data = $self->SUPER::set_data($data);
	
	if (ref $data->{__sape_links_page__} eq 'ARRAY' && @{ $data->{__sape_links_page__} }) {
        # преобразовываем текст со ссылками в регулярные выражения
        $data->{__sape_words_regexps__} = [];
        foreach (@{ $data->{__sape_links_page__} }) {
            # убираем тэги
            (my $sentence = $_) =~ s/<[^>]+?>//g;
            # экранируем спецсимволы регулярных выражений
            $sentence =~ s/([.\\+*?\[^\]\$(){}=!<>|:])/\\$1/g;
            # добавляем варианты написания некоторых символов (напрямую или через HTML-сущности)
            $sentence =~ s/&(?:amp;)?/(&(?:amp;)?)/g; # амперсанд
            $sentence =~ s/"/("|&quot;)/g; # кавычка
            $sentence =~ s/'/('|&#039;)/g; # апостроф
			$sentence =~ s/</(<|&lt;)/g; # меньше
			$sentence =~ s/>/(>|&gt;)/g; # больше
            $sentence =~ s/\s/(\\s|&nbsp;)+/g; # пробел
            # добавляем в список регулярных выражений для использования при поиске в тексте
            push @{ $data->{__sape_words_regexps__} }, $sentence;
        }
	}
}

# #############################################################################

1;
