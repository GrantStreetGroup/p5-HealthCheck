package HealthCheck;

# ABSTRACT: A health check for your code
# VERSION: 0.01

use 5.010;
use strict;
use warnings;

use Carp;

=head1 NAME

HealthCheck - Health Check Runner

=head1 SYNOPSIS

    use HealthCheck;

    sub my_check { return { id => "my_check", status => 'WARNING' } }

    my $checker = HealthCheck->new(
        id     => 'main_checker',
        label  => 'Main Health Check',
        tags   => [qw( fast cheap )],
        checks => [
            sub { return { id => 'coderef', status => 'OK' } },
            'my_check',          # Name of a method on caller
        ],
    );

    my $other_checker = HealthCheck->new(
        id     => 'my_health_check',
        label  => "My Health Check",
        tags   => [qw( cheap easy )],
        other  => "Other details to include",
    )->register(
        'My::Checker',       # Name of a loaded class that ->can("check")
        My::Checker->new,    # Object that ->can("check")
    );

    # You can add HealthCheck instances as checks
    # You could add a check to itself to create an infinite loop of checks.
    $checker->register( $other_checker );

    # A hashref of the check config
    # This whole hashref is passed as an argument
    # to My::Checker->another_check
    $checker->register( {
        invocant    => 'My::Checker',      # to call the "check" on
        check       => 'another_check',    # name of the check method
        tags        => [qw( fast easy )],
        more_params => 'anything',
    } );

    my @tags = $checker->tags;    # returns fast, cheap

    my %result = %{ $checker->check };


    package My::Checker;

    # A checker class or object just needs to have either
    # a # check method, which is used by default,
    # or another method as specified in a hash config.

    sub new { bless {}, $_[0] }

    # Any checks *must* return a valid "Health Check Result" hashref.

    sub check {
        return {
            id => ( ref $_[0] ? "object_method" : "class_method" ),
            status => "WARNING",
        };
    }

    sub another_check {
        my ($self, %params) = @_;
        return {
            id     => 'another_check',
            label  => 'A Super custom check',
            status => ( $params{more_params} eq 'fine' ? "OK" : "CRITICAL" ),
        };
    }

C<%result> will be

    'id'      => 'main_checker',
    'label'   => 'Main Health Check',
    'tags'    => [qw( fast cheap )],
    'results' => [
        { 'id' => 'coderef',  'status' => 'OK' },
        { 'id' => 'my_check', 'status' => 'WARNING' },
        {
            'id'      => 'my_health_check',
            'label'   => 'My Health Check',
            'tags'    => [qw( cheap easy )],
            'other'   => 'Other details to include',
            'results' => [
                { 'id' => 'class_method',  'status' => 'WARNING' },
                { 'id' => 'object_method', 'status' => 'WARNING' },
            ]
        },
        {
            'id'     => 'another_check',
            'label'  => 'A Super custom check',
            'status' => 'CRITICAL'
        },
    ],

Specifying C<tags> runs only tuhe subset of checks that match the tags.

    $checker->check( tags => ['fast'] );
    # returns
    # {
    #     'id'      => 'main_checker',
    #     'label'   => 'Main Health Check',
    #     'tags'    => [ 'fast', 'cheap' ],
    #     'results' => [
    #         { 'id' => 'coderef',  'status' => 'OK' },
    #         { 'id' => 'my_check', 'status' => 'WARNING' },
    #         {
    #             'id'     => 'another_check',
    #             'label'  => 'A Super custom check',
    #             'status' => 'CRITICAL',
    #         }
    #     ],
    # }

    $checker->check( tags => ['cheap'] );
    # returns
    # {
    #     'id'      => 'main_checker',
    #     'label'   => 'Main Health Check',
    #     'tags'    => [ 'fast', 'cheap' ],
    #     'results' => [
    #         { 'id' => 'coderef',  'status' => 'OK' },
    #         { 'id' => 'my_check', 'status' => 'WARNING' },
    #         {
    #             'id'      => 'my_health_check',
    #             'label'   => 'My Health Check',
    #             'tags'    => [ 'cheap', 'easy' ],
    #             'other'   => 'Other details to include',
    #             'results' => [
    #                 { 'id' => 'class_method',  'status' => 'WARNING' },
    #                 { 'id' => 'object_method', 'status' => 'WARNING' },
    #             ],
    #         },
    #     ],
    # }

    $checker->check( tags => ['easy'] );
    # returns
    # {
    #     'id'      => 'main_checker',
    #     'label'   => 'Main Health Check',
    #     'tags'    => [ 'fast', 'cheap' ],
    #     'results' => [ {
    #             'id'      => 'my_health_check',
    #             'label'   => 'My Health Check',
    #             'tags'    => [ 'cheap', 'easy' ],
    #             'other'   => 'Other details to include',
    #             'results' => [
    #                 { 'id' => 'class_method',  'status' => 'WARNING' },
    #                 { 'id' => 'object_method', 'status' => 'WARNING' }
    #             ],
    #         },
    #         {
    #             'id'     => 'another_check',
    #             'label'  => 'A Super custom check',
    #             'status' => 'CRITICAL'
    #         }
    #     ],
    # }

=head1 DESCRIPTION

Allows you to create callbacks that check the health of your application
and return a status result.

Results returned by these checks should correspond to the GSG
L<Health Check Standard|https://support.grantstreet.com/wiki/display/AC/Health+Check+Standard>.

=head1 METHODS

=head2 new

    my $checker = HealthCheck->new( id => 'my-checker' );

=head3 ATTRIBUTES

=over

=item checks

Passed to L</register> to initialize checks.

=item tags

Provides a default set of tags that apply to any checks that don't
include them.

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
    my ( $class, %params ) = @_;
    my $checks = delete $params{checks};
    my $self = bless {%params}, $class;
    return $checks ? $self->register($checks) : $self;
}

=head2 tags

Read only accessor that returns the tags registered with this object.

=cut

sub tags { @{ shift->{tags} || [] } }

=head2 register

    $checker->register({
        invocant => $class_or_object,
        check    => $method_on_invocant_or_coderef,
        more     => "any other params are passed to the check",
    });

Takes a list of check definitions to be added to the object.

Each registered check must return a valid GSG Health Check response,
either as a hashref or an even-sized list.
See the GSG Health Check Standard (linked in L</DESCRIPTION>)
for the fields that checks should return.

Rather than having to always pass in the full hashref definition,
several common cases are detected and used to fill out the check.

=over

=item coderef

If passed a coderef, this will just be called with an empty hashref

=item object

If a blessed object is passed in, we check whether it has a C<check> method,
otherwise throw an exception.

=item class name

If a string is passed in, we first test whether it is a loaded class
that has a C<check> method.

=item method

If the string was not a class with a check method, we look up the
C<caller> of C<register> and see if it has a method with this name,
otherwise throws an exception.

=item full hashref of params

The full hashref can consist of a C<check> key that the above heuristics
are applied,
or include an C<invocant> key,
that is used as either the C<object> or C<class name>.
With the C<invocant> specified, the now optional C<check> key
defaults to "check" and is used as the method to call on C<invocant>.

All attributes other than C<invocant> and C<check> are passed to the check.

=back

=cut

sub register {
    my ($self, @checks) = @_;
    croak("register cannot be called as a class method") unless ref $self;
    return $self unless @checks;
    my $class = ref $self;

    @checks = @{ $checks[0] }
        if @checks == 1 and ( ref $checks[0] || '' ) eq 'ARRAY';

    # If the check that was passed in is just the name of a method
    # we are going to use our caller as the invocant.
    my $caller;
    my $find_caller = sub {
        my ( $i, $c ) = ( 1, undef );
        do { ($c) = caller( $i++ ) } while $c->isa(__PACKAGE__);
        $c;
    };

    foreach (@checks) {
        my $type = ref $_ || '';
        my %c
            = $type eq 'HASH'  ? ( %{$_} )
            : $type eq 'ARRAY' ? ( check => $class->register($_) )
            :                    ( check => $_ );

        croak("check parameter required") unless $c{check};

        # If it's not a coderef,
        # it must be the name of a method to call on an invocant.
        unless ( ( ref $c{check} || '' ) eq 'CODE' ) {

            # If they passed in an object or a class that can('check')
            # then we want to set that as the invocant so the check
            # runner does the right thing.
            if ( $c{check} and not $c{invocant} and do {
                    local $@;
                    eval { local $SIG{__DIE__}; $c{check}->can('check') };
                } )
            {
                $c{invocant} = $c{check};
                $c{check}    = 'check';
            }

            # If they just passed in a method name,
            # we can see if the caller has that method.
            unless ($c{invocant}) {
                $caller ||= $find_caller->();

                if ($caller->can($c{check}) ) {
                    $c{invocant} = $caller;
                }
                else {
                    croak("Can't determine what to do with '$c{check}'");
                }
            }

            croak("'$c{invocant}' cannot '$c{check}'")
                unless $c{invocant}->can( $c{check} );
        }

        push @{ $self->{checks} }, \%c;
    }

    return $self;
}

=head2 check

    my %results = %{ $checker->check(%params) }

Calls all of the registered checks and returns a hashref of the results of
processing the checks.
Passes the L</full hashref of params> as an even-sized list to the check,
without the C<invocant> or C<check> keys.
This hashref is shallow merged with and duplicate keys overridden by
the C<%params> passed in.

If only a single check is registered,
the results from that check are merged with, and will override
the L</ATTRIBUTES> set on the object instead of being put in
a C<results> arrayref.

Throws an exception if no checks have been registered.

=cut

sub check {
    my ($self, %params) = @_;
    croak("check cannot be called as a class method") unless ref $self;
    croak("No registered checks") unless @{ $self->{checks} || [] };

    my %ret    = %{$self};
    my @checks = @{ delete $ret{checks} };

    my @res = map {
        my %c = %{$_};
        my $i = delete $c{invocant} || '';
        my $m = delete $c{check}    || '';
        my @r = $i ? $i->$m( %c, %params ) : $m->( %c, %params );

          @r == 1 && ref $r[0] eq 'HASH' ? $r[0]
        : @r % 2 == 0 ? {@r}
        : do {
            my $c = $i ? "$i->$m" : "$m";
            carp("Invalid return from $c (@r)");
            ();
        };
    } grep {
        $self->should_run( $_, %params );
    } @checks;

    # Merge the results if there is only a single check.
    if ( @res == 1 ) { %ret = ( %ret, %{ $res[0] } ) }
    else             { $ret{results} = \@res }

    return \%ret;
}

=head2 should_run

    my $bool = $checker->should_run( \%check, tags => ['banana'] );

Takes a check definition hash and paramters and returns true
if the check should be run.
Used by L</check> to determine which checks to run.

Supported parameters:

=over

=item tags

If the tags for the check match any of the tags passed in, the check is run.
If no tags are passed in, all checks will be run.

If the C<invocant> C<can('tags')> and there are no tags in the
L</full hashref of params> then the return value of that method is used.

If a check has no tags defined, will use the default tags defined
when the object was created.

=back

=cut

sub should_run {
    my ( $self, $check, %params ) = @_;

    if ( my @want_tags = @{ $params{tags} || [] } ) {
        my %have_tags = do {
            my @t = @{ $check->{tags} || [] };

            @t = $check->{invocant}->tags
                if not @t
                and $check->{invocant}
                and $check->{invocant}->can('tags');

            @t = $self->tags unless @t;
            map { $_ => 1 } @t;
        };

        return unless grep { $have_tags{$_} } @want_tags;
    }

    return 1;
}

1;

=head1 DEPENDENCIES

Perl 5.10 or higher.

=head1 CONFIGURATION AND ENVIRONMENT

None

