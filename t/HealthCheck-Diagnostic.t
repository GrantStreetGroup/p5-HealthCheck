use strict;
use warnings;
use Test::More;

use HealthCheck::Diagnostic;

my $nl = $] >= 5.016 ? ".\n" : "\n";

{ note "Object check with no run method defined";
    local $@;
    my $diagnostic = eval { My::HealthCheck::Diagnostic->new };
    ok !$@, "No exception from ->new";

    eval { $diagnostic->check };
    my $at = "at " . __FILE__ . " line " . ( __LINE__ - 1 );
    is $@, qq{My::HealthCheck::Diagnostic does not implement a 'run' method $at$nl},
        "Trying to run a check with no run method results in exception";
}

{ note "Class check with no run method defined";
    local $@;
    eval { My::HealthCheck::Diagnostic->check };
    my $at = "at " . __FILE__ . " line " . ( __LINE__ - 1 );
    is $@, qq{My::HealthCheck::Diagnostic does not implement a 'run' method $at$nl},
        "Trying to run a check with no run method results in exception";
}

my @results;
no warnings 'once';
*My::HealthCheck::Diagnostic::run = sub { @results };
use warnings 'once';

{ note "Results as different types";
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };

    my $warning_is = sub {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        my ($message) = @_;

        my $line = ( caller(0) )[2] - 2;
        my $at = 'at ' . __FILE__ . " line $line";

        my $warning = shift @warnings;
        $warning =~ s/0x[[:xdigit:]]+/0xHEX/g if $warning;
        is $warning, "$message $at$nl";
    };

    @results = ({ label => 'As Class', status => 'WARNING' });
    my $expect = $results[0];

    is_deeply( My::HealthCheck::Diagnostic->check, $expect,
        "Called as a class has expected results from hashref");
    is_deeply( My::HealthCheck::Diagnostic->new->check, $expect,
        "Called as an object has expected results from hashref");

    ok !@warnings, "No warnings generated with hashref results";

    @results = %{ $results[0] };
    is_deeply( My::HealthCheck::Diagnostic->check, $expect,
        "Called as a class has expected results from even-sized-list");
    is_deeply( My::HealthCheck::Diagnostic->new->check, $expect,
        "Called as an object has expected results from even-sized-list");

    ok !@warnings, "No warnings generated with even-sized-list results";

    @results = ( 'broken' );
    $expect = { status => 'UNKNOWN' };
    is_deeply( My::HealthCheck::Diagnostic->check, $expect,
        "Called as a class has expected string result");
    $warning_is->(
        "Invalid return from My::HealthCheck::Diagnostic->run (broken)");
    is_deeply( My::HealthCheck::Diagnostic->new->check, $expect,
        "Called as an object has expected results from string result");
    $warning_is->(
        "Invalid return from My::HealthCheck::Diagnostic->run (broken)");

    ok !@warnings, "No unexpected warnings generated";

    @results = ( [ { status => 'broken' } ] );
    $expect = { status => 'UNKNOWN' };
    is_deeply( My::HealthCheck::Diagnostic->check, $expect,
        "Called as a class has expected arrayref result");
    $warning_is->(
        "Invalid return from My::HealthCheck::Diagnostic->run (ARRAY(0xHEX))");
    is_deeply( My::HealthCheck::Diagnostic->new->check, $expect,
        "Called as an object has expected results from arrayref result");
    $warning_is->(
        "Invalid return from My::HealthCheck::Diagnostic->run (ARRAY(0xHEX))");

    ok !@warnings, "No unexpected warnings generated";
}

{ note "Override 'check'";
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };

    no warnings 'once';
    local *My::HealthCheck::Diagnostic::check = sub { 'invalid' };
    use warnings 'once';

    is_deeply( My::HealthCheck::Diagnostic->check, 'invalid',
        "Called as a class has expected invalid result");
    ok !@warnings, "No validation, no warnings as overridden class method";
    is_deeply( My::HealthCheck::Diagnostic->new->check, 'invalid',
        "Called as an object has expected results from arrayref result");
    ok !@warnings, "No validation, no warnings as overridden instance method";
}

{ note "Set and retrieve tags";
    is_deeply [ My::HealthCheck::Diagnostic->new->tags ], [],
        "No tags set, no tags returned";

    is_deeply [
        My::HealthCheck::Diagnostic->new( tags => [qw(foo bar)] )->tags ],
        [qw( foo bar )], "Returns the tags passed in.";

    is_deeply [ My::HealthCheck::Diagnostic->tags ], [],
        "Class method 'tags' has no tags, but also no exception";
}

{ note "Summarize validates result status";
    my @tests = (
        {
            have => {
                id      => 'false',
                results => [
                    { id => 'not_exists' },
                    { id => 'undef', status => undef },
                    { id => 'empty_string', status => '' },
                ]
            },
            expect => {
                'id'      => 'false',
                'status'  => 'UNKNOWN',
                'results' => [
                    { 'id' => 'not_exists',   'status' => 'UNKNOWN' },
                    { 'id' => 'undef',        'status' => 'UNKNOWN' },
                    { 'id' => 'empty_string', 'status' => 'UNKNOWN' }
                ],
            },
            warnings => [
                "Result false-not_exists does not have a status",
                "Result false-undef has undefined status",
                "Result false-empty_string has invalid status ''",
                "Result false does not have a status",
            ],
        },
        {
            # The extra empty results keep it from combining results
            # so we can see what it actually does
            have => {
                id        => 'by_number',
                'results' => [ {
                        id      => 'ok',
                        results => [ { id => 'zero', status => 0 }, {} ]
                    },
                    {
                        id      => 'warning',
                        results => [ { id => 'one', status => 1 }, {} ]
                    },
                    {
                        id      => 'critical',
                        results => [ { id => 'two', status => 2 }, {} ]
                    },
                    {
                        id      => 'unknown',
                        results => [ { id => 'three', status => 3 }, {} ]
                    },
                ]
            },
            expect => {
                id      => 'by_number',
                status  => 'CRITICAL',
                results => [ {
                        'id'      => 'ok',
                        'status'  => 'OK',
                        'results' => [
                            { 'id'     => 'zero', 'status' => 0 },
                            { 'status' => 'UNKNOWN' }
                        ],
                    },
                    {
                        'id'      => 'warning',
                        'status'  => 'WARNING',
                        'results' => [
                            { 'id'     => 'one', 'status' => 1 },
                            { 'status' => 'UNKNOWN' }
                        ],
                    },
                    {
                        'id'      => 'critical',
                        'status'  => 'CRITICAL',
                        'results' => [
                            { 'id'     => 'two', 'status' => 2 },
                            { 'status' => 'UNKNOWN' }
                        ],
                    },
                    {
                        'id'      => 'unknown',
                        'status'  => 'UNKNOWN',
                        'results' => [
                            { 'id'     => 'three', 'status' => 3 },
                            { 'status' => 'UNKNOWN' }
                        ],
                    },
                ],
            },
            warnings => [
                "Result by_number-ok-zero has invalid status '0'",
                "Result by_number-ok-1 does not have a status",
                "Result by_number-warning-one has invalid status '1'",
                "Result by_number-warning-1 does not have a status",
                "Result by_number-critical-two has invalid status '2'",
                "Result by_number-critical-1 does not have a status",
                "Result by_number-unknown-three has invalid status '3'",
                "Result by_number-unknown-1 does not have a status",
                "Result by_number-unknown does not have a status",
            ],
        },
        {
            have => {
                id      => 'invalid',
                results => [
                    { id => 'four',  status => 4 },
                    { id => 'other', status => 'OTHER' },
                ]
            },
            expect => {
                'id'      => 'invalid',
                'status'  => 'UNKNOWN',
                'results' => [
                    { 'id' => 'four',  'status' => 4 },
                    { 'id' => 'other', 'status' => 'OTHER' }
                ],
            },
            warnings => [
                "Result invalid-four has invalid status '4'",
                "Result invalid-other has invalid status 'OTHER'",
                "Result invalid does not have a status",
            ],
        },
        {
            have => {
                id     => 'by_index',
                results => [
                    { status => '00' },
                    { status => '11' },
                    { status => '22' },
                    { status => '33' },
                ], },
            expect => {
                'id'     => 'by_index',
                'status' => 'UNKNOWN',
                'results' => [
                    { 'status' => '00' },
                    { 'status' => '11' },
                    { 'status' => '22' },
                    { 'status' => '33' }
                ],
            },
            warnings => [
                "Result by_index-0 has invalid status '00'",
                "Result by_index-1 has invalid status '11'",
                "Result by_index-2 has invalid status '22'",
                "Result by_index-3 has invalid status '33'",
                "Result by_index does not have a status",
            ],
        },
    );

    foreach my $test (@tests) {
        my @warnings;
        my $name = $test->{have}->{id};

        my $got = do {
            local $SIG{__WARN__} = sub { push @warnings, @_ };
            My::HealthCheck::Diagnostic->summarize( $test->{have} );
        };
        my $at = "at " . __FILE__ . " line " . ( __LINE__ - 2 );

        is_deeply( $got, $test->{expect}, "$name Summarized statuses" )
            || diag explain $got ;

        is_deeply(
            \@warnings,
            [ map {"$_ $at$nl"} @{ $test->{warnings} || [] } ],
            "$name: Warned about incorrect status"
        ) || diag explain \@warnings;
    }
}

{ note "Validate and complain results 'results' key";
    my @warnings;

    my $at = "at " . __FILE__ . " line " . ( __LINE__ + 3 );
    {
        local $SIG{__WARN__} = sub { push @warnings, @_ };
        My::HealthCheck::Diagnostic->summarize( {
            id      => 'fine',
            status  => 'OK',
            results => [
                { status => 'OK' },    # nonexistent is OK
                map +{ status => 'OK', results => $_ },
                    undef,
                    '',
                    'a-string',
                    {},
            ] } );
    }

    s/0x[[:xdigit:]]+/0xHEX/g for @warnings;
    is_deeply( \@warnings, [ map {"Result $_ $at$nl"} 
        "fine-1 has undefined results",
        "fine-2 has invalid results ''",
        "fine-3 has invalid results 'a-string'",
        "fine-4 has invalid results 'HASH(0xHEX)'",
    ], "Got warnings about invalid results") || diag explain \@warnings;
}

{ note "Complain about invalid ID";
    my @warnings;

    my $at = "at " . __FILE__ . " line " . ( __LINE__ + 3 );
    {
        local $SIG{__WARN__} = sub { push @warnings, @_ };
        My::HealthCheck::Diagnostic->summarize({
            id      => 'fine',
            status  => 'OK',
            results => [
                { status => 'OK' }, # nonexistent is OK
                map +{ status => 'OK', id => $_ },
                    'ok',
                    'ok_with_underscores',
                    'ok_with_1_number',
                    'ok_1_with_2_numbers_3_intersperced',
                    '_ok_with_leading_underscore',
                    '1_ok_with_leading_number',
                    undef,
                    '', # empty string
                    'Not_OK_With_Capital_Letters',
                    'Not_ok_with_capitols_like_Washington',
                    'not-ok-with-dashes',
                    'not ok with spaces',
                    'not/ok/with/slashes',
                    'not_ok_"quoted"',
            ]
        } );
    }

    is_deeply( \@warnings, [ map { "Result $_ $at$nl" }
        "fine-7 has an undefined id",
        "fine- has an invalid id ''",
        "fine-Not_OK_With_Capital_Letters has an invalid id 'Not_OK_With_Capital_Letters'",
        "fine-Not_ok_with_capitols_like_Washington has an invalid id 'Not_ok_with_capitols_like_Washington'",
        "fine-not-ok-with-dashes has an invalid id 'not-ok-with-dashes'",
        "fine-not ok with spaces has an invalid id 'not ok with spaces'",
        "fine-not/ok/with/slashes has an invalid id 'not/ok/with/slashes'",
        q{fine-not_ok_"quoted" has an invalid id 'not_ok_"quoted"'},
    ], "Got warnings about invalid IDs" ) || diag explain \@warnings;
}

{ note "Timestamp must be ISO8601";
    my $warnings_ok = sub {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        my ($timestamp, $num_warnings, $message) = @_;
        $message ||= $timestamp;

        my @warnings;
        {
            local $SIG{__WARN__} = sub { push @warnings, @_ };
            My::HealthCheck::Diagnostic->summarize({ status => 'OK', timestamp => $timestamp });
        }
        my $at = "at " . __FILE__ . " line " . ( __LINE__ - 2 );
        my @expect = ("Result 0 has an invalid timestamp '$timestamp' $at$nl")
            x ( $num_warnings || 0 );

        is_deeply \@warnings, \@expect, "$message: Expected warnings";
    };

    my @tests = (
        '2017',                    '0001',
        '201712',                  '2017-12',
        '20171225',                '2017-12-25',
        '2017-12-25 12:34:56',     '2017-12-25T12:34:56',
        '20171225 123456',         '20171225T123456',
        '2017-12-25 12:34:56.001', '2017-12-25T12:34:56.001',
        '20171225 123456.001',     '20171225T123456.001',
    );
    my %ok = map { $_ => 1 } @tests;

    foreach my $ok (@tests) {
        $warnings_ok->( $ok );

        #use Data::Dumper 'Dumper'; warn Dumper \%+;

        $warnings_ok->( "1${ok}", 1 );
        $warnings_ok->( "${ok}1", 1 ) unless $ok =~ /\./;

        foreach my $i ( 0 .. length($ok) - 1 ) {
            my $nok = $ok;
            my $removed = substr( $nok, $i, 1, '' );
            last if $removed eq '.';    # can have shorter ms.
            next if $ok{$nok};
            $warnings_ok->( $nok, 1 );
        }
    }

    foreach my $nok (
        '2017-12-25 12:34:56.', '2017-12-25T12:34:56.',
        '20171225 123456.',     '20171225T123456.',
        '',
        )
    {
        $warnings_ok->( $nok, 1 );
    }
}

done_testing;

package My::HealthCheck::Diagnostic;
use parent 'HealthCheck::Diagnostic';

1;
