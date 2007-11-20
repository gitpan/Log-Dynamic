#!/usr/bin/perl

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'Log::Dynamic',
    'VERSION_FROM' => 'lib/Log/Dynamic.pm',
    'ABSTRACT'     => 'OOish dynamic and customizable logging',
    'AUTHOR'       => 'James Conerly <jmc.dev.perl@gmail.com>',
);

__END__
