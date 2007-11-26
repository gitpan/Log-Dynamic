#!/usr/bin/perl

use strict;
use warnings;

my $file = shift;
my $inst = {
	private => 'Attribute::Common::Code::Private',
};

print "\n-> Checking for optionally installed packages:\n";
foreach my $package (keys %{ $inst }) {
	print "   * $inst->{$package}... ";
	eval "use $inst->{$package}";
	$@
		? do { print "no\n"; $inst->{$package} = undef }
		: do { print "yes\n" }
}
print "\n";

open my $source, '<', "$file.template" or die "$0: $!\n";
open my $target, '>', "$file"          or die "$0: $!\n";

my $version;
my @code = map { 
	if (/^\$VERSION/) {
		($version = $_) =~ s/.*(\d+\.\d+).*/$1/s;
	}
	$_; 
} <$source>;

foreach my $line (@code) {
	$line =~ s/__USE_PRIVATE__/$inst->{'private'} 
		? "use base qw\/$inst->{private}\/;" : ''/e;
	$line =~ s/__PRIVATE__/$inst->{'private'} ? ': Private' : ''/e;
	$line =~ s/__VERSION__/$version/;
}

print "-> Writing $file... ";
print {$target} join '', @code;
print "done\n\n";

close $source;
close $target;

__END__
