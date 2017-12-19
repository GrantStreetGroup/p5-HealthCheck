use strict;
use warnings;
use Test::More;

use HealthCheck;

my $nl = $] >= 5.016 ? ".\n" : "\n";

{ note "Require instance methods";
    foreach my $method (qw( register check )) {
        local $@;
        eval { HealthCheck->$method };
        my $at = "at " . __FILE__ . " line " . ( __LINE__ - 1 );
        is $@, "$method cannot be called as a class method $at$nl",
            "> $method";
    }
}

{ note "Require check";
    {
        local $@;
        eval { HealthCheck->new->register('') };
        my $at = "at " . __FILE__ . " line " . ( __LINE__ - 1 );
        is $@, "check parameter required $at$nl", "> register('')";
    }
    {
        local $@;
        eval { HealthCheck->new->register(0) };
        my $at = "at " . __FILE__ . " line " . ( __LINE__ - 1 );
        is $@, "check parameter required $at$nl", "> register(0)";
    }
    {
        local $@;
        eval { HealthCheck->new->register({}) };
        my $at = "at " . __FILE__ . " line " . ( __LINE__ - 1 );
        is $@, "check parameter required $at$nl", "> register(\\%check)";
    }
}

{ note "Results with no checks";
    local $@;
    eval { HealthCheck->new->check };
    my $at = "at " . __FILE__ . " line " . ( __LINE__ - 1 );
    is $@, "No registered checks $at$nl",
        "Trying to run a check with no checks results in exception";
}

{ note "Register coderef checks";
    my $expect = { status => 'OK' };
    my $check = sub {$expect};

    is_deeply( HealthCheck->new( checks => [$check] )->check,
        $expect, "->new(checks => [\$coderef])->check works" );

    is_deeply( HealthCheck->new->register($check)->check,
        $expect, "->new->register(\$coderef)->check works" );
}

{ note "Find default method on object or class";
    my $expect = { status => 'OK' };

    is_deeply( HealthCheck->new( checks => ['My::Check'] )->check,
        $expect, "Check a class name with a check method" );

    is_deeply( HealthCheck->new( checks => [ My::Check->new ] )->check,
        $expect, "Check an object with a check method" );
}

{ note "Find method on caller";
    my $expect = { status => 'OK', label => 'Other' };

    is_deeply(
        HealthCheck->new( checks => ['check'] )->check,
        { status => 'OK', label => 'Local' },
        "Found check method on main"
    );

    is_deeply(
        HealthCheck->new( checks => ['other_check'] )->check,
        { status => 'OK', label => 'Other Local' },
        "Found other_check method on main"
    );

    is_deeply( My::Check->new->register_check->check,
        $expect, "Found other check method on caller object" );

    is_deeply( My::Check->register_check->check,
        $expect, "Found other check method on caller class" );
}

{ note "Don't find method where caller doesn't have it";
    {
        local $@;
        eval { HealthCheck->new( checks => ['nonexistent'] ) };
        my $at = "at " . __FILE__ . " line " . ( __LINE__ - 1 );
        is $@, "Can't determine what to do with 'nonexistent' $at$nl",
            "Add nonexistent check.";
    }
    {
        local $@;
        eval { My::Check->register_nonexistant };
        my $at = "at " . __FILE__ . " line " . My::Check->rne_line;
        is $@, "Can't determine what to do with 'nonexistent' $at$nl",
            "Add nonexestant check from class.";
    }
    {
        local $@;
        eval { My::Check->new->register_nonexistant };
        my $at = "at " . __FILE__ . " line " . My::Check->rne_line;
        is $@, "Can't determine what to do with 'nonexistent' $at$nl",
            "Add nonexistent check from object.";
    }
    {
        local $@;
        eval {
            HealthCheck->new->register(
                { invocant => 'My::Check', check => 'nonexistent' } );
        };
        my $at = "at " . __FILE__ . " line " . ( __LINE__ - 3 );
        is $@, "'My::Check' cannot 'nonexistent' $at$nl",
            "Add nonexestant method on class.";
    }
    {
        local $@;
        my $invocant = My::Check->new;
        eval {
            HealthCheck->new->register(
                { invocant => $invocant, check => 'nonexistent' } );
        };
        my $at = "at " . __FILE__ . " line " . ( __LINE__ - 3 );
        is $@, "'$invocant' cannot 'nonexistent' $at$nl",
            "Add nonexestant method on object.";
    }
}

{ note "Results as even-sized-list or hashref";
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };

    is_deeply(
        HealthCheck->new( checks => [
            sub { +{ id => 'hashref', status => 'OK' } },
            { invocant => 'My::Check', check => sub { 'broken' } },
            sub { id => 'even_size_list', status => 'OK' },
            sub { [ { status => 'broken' } ] },
        ] )->check,
        {
            'results' => [
                { 'id' => 'hashref',        'status' => 'OK' },
                { 'id' => 'even_size_list', 'status' => 'OK' }
            ],
        },
        "Results as expected"
    );
    my $at = "at " . __FILE__ . " line " . ( __LINE__ - 9 );

    s/0x[[:xdigit:]]+/0xHEX/g for @warnings;

    is_deeply \@warnings, [
         "Invalid return from My::Check->CODE(0xHEX) (broken) $at$nl",
         "Invalid return from CODE(0xHEX) (ARRAY(0xHEX)) $at$nl",
    ], "Expected warnings";
}

{ note "Calling Conventions";
    {
        my @args;
        my %check = (
            check => sub { @args = @_; status => 'OK' },
            label => "CodeRef Label",
        );
        HealthCheck->new->register( \%check )->check;

        delete @check{qw( invocant check )};

        is_deeply(
            \@args,
            [ %check ],
            "Without an invocant, called as a function"
        );
    }
    {
        my @args;
        my %check = (
            invocant => 'My::Check',
            check    => sub { @args = @_; status => 'OK' },
            label    => "Method Label",
        );
        HealthCheck->new->register( \%check )->check;

        delete @check{qw( invocant check )};
        is_deeply(
            \@args,
            [ 'My::Check', %check ],
            "With an invocant, called as a method"
        );
    }
    {
        my @args;
        my %check = (
            check => sub { @args = @_; status => 'OK' },
            label => "CodeRef Label",
        );
        HealthCheck->new->register( \%check )->check( custom => 'params' );

        delete @check{qw( invocant check )};

        is_deeply(
            \@args,
            [ %check, custom => 'params' ],
            "Params passed to check merge with check definition"
        );
    }
    {
        my @args;
        my %check = (
            check => sub { @args = @_; status => 'OK' },
            label => "CodeRef Label",
        );
        HealthCheck->new->register( \%check )->check( label => 'Check' );

        delete @check{qw( invocant check )};

        is_deeply(
            \@args,
            [ %check, label => 'Check' ],
            "Params passed to check override check definition"
        );
    }
}

{ note "Set and retrieve tags";
    is_deeply [HealthCheck->new->tags], [],
        "No tags set, no tags returned";

    is_deeply [ HealthCheck->new( tags => [qw(foo bar)] )->tags ],
        [qw( foo bar )],
        "Returns the tags passed in.";

}

done_testing;

sub check       { +{ status => 'OK', label => 'Local' } }
sub other_check { +{ status => 'OK', label => 'Other Local' } }

package My::Check;

sub new { bless {}, $_[0] }
sub check       { +{ status => 'OK' } }
sub other_check { +{ status => 'OK', label => 'Other' } }

sub register_check       { HealthCheck->new->register('other_check') }
sub register_nonexistant { HealthCheck->new->register('nonexistent') }
sub rne_line { __LINE__ - 1 }
