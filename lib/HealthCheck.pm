package HealthCheck;

# ABSTRACT: A health check for your code
# VERSION: 0.01

use 5.010;
use strict;
use warnings;

sub new {}

sub register {}

sub results {}

1;
__END__

=head1 NAME

HealthCheck - Health Check Runner

=head1 SYNOPSIS

    my %result = %{ HealthCheck->new(
        id     => 'my-health-check',
        label  => "My Health Check",
        checks => [ sub { return { status => 'OK' } } ],
    )->check };

=head1 DESCRIPTION

Allows you to create callbacks that check the health of your application
and return a status result.

Results returned by these checks should correspond to the GSG
L<https://support.grantstreet.com/wiki/display/AC/Health+Check+Standard|Health Check Standard>.

=head1 ATTRIBUTES

=head2 id

=head2 label

=head2 checks

=head1 METHODS

=head2 new

=head2 register

=head2 check

=head1 DEPENDENCIES

Perl 5.10 or higher.

=head1 CONFIGURATION AND ENVIRONMENT

None

