#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib';

use Log::Dynamic;

my $log = Log::Dynamic->open (
	file         => 'STDOUT',
	mode         => 'append',
	types        => [qw/ foo bar /],
#	invalid_type => \&invalid, 
);

sub invalid { 
	die "FUCK! [type=".(shift || 'ghey')."]\n";
}

$log->james('yo');
$log->foo('FOOL');
$log->bar('GO TO T3H BAR!');
$log->foo('FOOL');
$log->bar('GO TO T3H BAR!');
