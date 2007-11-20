package Log::Dynamic;

$VERSION = 0.01;

use strict;
use warnings;

use Carp;

my $PKG   = __PACKAGE__;
my $MODE  = '>>';  # By default we append
my $TYPES = undef;

# Constructor
sub open {
	my $class = shift;

	# Catch an object call
	$class = ref $class || $class;

	return bless _init({@_}), $class;
}

# Initialize our params
sub _init {
	my $args = shift;
	my $fh;

	unless ($args->{'file'}) {
		croak "$PKG: Must supply file: Log::Dynamic->open(file => 'foo')";
	}

	# Override append mode to clobber mode if requested
	if (defined $args->{'mode'} && $args->{'mode'} =~ m/^clobber$/) {
		$MODE = '>';
	}

	_init_types($args->{'types'},$args->{'invalid_type'});

	if ($args->{'file'} =~ /STD(?:OUT|ERR)/i) {
		$fh = uc $args->{'file'};
	} else {
		CORE::open $fh, $MODE, $args->{'file'}
			or croak "$PKG: Failed to open file '$args->{file}': $!";
	}

	return \$fh;
}

# Type initialization was a large enough chunk of code that
# I felt it should be pulled into its own subroutine.
sub _init_types {
	my $types   = shift || return;
	my $handler = shift || \&_invalid_type;

	# If provided the invalid type handler must be a coderef
	croak "$PKG: Value for the 'invalid_type' param must be a code ref"
		unless ref $handler eq 'CODE';

	# A Smudge of error checking. Non-empty array ref please
	croak "$PKG: Value for the 'types' param must be an array ref"
		unless ref $types eq 'ARRAY';
	croak "$PKG: Value for the 'types' param must not be an empty list"
		unless @{ $types };

	# We have types! Make a hash of types for easy lookup and
	# store our invalid type handler.
	$TYPES = { map { $_ => 1 } @{ $types } };
	$TYPES->{'_handle_invalid'} = $handler;
}

# For those of you that decide you want to use the standard 
# constructor notation of new(), here you go.
sub new { shift->open(@_) }

# O'hai. Sry, we closed...
sub close { close ${(shift)} }

# Base logging function
sub log {
	my $fh   = shift;             # File handle reference
	my $type = shift || return;   # Message type, REQUIRED
	my $msg  = shift || return;   # Message body, REQUIRED
	my $time = scalar localtime;  # Formatted timestamp

	_validate_type($type);

	# Formatted caller info. Because custom types are essentially
	# wrapper functions for log() we need to check up one more
	# level to get the correct caller information.
	my $call = join(' ',
		map {
			(caller(1))[$_]  # Called using $log->[custom type]()
			    ||           #      - OR -
			(caller(0))[$_]  # Called using $log->log()
		} 0..2
	);

	# Output formatted log entry. We turn off strict refs so that 
	# we can print to STDERR and STDOUT witout perl spitting an 
	# error and dying.
	no strict 'refs';
	print {$$fh} "$time [".uc($type)."] $msg ($call)\n";
}

sub AUTOLOAD {
	my $log  = shift;
	my $type = (our $AUTOLOAD = $AUTOLOAD);

	return if $type =~ /::DESTROY$/;
	$type =~ s/.*::(.+)$/$1/;

	_validate_type($type);

	# Define a subroutine for our new type. Since this new
	# sub just turns around and calls log() with a set value
	# for the $type variable you can probably lable this a 
	# form of function currying. 
	{
		no strict;
		no warnings;
		*$type = sub { shift->log($type,@_) };
	}

	# Log with our new type
	$log->log($type,@_);
}

# Valid log type
sub _validate_type {
	my $type = shift;

	if (defined $TYPES and not $TYPES->{$type}) {
		$TYPES->{'_handle_invalid'}->($type);
	} 
}

sub _invalid_type {
	my $type = shift;
	croak "$PKG: Type '$type' was not specified as a valid type";
}

# Cleanup... Just close the file handle
sub DESTROY { shift->close }

1;

# TODO:
#  1. Custom log entry formatting
#  2. dump() function

__END__

=head1 NAME

B<Log::Dynamic> - OOish dynamic and customizable logging

=head1 SYNOPSIS

I<Object instatiation>

   use Log::Dynamic;

   # Set up logging so that _ALL_ log types are valid
   my $log = Log::Dynamic->open (
       file => 'logs/my.log',
       mode => 'append',
   );

      ## OR ##

   # Set up logging so that there is a set list of valid types
   my $log = Log::Dynamic->open (
       file  => 'logs/my.log',
       mode  => 'append',
       types => [qw/ foo bar baz /],
   );

      ## OR ##

   # Set up logging so that there is a set list of valid types
   # and override the default invalid type handler
   my $log = Log::Dynamic->open (
       file         => 'logs/my.log',
       mode         => 'append',
       types        => [qw/ foo bar baz /],
       invalid_type => sub { "INVALID TYPE: ".(shift)."\n" },
   );

I<Basic logging>

   # Just like many other logging packages:
   $log->log('INFO', 'I can has info?');
   $log->log('ERROR', 'Oh crapz! Someone killed a kittah!');

I<Custom logging>

   # Call any log type you like as an object method. For 
   # example, if you are logging cache hits and misses you 
   # might want to do something like:
   if ($CACHE->{$key}) {
       $log->cache_hit("Got hit on key $key");
       return $CACHE->{$key};
   } else {
       $log->cache_miss("Awww... Key $key was a miss");
       $CACHE->{$key} = do_expensive_operation(@args);
   }

I<Other usage>

   # Use the object as a file handle for print() statements
   # from within your script or application:
   print {$$log} "This is a custom message. Pay attention!\n";

=head1 DESCRIPTION

Yet another darn logger? Why d00d?

Well, I wanted to write a lite weight logging module that...

 * developers could use in a way that felt natural to them
   and it would just work, 

 * was adaptable enough that it could be used in dynamic, 
   ever changing environments,

 * was flexible enough to satisfy most logging needs without 
   too much overhead,

 * and gave developers full control over handling the myriad
   of log events that occur in large applications.

Log::Dynamic still has a ways to go, but the direction seems 
promising. Comments and suggestions are always welcome. 

=head1 LOG FORMAT

Currently Log::Dynamic has only one format for the log entries which
looks like:

    TIME/DATE STAMP [LOG TYPE] LOG MESSAGE (CALLER INFO)

Eventually this module will have support user defined log formats,
as it should having a name like Log::Dynamic.

=head1 LOG TYPES

Log "type" refers to the string displayed in the square brackets 
of your log output. In the following example the type is 'BEER ERROR':

    Thu Nov  8 21:14:12 2007 [BEER ERROR] Need more (main bottles.pl 99)

For those unfamiliar with logging this is especially useful when
grep-ing through your logs for specific types of errors, ala: 

    % grep -i 'beer error' /path/to/my.log

As stated above, by default there is no set list of types that 
this module supports. If you want to have a new type start showing 
up in your logs just call an object method of that name and 
Log::Dynamic will automatically do what you want: 

    $log->new_type('Hai!');

=head1 LIMITING LOG TYPES

By default Log::Dynamic supports any log type you throw at it. However,
if you would like to define a finite set of valid (supported) log types 
you may do so using the 'types' parameter durning object instantiation. 
For example, if you would like only the types 'info', 'warn', and 'error'
to be valid log types within your application you would instantiate you
object like:

    my $log = Log::Dynamic->open (
        file  => 'my.log',
        types => [qw/ info warn error /],
    );

If you decide to define a set of valid types and your application attempts
to log with an invalid type, then, B<by default Log::Dynamic will croak with 
an appropriate error>. _HOWEVER_, if you don't want to go around your 
application wrapping each log call in an eval then you may override this 
behavior using the 'invalid_type' parameter:

    my $log = Log::Dynamic->open (
        file         => 'my.log',
        types        => [qw/ info warn error /],
        invalid_type => sub { warn (shift)." is bad! Moving on...\n" }
    );

If you choose to override the default invalid type handler Log::Dynamic 
will execute the provided subroutine and will pass it one parameter: 
the string of the invalid type that your application attempted to use. 

=head1 METHODS

=over 4

=item *

B<open()>

This is the object constructor. (Sure, you can still use new()
if you wish) B<open()> has two available parameters, each with
several allowed values. They are:

B<file> : file name, STDOUT, STDERR

    -REQUIRED-

B<mode> : append, clobber

    -OPTIONAL- The default value is 'append'.

B<types> : array ref of your valid types

    -OPTIONAL- By default Log::Dynamic lets you call _ANY_ type as 
    a method. However, if you would like to limit the set of valid 
    types you can do that using this parameter. Once the list is set, 
    if an invalid type is called Log::Dynamic croaks with a message.

B<invalid_type> : code ref to handle invalid types

    -OPTIONAL- See LIMITING LOG TYPES above.

Here is an example instantiation for logging to a file that 
you want to clobber:

    my $log = Log::Dynamic->open (
        file => '/path/to/logs/my.log',
        mode => 'clobber',
    );

Here is an example instantiation for logging to STDERR:

    my $log = Log::Dynamic->open (file => STDERR);

As you can see there is no need to quote STDERR and STDOUT, but
it will still work if you choose to quote them.

=item *

B<close()>

Close the file handle.

=item *

B<log()>

Your basic log subroutine. just give it the log type and
the log message:

    $log->log('TYPE','MESSAGE');

Message Types are discussed above.

=item *

B<Custom Methods>

Log any type of message you want simply by calling the type as an
object method. For example, if you want to log a message with a 
type of ALARM you would do:

   $log->alarm('OONTZ!');

This would print a log entry that looks like:

   Thu Nov  8 21:14:12 2007 [ALARM] OONTZ! (main techno.pl 42)

This functionality was the impetus for writing this module.
What ever type you want to see in the log B<JUST USE IT!> =)

=back

=head1 OTHER USAGE

While most OO modules bless a reference to a data structure, this 
module blesses a reference to an open file handle. Why did I do 
that? Because I can and I felt like doing something different. The 
only "special" thing this really lets you do is use the object as 
a file handle from within your script or application. All you have 
to do is dereference it when you use it. For example:

    # Normal log entry
    $log->info('This is information');

    # Special log entry
    print {$$log} "*** Hai. I am special. Pls give me attention! ***\n";

Obviously if you use the object in this special way you will not
get any of the nice additional information (timestamp, log type, 
and caller information) that you would get when using the normal 
way. This simply gives you the flexibility to print anything you 
want to your log. A useful example would be a dump of an object
or data structure: 

    use Data::Dumper;
    print {$$log} "Object dump:\n" . Dumper($object);

=head1 BUGS

None that I know of yet.

=head1 AUTHOR

James Conerly I<E<lt>jconerly@cpan.orgE<gt>> 2007

=head1 LICENSE

This software is free to use. If you use pieces of my code in your
scripts or applications all I ask is that you site me. Other than
that, log away my friends.

=head1 SEE ALSO

Carp

=cut
