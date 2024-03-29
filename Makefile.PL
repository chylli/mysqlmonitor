use 5.16.2;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'MySQL::Monitor',
    AUTHOR           => q{chylli <chylli.email at gmail.com>},
    VERSION_FROM     => 'lib/MySQL/Monitor.pm',
    ABSTRACT_FROM    => 'lib/MySQL/Monitor.pm',
    LICENSE          => 'FreeBSD',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.16.2,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        #'ABC'              => 1.6,
        #'Foo::Bar::Module' => 5.0401,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'mysqlmonitor-*' },
);
