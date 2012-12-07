#!perl -T
use 5.16.2;
use strict;
use warnings FATAL => 'all';
use Test::More qw(no_plan);
#use Test::Output;
use MySQL::Monitor;


my %options = MySQL::Monitor::parse_options(qw{-S /var/run/mysqld/mysqld.sock -u testmonitor -p 123456 -d testmonitor --chart-width=100 --chart-height=190 deploy});

# test parse option
is($options{host}, 'localhost', "default args is ok");
is($options{password}, '123456', "args is ok");




%options = MySQL::Monitor::parse_options(qw{-S /var/run/mysqld/mysqld.sock -u testmonitor -p 123456 -d testmonitor --chart-width=100 --chart-height=90  deploy});

is($options{chart_width}, 150, "the min vlaue of chart-width is 150");
is($options{chart_height}, 100, "the the min value of chart-height is 100");

#stderr_is(sub {eval {MySQL::Monitor::run}, "purge-days must be at least 1\n",'purge-days must be at least 1');



#done_testing(2);
