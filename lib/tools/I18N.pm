#
# This file is part of Dancer-Plugin-Locale-Wolowitz
#
# This software is copyright (c) 2014 by Natal Ngétal.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package tools::I18N;

use strict;
use warnings;
use tools::json;

use 5.010;

use Dancer ':syntax';
use Dancer::Plugin;
use Dancer::Exception qw(:all);

use Locale::Wolowitz;

#ABSTRACT: Intenationalization for Dancer

my $w;
my $languages  = load_json('json/languages.json');

#Register exception
register_exception('DirectoryNotFound',
    message_pattern => "Not found directory: %s"
);

register loc => sub {
    _loc(@_);
};

sub _loc {
    my ( $str, $args ) = @_;

    $w = Locale::Wolowitz->new(_path_directory_locale()) unless defined($w);
    my $lang = _lang();

    !$args and return $w->loc($str, $lang);

    my $msg = $w->loc($str, $lang, map($w->loc($_, $lang), @{$args}));

    return $msg;
}

sub _path_directory_locale {
    my $settings = plugin_setting;
    my $path     = $settings->{locale_path_directory} //
        Dancer::FileUtils::path(setting('appdir'), 'languages');

    raise DirectoryNotFound => $path unless -d $path;
    return $path;
}

sub _lang {
    my $settings     = plugin_setting;
    my $lang_session = $settings->{lang_session} || 'lang';
    my $lang = $settings->{default_lang};

    # don't force the user to store lang in a session
    if ( setting('session') ) {
        my $session_language = session $lang_session;

        if ( !$session_language ) {
            # CHANGE DONE IN THIS LINE
            $lang = _detect_lang_from_browser() || config->{default_lang};
            $lang = config->{default_lang} unless $languages->{$lang}; 

            session $lang_session => $lang;
            return $lang;
        }
        else {
            return $session_language;
        }
    }

    $lang = _detect_lang_from_browser();

    return $lang;
}

sub _detect_lang_from_browser {
    my $lang = request->accept_language or return;

    $lang =~ s/-\w+//g;
    $lang = (split(/,\s*/,$lang))[0] if $lang =~ /,/;

    return $lang;
}

register_plugin;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dancer::Plugin::Locale::Wolowitz - Intenationalization for Dancer

=head1 VERSION

version 0.140120

=head1 SYNOPSIS

    use Dancer ':syntax';
    use Dancer::Plugin::Locale::Wolowitz;

    get '/' => sub {
        template index;
    }

=head1 DESCRIPTION

Provides an easy way to translate your application. This module relies on L<Locale::Wolowitz>, please consult the documentation of Locale::Wolowitz.

=head1 METHODS

=head2 loc

    loc('Welcome');
    loc('View %1', ['Country'])
or
    <% l('Welcome') %>
    <% l('View %1', ['Country']) %>

Translated to the requested language, if such a translation exists, otherwise
no traslation occurs.

    input: (Str): Key translate
           (Arrayref): Arguments are injected to the placeholders in the string
    output: (Str): Translated to the requested language

=head1 CONFIGURATION

  plugins:
    Locale::Wolowitz:
      lang_session: "lang"
      locale_path_directory: "i18n"

=head1 CONTRIBUTING

This module is developed on Github at:

L<http://github.com/hobbestigrou/Dancer-Plugin-Locale-Wolowitz>

=head1 ACKNOWLEDGEMENTS

Thanks to Ido Perlmuter to Locale::Wolowitz

=head1 BUGS

Please report any bugs or feature requests in github.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dancer::Plugin::Locale::Wolowitz

=head1 SEE ALSO

L<Dancer>
L<Locale::Wolowitz>

=head1 AUTHOR

Natal Ngétal

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Natal Ngétal.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
