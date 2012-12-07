#!perl
use 5.16.2;
use strict;
use warnings FATAL => 'all';
use Test::More qw(no_plan);
#use Test::Output;
use MySQL::Monitor;
use DBI;
use List::MoreUtils qw(any);

sub do_query{
    my ($dbh, $query) = @_;
    my $sth = $dbh->prepare($query);
    $sth->execute();
    my ($result) = $sth->fetchrow_array;
    return $result;
}

sub setup{
    my $dbh = DBI->connect("DBI:mysql:database=test","testmonitor","123456");
    $dbh->do("drop database if exists testmonitor");
    $dbh->do("create database testmonitor");
}

setup();

my %options = MySQL::Monitor::parse_options(qw{-S /var/run/mysqld/mysqld.sock -u testmonitor -p 123456 -d testmonitor --chart-width=100 --chart-height=190 -S /var/run/mysqld/mysqld.sock deploy});

my ($read_dbh, $write_dbh) = MySQL::Monitor::open_connections();
isa_ok($write_dbh, "DBI::db", "open_connection return a dbh");
is($read_dbh, $write_dbh,"read_dbh and write_dba are a same dbh when there is no monitored db in args");

MySQL::Monitor::init_connections();
is(do_query($read_dbh,'select @@group_concat_max_len'), do_query($read_dbh, 'select GREATEST(@@group_concat_max_len, @@max_allowed_packet)'), "the variable group_concat_max_len should be changed");

MySQL::Monitor::deploy_schema();
is(do_query($write_dbh,'select version from testmonitor.metadata'), $MySQL::Monitor::VERSION, "table metadata created and data inserted");

is(do_query($write_dbh,'select max(n) from testmonitor.numbers'), 4095, "table numbers created and data inserted");

is(do_query($write_dbh,'select chart_height from testmonitor.charts_api'), 190, "table charts_api created and data inserted");

is(do_query($write_dbh,'select count(*) from testmonitor.html_components'),1,"table html_components created and data inserted");

is(do_query($write_dbh,'select count(*) from testmonitor.custom_query'),0,"table custom_query created");
is(do_query($write_dbh,'select count(*) from testmonitor.custom_query_view'),0,"table custom_query created");

is(MySQL::Monitor::get_column_sign_indicator("innodb_buffer_pool_pages_total"), "SIGNED", "get_column_sign_indicator is ok");

is(MySQL::Monitor::get_column_sign_indicator("abcdefgh"), "UNSIGNED", "get_column_sign_indicator is ok");

is(MySQL::Monitor::should_monitor_os(), 1, "should_monitor_os() ok");

my @cols = MySQL::Monitor::get_status_variables_columns();
is((any {$_ eq 'queries'} @cols), 1, "get_status_variables_columns ok");

is(MySQL::Monitor::normalize_variable_value('Innodb_have_atomic_builtins', 'on'), 1, "normalize_variable_value ok");
is(do_query($write_dbh,'select count(*) from testmonitor.status_variables'),0,"table status_variables created");
is(do_query($write_dbh,'select count(*) from testmonitor.alert_condition'),0,"table alert_condition created");
is(do_query($write_dbh,'select count(*) from testmonitor.alert'),0,"table alert created");
is(do_query($write_dbh,'select count(*) from testmonitor.alert_pending'),0,"table alert_pending created");
is(do_query($write_dbh,'select count(*) from testmonitor.sv_latest'),1,"view sv_latest created");
is(do_query($write_dbh,'select count(*) from testmonitor.sv_diff'),0,"view sv_diff created");
is(do_query($write_dbh,'select count(*) from testmonitor.sv_sample'),0,"view sv_sample created");
