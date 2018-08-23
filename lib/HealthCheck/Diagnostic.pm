package HealthCheck::Diagnostic;

# ABSTRACT: A base clase for writing health check diagnositics
# VERSION: 0.01

use 5.010;
use strict;
use warnings;

use Carp;

# From the O'Reilly Regular Expressions Cookbook 2E, sorta
# https://www.safaribooksonline.com/library/view/regular-expressions-cookbook/9781449327453/ch04s07.html
my $iso8601_timestamp = qr/^(?:
    (?P<year>[0-9]{4})(?P<hyphen>-)?
    (?P<month>1[0-2]|0[1-9])(?(<hyphen>)-)
    (?P<day>3[01]|0[1-9]|[12][0-9])
    (?:
        [T ]
        (?P<hour>2[0-3]|[01][0-9])(?(<hyphen>):)
        (?P<minute>[0-5][0-9])(?(<hyphen>):)
        (?P<second>[0-5][0-9])
        (?: \. (?P<ms>\d+) )?
    )?
    | (?P<year>[0-9]{4})(?P<hyphen>-)?(?P<month>1[0-2]|0[1-9])
    | (?P<year>[0-9]{4})
)$/x;

=head1 SYNOPSIS

    package HealthCheck::Diagnostic::Sample;
    use parent 'HealthCheck::Diagnostic';

    # Required implementation of the check
    # or you can override the 'check' method and avoid the
    # automatic call to 'summarize'
    sub run {
        my ( $class_or_self, %params ) = @_;

        # will be passed to 'summarize' by 'check'
        return { %params, status => 'OK' };
    }

You can then either instantiate an instance and run the check.

    my $diagnostic = HealthCheck::Diagnostic::Sample->new( id => 'my_id' );
    my $result     = $diagnostic->check;

Or as a class method.

    my $result = HealthCheck::Diagnostic::Sample->check();

=head1 DESCRIPTION

A base class for writing Health Checks.
Provides some helpers for validation of results returned from the check.

This module does not require that an instance is created to run checks against.
If your code requires an instance, you will need to verify that yourself.

Results returned by these checks should correspond to the GSG
L<Health Check Standard|https://support.grantstreet.com/wiki/display/AC/Health+Check+Standard>.

Implementing a diagnostic should normally be done in L<run>
to allow use of the helper features that L</check> provides.

=head1 REQUIRED METHODS

=head2 run

    sub run {
        my ( $class_or_self, %params ) = @_;
        return { %params, status => 'OK' };
    }

A subclass must either implement a C<run> method,
which will be called by L</check>
have its return value passed through L</summarize>,
or override C<check> and handle all validation itself.

See the L</check> method documentation for suggestions on when it
might be overridden.

=head1 METHODS

=head2 new

    my $diagnostic
        = HealthCheck::Diagnostic::Sample->new( id => 'my-diagnostic' );

=head3 ATTRIBUTES

Attributes set on the object created will be copied into the result
by L</summarize>, without overriding anything already set in the result.

=over

=item tags

An arrayref used as the default set of tags for any checks that don't
override them.

=back

Any other parameters are included in the "Result" hashref returned.

Some recommended things to include are:

=over

=item id

The unique id for this check.

=item label

A human readable name for this check.

=back

=cut

sub new {
    my ($class, @params) = @_;

    # Allow either a hashref or even-sized list of params
    my %params = @params == 1 && ( ref $params[0] || '' ) eq 'HASH'
        ? %{ $params[0] } : @params;

    bless \%params, $class;
}

=head2 tags

Read only accessor that returns the list of tags registered with this object.

=cut

sub tags { return unless ref $_[0]; @{ shift->{tags} || [] } }

=head2 check

    my %results = %{ $diagnostic->check(%params) }

This method is what is normally called by the L<HealthCheck> runner,
but this version expects you to implement a L</run> method for the
body of your diagnostic.
This thin wrapper
makes sure C<%params> is an even-sided list (possibly unpacking a hashref)
before passing it to L</run>,
trapping any exceptions,
and passing the return value through L</summarize>.

This could be used to validate parameters or to modify the the return value
in some way.

    sub check {
        my ( $self, @params ) = @_;

        # Require check as an instance method
        croak("check cannot be called as a class method") unless ref $self;

        # Allow either a hashref or even-sized list of params
        my %params = @params == 1 && ( ref $params[0] || '' ) eq 'HASH'
            ? %{ $params[0] } : @params;

        # Validate any required parameters and that they look right.
        my $required_param = $params{required} || $self->{required};
        croak("The 'required' parameter is required")
            unless $required_param and ref $required_param == 'HASH';

        # Calls $self->run and then passes the result through $self->summarize
        my $res = $self->SUPER::check( %params, required => $required_param );

        # Modify the result after it has been summarized
        delete $res->{required};

        # and return it
        return $res;
    }

=cut

sub check {
    my ( $class_or_self, @params ) = @_;

    # Allow either a hashref or even-sized list of params
    my %params = @params == 1 && ( ref $params[0] || '' ) eq 'HASH'
        ? %{ $params[0] } : @params;

    my $class = ref $class_or_self || $class_or_self;
    croak("$class does not implement a 'run' method")
        unless $class_or_self->can('run');

    local $@;
    my @res = eval { local $SIG{__DIE__}; $class_or_self->run(%params) };
    @res = { status => 'CRITICAL', info => $@ } if $@;

    if ( @res == 1 && ( ref $res[0] || '' ) eq 'HASH' ) { }    # noop, OK
    elsif ( @res % 2 == 0 ) { @res = {@res}; }
    else {
        carp("Invalid return from $class\->run (@res)");
        @res = { status => 'UNKNOWN' };
    }

    return $class_or_self->summarize(@res);
}

=head2 summarize

    %result = %{ $diagnostic->summarize( \%result ) };

Validates, pre-formats, and returns the C<result> so that it is easily
usable by HealthCheck.

The attributes on the C<$diagnostic> get copied into the C<result>.

The C<status> and C<info> are summarized when we have multiple
C<results> in the C<result>. All of the C<info> values get appended
together. One C<status> value is selected from the list of C<status>
values.

Used by L</check>.

Carps a warning if validation fails on several keys.

=over

=item status

Expects it to be one of C<OK>, C<WARNING>, C<CRITICAL>, or C<UNKNOWN>.

Also carps if it does not exist.

=item results

Complains if it is not an arrayref.

=item id

Complains if the id contains anything but
lowercase ascii letters, numbers, and underscores.

=item timestamp

Expected to look like an ISO8601 timestamp.

=back

Modifies the passed in hashref in-place.

=cut

sub summarize {
    my ( $self, $result ) = @_;

    if ( ref $self ) {
        $result->{$_} = $self->{$_}
            for grep { not exists $result->{$_} } keys %{$self};
    }

    return $self->_summarize( $result, $result->{id} // 0 );
}

sub _summarize {
    my ($self, $result, $id) = @_;

    # Indexes correspond to Nagios Plugin Return Codes
    # https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/3/en/pluginapi.html
    my @forward = qw( OK WARNING CRITICAL UNKNOWN );

    # The order of preference to inherit from a child.
    my %statuses = (
        UNKNOWN  => -1,
        OK       => 0,
        WARNING  => 1,
        CRITICAL => 2,
    );

    my $status = $result->{status};
    $status = '' unless exists $statuses{ $status || '' };

    my @results;
    if ( exists $result->{results} ) {
        if ( ( ref $result->{results} || '' ) eq 'ARRAY' ) {
            @results = @{ $result->{results} };

            # Merge if there is only a single result.
            if ( @results == 1 ) {
                my ($r) = @{ delete $result->{results} };
                %{$result} = ( %{$result}, %{$r} );

                # Now that we've merged, need to redo everything again
                return $self->_summarize($result, $id);
            }
        }
        else {
            my $disp
                = defined $result->{results}
                ? "invalid results '$result->{results}'"
                : 'undefined results';
            carp("Result $id has $disp");
        }
    }

    foreach my $i ( 0 .. $#results ) {
        my $r = $results[$i];
        $self->_summarize( $r, "$id-" . ( $r->{id} // $i ) );

        my $s = $r->{status};
        $s = $forward[$s] if defined $s and $s =~ /^[0-3]$/;

        $status = uc($s)
            if $s
            and exists $statuses{ uc $s }
            and $statuses{ uc $s } > $statuses{ $status || 'UNKNOWN' };
    }

    # If we've found a valid status in our children,
    # use that if we don't have our own.
    $result->{status} //= $status if $status;

    if ( exists $result->{id} ) {
        my $rid = $result->{id};
        unless ( defined $rid and $rid =~ /^[a-z0-9_]+$/ ) {
            my $disp_id = defined $rid ? "invalid id '$rid'" : 'undefined id';
            carp("Result $id has an $disp_id");
        }
    }

    if ( exists $result->{timestamp} ) {
        my $ts = $result->{timestamp};
        unless ( defined $ts and $ts =~ /$iso8601_timestamp/ ) {
            my $disp_timestamp
                = defined $ts
                ? "invalid timestamp '$ts'"
                : 'undefined timestamp';
            carp("Result $id has an $disp_timestamp");
        }
    }

    if ( not exists $result->{status} ) {
        carp("Result $id does not have a status");
    }
    elsif ( not defined $result->{status} ) {
        carp("Result $id has undefined status");
    }
    elsif ( not exists $statuses{ uc( $result->{status} // '' ) } ) {
        carp("Result $id has invalid status '$result->{status}'");
    }

    $result->{status} = 'UNKNOWN'
        unless defined $result->{status} and length $result->{status};

    return $result;
}

1;

=head1 DEPENDENCIES

Perl 5.10 or higher.

=head1 CONFIGURATION AND ENVIRONMENT

None

=head1 SEE ALSO

L<Writing a HealthCheck::Diagnostic|writing_a_healthcheck_diagnostic>
