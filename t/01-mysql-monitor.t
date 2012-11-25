#!perl -T
use 5.16.2;
use strict;
use warnings FATAL => 'all';
use Test::More qw(no_plan);
use MySQL::Monitor;

my $monitor = MySQL::Monitor->new;
isa_ok($monitor, "MySQL::Monitor", "create MySQL::Monitor object");

$monitor->parse_options(qw{-S /var/run/mysqld/mysqld.sock -u mychckpoint_user -p 123456 -d mycheckpoint deploy});


#is($monitor->{args}[0],'-S', "args is ok");
is($monitor->{options}{host}, 'localhost', "default args is ok");
is($monitor->{options}{password}, '123456', "args is ok");

#done_testing(2);
