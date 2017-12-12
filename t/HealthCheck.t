use strict;
use warnings;
use Test::More;

use HealthCheck;

subtest "Require instance methods" => sub {
    foreach my $method (qw( register check )) {
        local $@;
        eval { HealthCheck->$method };
        my $at = "at " . __FILE__ . " line " . ( __LINE__ - 1 );
        is $@, "$method cannot be called as a class method $at.\n",
            "> $method";
    }
};

subtest "Require check" => sub {
    {
        local $@;
        eval { HealthCheck->new->register('') };
        my $at = "at " . __FILE__ . " line " . ( __LINE__ - 1 );
        is $@, "check parameter required $at.\n", "> register('')";
    }
    {
        local $@;
        eval { HealthCheck->new->register(0) };
        my $at = "at " . __FILE__ . " line " . ( __LINE__ - 1 );
        is $@, "check parameter required $at.\n", "> register(0)";
    }
    {
        local $@;
        eval { HealthCheck->new->register({}) };
        my $at = "at " . __FILE__ . " line " . ( __LINE__ - 1 );
        is $@, "check parameter required $at.\n", "> register(\\%check)";
    }
};

subtest "Results with no checks" => sub {
    local $@;
    eval { HealthCheck->new->check };
    my $at = "at " . __FILE__ . " line " . ( __LINE__ - 1 );
    is $@, "No registered checks $at.\n",
        "Trying to run a check with no checks results in exception";
};

subtest "Register coderef checks" => sub {
    my $expect = { status => 'OK' };
    my $check = sub {$expect};

    is_deeply( HealthCheck->new( checks => [$check] )->check,
        $expect, "->new(checks => [\$coderef])->check works" );

    is_deeply( HealthCheck->new->register($check)->check,
        $expect, "->new->register(\$coderef)->check works" );
};

subtest "Find default method on object or class" => sub {
    my $expect = { status => 'OK' };

    is_deeply( HealthCheck->new( checks => ['My::Check'] )->check,
        $expect, "Check a class name with a check method" );

    is_deeply( HealthCheck->new( checks => [ My::Check->new ] )->check,
        $expect, "Check an object with a check method" );
};

subtest "Find method on caller" => sub {
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
};

subtest "Don't find method where caller doesn't have it" => sub {
    {
        local $@;
        eval { HealthCheck->new( checks => ['nonexistent'] ) };
        my $at = "at " . __FILE__ . " line " . ( __LINE__ - 1 );
        is $@, "Can't determine what to do with 'nonexistent' $at.\n",
            "Add nonexistent check.";
    }
    {
        local $@;
        eval { My::Check->register_nonexistant };
        my $at = "at " . __FILE__ . " line " . My::Check->rne_line;
        is $@, "Can't determine what to do with 'nonexistent' $at.\n",
            "Add nonexestant check from class.";
    }
    {
        local $@;
        eval { My::Check->new->register_nonexistant };
        my $at = "at " . __FILE__ . " line " . My::Check->rne_line;
        is $@, "Can't determine what to do with 'nonexistent' $at.\n",
            "Add nonexistent check from object.";
    }
    {
        local $@;
        eval {
            HealthCheck->new->register(
                { invocant => 'My::Check', check => 'nonexistent' } );
        };
        my $at = "at " . __FILE__ . " line " . ( __LINE__ - 3 );
        is $@, "'My::Check' cannot 'nonexistent' $at.\n",
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
        is $@, "'$invocant' cannot 'nonexistent' $at.\n",
            "Add nonexestant method on object.";
    }
};

subtest "Calling Conventions" => sub {
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
};

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
