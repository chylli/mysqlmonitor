#!perl -T
use 5.16.2;
use strict;
use warnings FATAL => 'all';
use Test::More qw(no_plan);
#use Test::Output;
use MySQL::Monitor;
use DBI;

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

my $monitor = MySQL::Monitor->new;
$monitor->parse_options(qw{-S /var/run/mysqld/mysqld.sock -u testmonitor -p 123456 -d testmonitor --chart-width=100 --chart-height=190 -S /var/run/mysqld/mysqld.sock deploy});

my ($read_dbh, $write_dbh) = $monitor->open_connections();
isa_ok($write_dbh, "DBI::db", "open_connection return a dbh");
is($read_dbh, $write_dbh,"read_dbh and write_dba are a same dbh when there is no monitored db in args");

$monitor->init_connections();
is(do_query($read_dbh,'select @@group_concat_max_len'), do_query($read_dbh, 'select GREATEST(@@group_concat_max_len, @@max_allowed_packet)'), "the variable group_concat_max_len should be changed");

$monitor->create_metadata_table();
is(do_query($write_dbh,'select version from testmonitor.metadata'), $MySQL::Monitor::VERSION, "table metadata created and data inserted")



