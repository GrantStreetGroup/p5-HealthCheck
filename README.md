# NAME

HealthCheck - A health check for your code

# VERSION

version v1.9.0

# SYNOPSIS

    use HealthCheck;

    # a check can return a hashref containing anything at all,
    # however some values are special.
    # See the HealthCheck Standard for details.
    sub my_check {
        return {
            anything => "at all",
            id       => "my_check",
            status   => 'WARNING',
        };
    }

    my $checker = HealthCheck->new(
        id      => 'main_checker',
        label   => 'Main Health Check',
        runbook => 'https://grantstreetgroup.github.io/HealthCheck.html',
        tags    => [qw( fast cheap )],
        checks  => [
            sub { return { id => 'coderef', status => 'OK' } },
            'my_check',          # Name of a method on caller
        ],
    );

    my $other_checker = HealthCheck->new(
        id      => 'my_health_check',
        label   => "My Health Check",
        runbook => 'https://grantstreetgroup.github.io/HealthCheck.html',
        tags    => [qw( cheap easy )],
        other   => "Other details to pass to the check call",
    )->register(
        'My::Checker',       # Name of a loaded class that ->can("check")
        My::Checker->new,    # Object that ->can("check")
    );

    # It's possible to add ids, labels, and tags to your checks
    # and they will be copied to the Result.
    $other_checker->register( My::Checker->new(
        id      => 'my_checker',
        label   => 'My Checker',
        runbook => 'https://grantstreetgroup.github.io/HealthCheck.html',
        tags    => [qw( cheap copied_to_the_result )],
    ) );

    # You can add HealthCheck instances as checks
    # You could add a check to itself to create an infinite loop of checks.
    $checker->register( $other_checker );

    # A hashref of the check config
    # This whole hashref is passed as an argument
    # to My::Checker->another_check
    $checker->register( {
        invocant    => 'My::Checker',      # to call the "check" on
        check       => 'another_check',    # name of the check method
        runbook     => 'https://grantstreetgroup.github.io/HealthCheck.html',
        tags        => [qw( fast easy )],
        more_params => 'anything',
    } );

    my @tags = $checker->tags;    # returns fast, cheap

    my %result = %{ $checker->check( tags => ['cheap'] ) };
       # OR run the opposite checks
       %result = %{ $checker->check( tags => ['!cheap'] ) };

    # A checker class or object just needs to have either
    # a check method, which is used by default,
    # or another method as specified in a hash config.
    package My::Checker;

    # Optionally subclass HealthCheck::Diagnostic
    use parent 'HealthCheck::Diagnostic';

    # and provide a 'run' method, the Diagnostic base class will
    # pass your results through the 'summarize' helper that
    # will add warnings about invalid values as well as
    # summarizing multiple results.
    sub run {
        return {
            id     => ( ref $_[0] ? "object_method" : "class_method" ),
            status => "WARNING",
        };
    }

    # Any checks *must* return a valid "Health Check Result" hashref.

    # You can add your own check that doesn't call 'summarize'
    # or, overload the 'check' helper in the parent class.
    sub another_check {
        my ($self, %params) = @_;
        return {
            id      => 'another_check',
            label   => 'A Super custom check',
            runbook => 'https://grantstreetgroup.github.io/HealthCheck.html',
            status  => ( $params{more_params} eq 'fine' ? "OK" : "CRITICAL" ),
        };
    }

`%result` will be from the subset of checks run due to the tags.

    $checker->check(tags => ['cheap']);

    id      => "main_checker",
    label   => "Main Health Check",
    runbook => 'https://grantstreetgroup.github.io/HealthCheck.html',
    tags    => [ "fast", "cheap" ],
    status  => "WARNING",
    results => [
        {   id     => "coderef",
            status => "OK",
            tags   => [ "fast", "cheap" ]  # inherited
        },
        {   anything => "at all",
            id       => "my_check",
            status   => "WARNING",
            tags     => [ "fast", "cheap" ] # inherited
        },
        {   id      => "my_health_check",
            label   => "My Health Check",
            tags    => [ "cheap", "easy" ],
            status  => "WARNING",
            results => [
                {   id     => "class_method",
                    tags   => [ "cheap", "easy" ],
                    status => "WARNING",
                },
                {   id     => "object_method",
                    tags   => [ "cheap", "easy" ],
                    status => "WARNING",
                },
                {   id     => "object_method_1",
                    label  => "My Checker",
                    tags   => [ "cheap", "copied_to_the_result" ],
                    status => "WARNING",
                }
            ],
        }
    ],

There is also runtime support,
which can be enabled by adding a truthy `runtime` param to the `check`.

    $checker->check( tags => [ 'easy', '!fast' ], runtime => 1 );

    id      => "my_health_check",
    label   => "My Health Check",
    runtime => "0.000",
    runbook => 'https://grantstreetgroup.github.io/HealthCheck.html',
    tags    => [ "cheap", "easy" ],
    status  => "WARNING",
    results => [
        {   id      => "class_method",
            runtime => "0.000",
            tags    => [ "cheap", "easy" ],
            status  => "WARNING",
        },
        {   id      => "object_method",
            runtime => "0.000",
            tags    => [ "cheap", "easy" ],
            status  => "WARNING",
        }
    ],

# DESCRIPTION

Allows you to create callbacks that check the health of your application
and return a status result.

There are several things this is trying to enable:

- A fast HTTP endpoint that can be used to verify that a web app can
serve traffic.
To this end, it may be useful to use the runtime support option,
available in [HealthChecks::Diagnostic](https://metacpan.org/pod/HealthChecks%3A%3ADiagnostic).
- A more complete check that verifies all the things work after a deployment.
- The ability for a script, such as a cronjob, to verify that it's dependencies
are available before starting work.
- Different sorts of monitoring checks that are defined in your codebase.

Results returned by these checks should correspond to the GSG
[Health Check Standard](https://grantstreetgroup.github.io/HealthCheck.html).

You may want to use [HealthCheck::Diagnostic](https://metacpan.org/pod/HealthCheck%3A%3ADiagnostic) to simplify writing your
check slightly.

# METHODS

## new

    my $checker = HealthCheck->new( id => 'my_checker' );

### ATTRIBUTES

- checks

    An arrayref that is passed to ["register"](#register) to initialize checks.

- tags

    An arrayref used as the default set of tags for any checks that don't
    override them.

Any other parameters are included in the "Result" hashref returned.

Some recommended things to include are:

- id

    The unique id for this check.

- label

    A human readable name for this check.

- runbook

    A runbook link to help troubleshooting if the status is not OK.

## register

    $checker->register({
        invocant => $class_or_object,
        check    => $method_on_invocant_or_coderef,
        more     => "any other params are passed to the check",
    });

Takes a list or arrayref of check definitions to be added to the object.

Each registered check must return a valid GSG Health Check response,
either as a hashref or an even-sized list.
See the GSG Health Check Standard (linked in ["DESCRIPTION"](#description))
for the fields that checks should return.

Rather than having to always pass in the full hashref definition,
several common cases are detected and used to fill out the check.

- coderef

    If passed a coderef, this will be called as the `check` without an `invocant`.

- object

    If a blessed object is passed in
    and it has a `check` method, use that for the `check`,
    otherwise throw an exception.

- string

    If a string is passed in,
    check if it is the name of a loaded class that has a `check` method,
    and if so use it as the `invocant` with the method as the `check`.
    Otherwise if our [caller](https://metacpan.org/pod/caller) has a method with this name,
    the [caller](https://metacpan.org/pod/caller) becomes the `invocant` and this becomes the `check`,
    otherwise throws an exception.

- full hashref of params

    The full hashref can consist of a `check` key that the above heuristics
    are applied,
    or include an `invocant` key that is used as either
    an `object` or `class name`.
    With the `invocant` specified, the now optional `check` key
    defaults to "check" and is used as the method to call on `invocant`.

    All attributes other than `invocant` and `check` are passed to the check.

## check

    my %results = %{ $checker->check(%params) }

Calls all of the registered checks and returns a hashref of the results of
processing the checks passed through ["summarize" in HealthCheck::Diagnostic](https://metacpan.org/pod/HealthCheck%3A%3ADiagnostic#summarize).
Passes the ["full hashref of params"](#full-hashref-of-params) as an even-sized list to the check,
without the `invocant` or `check` keys.
This hashref is shallow merged with and duplicate keys overridden by
the `%params` passed in.

If there is both an `invocant` and `check` in the params,
it the `check` is called as a method on the `invocant`,
otherwise `check` is used as a callback coderef.

If only a single check is registered,
the results from that check are merged with, and will override
the ["ATTRIBUTES"](#attributes) set on the object instead of being put in
a `results` arrayref.

Throws an exception if no checks have been registered.

### run

Main implementation of the checker is here.

Passes `summarize_result => 0` to each registered check
unless overridden to avoid running `summarize` multiple times.
See ["check" in HealthCheck::Diagnostic](https://metacpan.org/pod/HealthCheck%3A%3ADiagnostic#check).

## get\_registered\_tags

Read-only accessor that returns the list of 'top-level' tags registered with
this object. Sub-check tags are not included - only those which will result in
checks being run when passed to ["check"](#check) on the given object.

# INTERNALS

These methods may be useful for subclassing,
but are not intended for general use.

## should\_run

    my $bool = $checker->should_run( \%check, tags => ['apple', '!banana'] );

Takes a check definition hash and paramters and returns true
if the check should be run.
Used by ["check"](#check) to determine which checks to run.

Supported parameters:

- tags

    Tags can be either "positive" or "negative". A negative tag is indicated by a
    leading `!`.
    A check is run if its tags match any of the passed in positive tags and none
    of the negative ones.
    If no tags are passed in, all checks will be run.

    If the `invocant` `can('tags')` and there are no tags in the
    ["full hashref of params"](#full-hashref-of-params) then the return value of that method is used.

    If a check has no tags defined, will use the default tags defined
    when the object was created.

# DEPENDENCIES

Perl 5.10 or higher.

# CONFIGURATION AND ENVIRONMENT

None

# SEE ALSO

[HealthCheck::Diagnostic](https://metacpan.org/pod/HealthCheck%3A%3ADiagnostic)

The GSG
[Health Check Standard](https://grantstreetgroup.github.io/HealthCheck.html).

# AUTHOR

Grant Street Group <developers@grantstreet.com>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2017 - 2024 by Grant Street Group.

This is free software, licensed under:

    The Artistic License 2.0 (GPL Compatible)
