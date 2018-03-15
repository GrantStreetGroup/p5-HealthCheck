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

=head1 DESCRIPTION

A base class for writing Health Checks.

Results returned by these checks should correspond to the GSG
L<Health Check Standard|https://support.grantstreet.com/wiki/display/AC/Health+Check+Standard>.

=head1 METHODS

=head2 new

    my $checker = HealthCheck::Diagnostic::Sample->new( id => 'my-checker' );

=head3 ATTRIBUTES

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

sub tags { @{ shift->{tags} || [] } }

=head2 check

    my %results = %{ $checker->check(%params) }

=cut

sub check {
    my ( $self, @params ) = @_;
    # Allow either a hashref or even-sized list of params
    my %params = @params == 1 && ( ref $params[0] || '' ) eq 'HASH'
        ? %{ $params[0] } : @params;
    return $self->summarize( \%params );
}

=head2 summarize

    %result = %{ $checker->summarize( \%result ) };

Summarizes and validates the result.
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

An ISO8601 timestamp.

=back

Modifies the passed in hashref in-place.

=cut

sub summarize {
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

    $id //= $result->{id} // 0;
    my $status = $result->{status};
    $status = '' unless exists $statuses{ $status || '' };

    my @results;
    if ( exists $result->{results} ) {
        if ( ( ref $result->{results} || '' ) eq 'ARRAY' ) {

            # Merge the results if there is only a single check.
            if ( @{ $result->{results} } == 1 ) {
                my ($r) = @{ delete $result->{results} };
                %{$result} = ( %{$result}, %{$r} );
            }
            else {
                @results = @{ $result->{results} };
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
        $self->summarize( $r, "$id-" . ( $r->{id} // $i ) );

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

