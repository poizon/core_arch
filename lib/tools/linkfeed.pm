package linkfeed;

use strict;
use utf8;
use Encode;
use File::Copy;
use File::stat;
use IO::File;
use LWP::UserAgent;
use Fcntl qw(:flock);
use Digest::SHA qw(sha1_hex);

use vars qw (@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw();

sub new {
    my ( $class, %params) = @_;
    my $self = {};
    bless $self, $class;

    $self->{version}         = '0.3';
    $self->{charset}         = $params{charset} || 'DEFAULT';
    $self->{server}          = 'db.linkfeed.ru';
    $self->{cache_time}      = 3600;
    $self->{reload_time}     = 300;
    $self->{host}            = $params{host} || $ENV{HOSTNAME} || $ENV{HTTP_HOST};
    $self->{request_uri}     = $params{request_uri} || $ENV{REQUEST_URI};
    $self->{request_timeout} = $params{request_timeout} || 6;
    $self->{multi_site}      = $params{multi_site} || 0;
    $self->{user}            = $params{user};
    $self->{debug}           = $params{debug} || 0;
    $self->{ip}              = $params{ip} || $ENV{REMOTE_ADDR};


    $self->{user_agent}      = 'LinkFeed Client Perl '.$self->{version};
    $self->{db_dir}          = $params{db_dir} || "$ENV{DOCUMENT_ROOT}/".$self->{user};

    $self->{host} =~ s/^www\.//i;
    $self->{host} = lc($self->{host});

    $self->{link_url}        = "http://$self->{server}".'/'.$self->{user}.'/'.$self->{host}.'/'.uc($self->{charset}).'.text';

	$self->{db_file} = $self->{db_dir} . "/";
    if ($self->{multi_site}) {
         $self->{db_file} .= "linkfeed.".$self->{host}.".links.db";
    } else {
         $self->{db_file} .= "linkfeed.links.db";
    }
    $self->{db_file_new}   = $self->{db_file}.".new";

    $self->load_links();

    $self->{db_data}{__linkfeed_start__} ||= "";
    $self->{db_data}{__linkfeed_end__}   ||= "";

    $self->{db_data}{__linkfeed_before_text__} ||= "";
    $self->{db_data}{__linkfeed_after_text__}  ||= "";
    $self->{db_data}{__linkfeed_delimiter__}   ||= " ";

    $self->{robot} = 0;

    my $ip;
    if ($self->{db_data}{__linkfeed_robots__}) {
       foreach $ip (@{$self->{db_data}{__linkfeed_robots__}}) {
         if ($self->{ip} eq $ip) {
           $self->{robot} = 1;
           last;
         }
       }
    }

    $self->{links_count} = 0;
    $self->{links_count} = scalar(@{$self->{db_data}{$self->{request_uri}}}) if $self->{db_data}{$self->{request_uri}};

    $self->{show_code} = $self->{debug} || $self->{robot};

    return $self;
}


sub return_links {

  my $self   = shift;
  my $count  = shift;

  $count = 0 if !$count;

  my $result = '';

  my @page_links;
  @page_links  = @{$self->{db_data}{$self->{request_uri}}} if $self->{db_data}{$self->{request_uri}};

  if ($self->{show_code}) {

     $result .= $self->{db_data}{__linkfeed_start__};

     my ($sec,$min,$hour,$mday,$mon,$year,$wday)= localtime($self->{file_change_date});
     my $mtime = sprintf "%4d-%02d-%02d %02d:%02d:%02d\n", $year+1900,$mon+1,$mday,$hour,$min,$sec;

     $result .= $self->{error} if $self->{error};
     $result .= '<!--REQUEST_URI=' . $self->{request_uri} . "-->\n";
     $result .= "\n<!--\n";
     $result .= 'link_url ' . $self->{link_url}. "\n";
     $result .= 'PL ' . $self->{version}. "\n";
     $result .= 'charset=' . $self->{charset}. "\n";
     $result .= 'multi_site=' . $self->{multi_site} . "\n";
     $result .= "file change date=$mtime\n";
     $result .= 'file size=' . $self->{file_size} . "\n";
     $result .= 'links_count=' . $self->{links_count} . "\n";
     $result .= 'left_links_count=' . scalar(@page_links) . "\n";
     $result .= 'n=' . $count . "\n";
     $result .= '-->';
  }

  if (@page_links) {
     my $i = 0;
     my $link;
     my @block_links;
     $result .= $self->{db_data}{__linkfeed_before_text__};
     while ( (!$count || $i < $count) && scalar(@page_links)) {
        push(@block_links, shift @page_links);
        $i++;
     }
     $result .= join($self->{db_data}{__linkfeed_delimiter__}, @block_links);
     $result .= $self->{db_data}{__linkfeed_after_text__};

     $self->{db_data}{$self->{request_uri}} = \@page_links;
  }

  $result .= $self->{db_data}{__linkfeed_end__} if $self->{show_code};

  #$result .= $self->uptolike_tag();

  return decode("utf8", $result);

}

sub parse_db_file {
   my $self    = shift;
   my $content = shift;

   my @lines = split(/\n/,$content);
   my $line;
   my $key;
   my $value;

   return if !@lines;

   foreach $line (@lines) {
      if ($line =~ /^(.+?):(.*)$/) {
         ($key, $value) = ($1, $2);
         if ($value =~ / <break> / || $key !~ /^__linkfeed/) {
              my @values = split(' <break> ', $value);
             $self->{db_data}{$key} = \@values;
         } else {
             $self->{db_data}{$key} = $value;
         }
      } else {
         return $self->raise_error("Wrong line in db_file: $line\n");
      }
   }
   return 1;
}


sub load_links {

   my $self = shift;
   my $new_file = 0;
   my $error = "";
   my $content;

   if (! -f $self->{db_file}) {
       if (sysopen(FILE, $self->{db_file}, O_RDWR|O_CREAT|O_EXCL)) {
           $new_file = 1;
       } else {
          $error = $!;
       }
   }

   if (!$new_file) {
      sysopen(FILE, $self->{db_file}, O_RDWR) || return $self->raise_error("Can't create or read file '".$self->{db_file}."': $error, $!\
n");
   }

   my $stat = stat($self->{db_file}) || return $self->raise_error("Can't stat file ".$self->{db_file}."': $!\n");
   $self->{file_size} = $stat->size();
   $self->{file_change_date} = $stat->mtime();

   if ($new_file || $stat->mtime() < time() - $self->{cache_time} || ($stat->size() == 0 && $stat->mtime() < time() - $self->{reload_time}
) ) {
       utime undef, time, $self->{db_file};
       $content = $self->update_db_file();
   }
   if (!$content) {
       local $/ = undef;
       $content = <FILE>;
   }
   close(FILE);
  $self->parse_db_file($content) if $content;
  return $content;
}

sub update_db_file {

  my $self = shift;

  sysopen(FILE_NEW, $self->{db_file_new}, O_RDWR|O_CREAT|O_TRUNC) || return $self->raise_error("Can't open ".$self->{db_file_new}." $!");

  if (!flock FILE_NEW, LOCK_EX | LOCK_NB) {
      return $self->raise_error("Can't flock ".$self->{db_file_new}." $!");
  }

  my $content = $self->fetch_db_file;
  if ($content) {
     print FILE_NEW $content;
     move($self->{db_file_new}, $self->{db_file}) || $self->raise_error("Can't move file '".$self->{db_file_new}."': $!\n");
  }
  close(FILE_NEW);
  return $content;
}


sub fetch_db_file {

   my $self = shift;

   my $ua = LWP::UserAgent->new;

   $ua->timeout($self->{request_timeout});
   $ua->agent($self->{user_agent});

   my $response = $ua->get($self->{link_url});

   return $self->raise_error("Can't fetch ".$self->{link_url}." : ".$response->status_line) if !$response->is_success;
   return $response->content;
}

sub uptolike_tag {
  my $self = shift;
	
  my $uptolike_hash = 'lf' . sha1_hex($self->{host});

  my $result = '<script async="async" src="https://w.uptolike.com/widgets/v1/zp.js?pid=' . $uptolike_hash . '" type="text/javascript"></script>';

  return $result;
}

sub raise_error {
   my ($self, $error) = @_;
   $self->{'error'} = "<!--ERROR: $error -->";
   return;
}

1;
