#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use Test::More;

plan skip_all => "Signals are problematic on Windows" if $^O eq 'MSWin32';
plan skip_all => "no IPC::Run installed (highly recommended, but optional)" if !eval { require IPC::Run; 1 };
plan 'no_plan';

use Doit;

my $r = Doit->init;

$r->run('true');
pass 'no exception';

eval { $r->run('false') };
like $@, qr{^Command exited with exit code 1};
is $@->{exitcode}, 1;

eval { $r->run([$^X, '-e', 'kill TERM => $$']) };
like $@, qr{^Command died with signal 15, without coredump};
is $@->{signalnum}, 15;
is $@->{coredump}, 'without';

eval { $r->run([$^X, '-e', 'kill KILL => $$']) };
like $@, qr{^Command died with signal 9, without coredump};
is $@->{signalnum}, 9;
is $@->{coredump}, 'without';

SKIP: {
    skip "No BSD::Resource available", 1
	if !eval { require BSD::Resource; 1 };
    skip "coredumps disabled", 1
	if BSD::Resource::getrlimit(BSD::Resource::RLIMIT_CORE()) < 4096; # minimum of 4k needed on linux to actually do coredumps
    eval { $r->run([$^X, '-e', 'kill ABRT => $$']) };
    like $@, qr{^Command died with signal 6, with coredump};
    is $@->{signalnum}, 6;
    is $@->{coredump}, 'with';
}

__END__