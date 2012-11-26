#!perl -T
use 5.16.2;
use strict;
use warnings FATAL => 'all';
use Test::More qw(no_plan);
#use Test::Output;
use MySQL::Monitor;

my $monitor = MySQL::Monitor->new;
isa_ok($monitor, "MySQL::Monitor", "create MySQL::Monitor object");

$monitor->parse_options(qw{-S /var/run/mysqld/mysqld.sock -u mychckpoint_user -p 123456 -d mycheckpoint --chart-width=100 --chart-height=190 deploy});

# test parse option
is($monitor->{options}{host}, 'localhost', "default args is ok");
is($monitor->{options}{password}, '123456', "args is ok");




$monitor = MySQL::Monitor->new;
$monitor->parse_options(qw{-S /var/run/mysqld/mysqld.sock -u mychckpoint_user -p 123456 -d mycheckpoint --chart-width=100 --chart-height=90 --purge-days=0 deploy});

is($monitor->{options}{chart_width}, 150, "the min vlaue of chart-width is 150");
is($monitor->{options}{chart_height}, 100, "the the min value of chart-height is 100");

#stderr_is(sub {eval {$monitor->run}, "purge-days must be at least 1\n",'purge-days must be at least 1');

my ($read_dbh, $write_dbh) = $monitor->open_connections();
isa_ok($write_dbh, "DBI::db", "open_connection return a dbh");
is($read_dbh, $write_dbh,"read_dbh and write_dba are a same dbh when there is no monitored db in args")


#done_testing(2);
