#!perl -T
use 5.16.2;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'MySQL::Monitor' ) || print "Bail out!\n";
}

diag( "Testing MySQL::Monitor $MySQL::Monitor::VERSION, Perl $], $^X" );
