package MySQL::Monitor;

use 5.16.2;
use strict;
use warnings FATAL => 'all';
use Getopt::Long;

=head1 NAME

MySQL::Monitor - Monitor mysql status and customed status

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

mysqlmonitor is a script to monitor mysql status and customed status which is a perl clone of mycheckpoint L<code.openark.org/forge/mycheckpoint>.
Perhaps a little code snippet.

=cut

my $help_msg = <<HELP;
Usage: mysqlmonitor [options] [command [, command ...]]

mysqlmonitor is a script to monitor mysql status and customed status which is a perl clone of mycheckpoint L<code.openark.org/forge/mycheckpoint>.

See online documentation on L<http://code.openark.org/forge/mycheckpoint/documentation>

Available commands:
  http
  deploy
  email_brief_report

Options:
  -h, --help            show this help message and exit
  -u USER, --user=USER  MySQL user
  -H HOST, --host=HOST  MySQL host. Written to by this application (default:
                        localhost)
  -p PASSWORD, --password=PASSWORD
                        MySQL password
  --ask-pass            Prompt for password
  -P PORT, --port=PORT  TCP/IP port (default: 3306)
  -S SOCKET, --socket=SOCKET
                        MySQL socket file. Only applies when host is localhost
                        (default: /var/run/mysqld/mysql.sock)
  --monitored-host=MONITORED_HOST
                        MySQL monitored host. Specity this when the host
                        you're monitoring is not the same one you're writing
                        to (default: none, host specified by --host is both
                        monitored and written to)
  --monitored-port=MONITORED_PORT
                        Monitored host's TCP/IP port (default: 3306). Only
                        applies when monitored-host is specified
  --monitored-socket=MONITORED_SOCKET
                        Monitored host MySQL socket file. Only applies when
                        monitored-host is specified and is localhost (default:
                        /var/run/mysqld/mysql.sock)
  --monitored-user=MONITORED_USER
                        MySQL monitored server user name. Only applies when
                        monitored-host is specified (default: same as user)
  --monitored-password=MONITORED_PASSWORD
                        MySQL monitored server password. Only applies when
                        monitored-host is specified (default: same as
                        password)
  --defaults-file=DEFAULTS_FILE
                        Read from MySQL configuration file. Overrides all
                        other options
  -d DATABASE, --database=DATABASE
                        Database name (required unless query uses fully
                        qualified table names)
  --skip-aggregation    Skip creating and maintaining aggregation tables
  --rebuild-aggregation
                        Completely rebuild (drop, create and populate)
                        aggregation tables upon deploy
  --purge-days=PURGE_DAYS
                        Purge data older than specified amount of days
                        (default: 182)
  --disable-bin-log     Disable binary logging (binary logging enabled by
                        default)
  --skip-disable-bin-log
                        Skip disabling the binary logging (this is default
                        behaviour; binary logging enabled by default)
  --skip-check-replication
                        Skip checking on master/slave status variables
  -o, --force-os-monitoring
                        Monitor OS even if monitored host does does nto appear
                        to be the local host. Use when you are certain the
                        monitored host is local
  --skip-alerts         Skip evaluating alert conditions as well as sending
                        email notifications
  --skip-emails         Skip sending email notifications
  --force-emails        Force sending email notifications even if there's
                        nothing wrong
  --skip-custom         Skip custom query execution and evaluation
  --skip-defaults-file  Do not read defaults file. Overrides --defaults-file
                        and ignores /etc/mycheckpoint.cnf
  --chart-width=CHART_WIDTH
                        Chart image width (default: 370, min value: 150)
  --chart-height=CHART_HEIGHT
                        Chart image height (default: 180, min value: 100)
  --chart-service-url=CHART_SERVICE_URL
                        Url to Google charts API (default:
                        http://chart.apis.google.com/chart)
  --smtp-host=SMTP_HOST
                        SMTP mail server host name or IP
  --smtp-from=SMTP_FROM
                        Address to use as mail sender
  --smtp-to=SMTP_TO     Comma delimited email addresses to send emails to
  --http-port=HTTP_PORT
                        Socket to listen on when running as web server
                        (argument is http)
  --debug               Print stack trace on error
  -v, --verbose         Print user friendly messages
  --version             Prompt version number
HELP

=head1 ATTRIBUTES

=cut


=head1 SUBROUTINES/METHODS

=head2 new

=cut

sub new {
    my $class = shift;

    my %options = 
      (
       "user"=> "",
       "host"=> "localhost",
       "password"=> "",
       "prompt_password"=> 0,
       "port"=> 3306,
       "socket"=> "/var/run/mysqld/mysql.sock",
       "monitored_host"=> undef,
       "monitored_port"=> 3306,
       "monitored_socket"=> undef,
       "monitored_user"=> undef,
       "monitored_password"=> undef,
       "defaults_file"=> "",
       "database"=> "mycheckpoint",
       "skip_aggregation"=> 0,
       "rebuild_aggregation"=> 0,
       "purge_days"=> 182,
       "disable_bin_log"=> 0,
       "skip_check_replication"=> 0,
       "force_os_monitoring"=> 0,
       "skip_alerts"=> 0,
       "skip_emails"=> 0,
       "force_emails"=> 0,
       "skip_custom"=> 0,
       "skip_defaults_file"=> 0,
       "chart_width"=> 370,
       "chart_height"=> 180,
       "chart_service_url"=> "http=>//chart.apis.google.com/chart",
       "smtp_host"=> undef,
       "smtp_from"=> undef,
       "smtp_to"=> undef,
       "http_port"=> 12306,
       "debug"=> 0,
       "verbose"=> 0,
       "version"=> 0,
       );

    return bless {options => \%options}, $class;
}

=head2 parse_options

parse the options, if there is a 'help' or 'man', print help info and exit

=cut

sub parse_options {
    my $self = shift;

    local @ARGV ;
    push @ARGV, @_;

    my $options = $self->{options};

    Getopt::Long::Configure("bundling");
    Getopt::Long::GetOptions
        (
         'h|help' => sub {$self->show_help},
         'H|host=s' => \$options->{host},
         'p|password=s' => \$options->{password},
         'ask-pass' => \$options->{prompt_password},
         'P|port=i' => \$options->{port},
         'S|socket=s' => \$options->{socket},
         'monitored-host=s' => \$options->{monitored_host},
         'monitored-port=s' => \$options->{monitored_host},
         'monitored-socket=s' => \$options->{monitored_socket},
         'monitored-user=s' => \$options->{monitored_user},
         'monitored-password=s' => \$options->{monitored_password},
         'defaults-file=s' => \$options->{defaults_file},
         'd|database=s' => \$options->{database},
         'skip-aggregation' => \$options->{skip_aggregation},
         'rebuild-aggregation' => \$options->{rebuild_aggregation},
         'purge-days=i' => \$options->{purge_days},
         'disable-bin-log' => \$options->{disable_bin_log},
         'skip-disable-bin-log' => sub {$options->{disable_bin_log} = 0},
         'skip-check-replication' => \$options->{skip_check_replication},
         'o|force-os-monitoring' => \$options->{force_os_monitoring},
         'skip-alerts' => \$options->{skip_alerts},
         'skip-emails' => \$options->{skip_emails},
         'force-emails' => \$options->{force_emails},
         'skip-custom' => \$options->{skip_custom},
         'skip-defaults-file' => \$options->{skip_defaults_file},
         'chart-width=i' => \$options->{chart_width},
         'chart-height=i' => \$options->{chart_height},
         'chart-service-url=s' => \$options->{chart_service_url},
         'smtp-host=s' => \$options->{smtp_host},
         'smtp-from=s' => \$options->{smtp_from},
         'smtp-to=s' => \$options->{smtp_to},
         'http-port=i' => \$options->{http_port},
         'debug' => \$options->{debug},
         'v|verbose' => \$options->{verbose},
         'version' => \$options->{version},

        );


    $self->{args} = \@ARGV;
}


=head2 show_help

print help information.

=cut

sub show_help {
    my $self = shift;
    print $help_msg, "\n";
    exit 0;
}

sub stub {
    my $self = shift;
    my $option = shift;
    print "option $option not implemented yet\n";
    exit 0;
}

=head2 verbose

print messages when program is in verbose mode.

=cut

sub verbose {
    my $self = shift;
    my ($message, $force_verbose) = @_;
    print "-- $message\n" if $self->{options}{verbose} || $force_verbose;
}

=head2 print_error

=cut

sub print_error {
    my $self = shift;
    my $message = shift;
    print STDERR "-- ERROR: $message\n";
}



=head2 run

The program entrance.

=cut

sub run {
    my $self = shift;
    $self->parse_options(@_);

    $self->verbose("mysqlmonitor version $VERSION. Copyright (c) 2012-2013 by Chylli", $self->{options}{version});




    # TODO
    # do the concreate things
}

=head1 AUTHOR

chylli, C<< <chylli.email at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mysqlmonitor at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=mysqlmonitor>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc MySQL::Monitor


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=mysqlmonitor>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/mysqlmonitor>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/mysqlmonitor>

=item * Search CPAN

L<http://search.cpan.org/dist/mysqlmonitor/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 chylli.

This program is distributed under the (Simplified) BSD License:
L<http://www.opensource.org/licenses/BSD-2-Clause>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of MySQL::Monitor
