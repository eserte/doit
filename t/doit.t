#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use File::Temp 'tempdir';
use Test::More 'no_plan';

use Doit;

my $tempdir = tempdir('doit_XXXXXXXX', TMPDIR => 1, CLEANUP => 1);
chdir $tempdir or die "Can't chdir to $tempdir: $!";

my $r = Doit->init;
$r->touch("decl-test");
ok -f "decl-test";
$r->touch("decl-test");
ok -f "decl-test";
$r->utime(undef, undef, "decl-test");
{
    my @s = stat "decl-test"; cmp_ok $s[9], ">", 0;
}
$r->chmod(0755, "decl-test");
$r->chmod(0755, "decl-test");
$r->chmod(0644, "decl-test");
$r->chmod(0644, "decl-test");
$r->chown($>, undef, "decl-test");
$r->chown($>, undef, "decl-test");
$r->chown(undef, (split / /, $))[1], "decl-test");
$r->chown(undef, (split / /, $))[1], "decl-test");
$r->rename("decl-test", "decl-test2");
$r->rename("decl-test2", "decl-test");
$r->symlink("tmp/decl-test", "decl-test-symlink");
ok -l "decl-test-symlink";
$r->symlink("tmp/decl-test", "decl-test-symlink");
$r->unlink("decl-test-symlink");
ok ! -e "decl-test-symlink";
$r->write_binary("decl-test", "some content\n");
$r->write_binary("decl-test", "some content\n");
$r->write_binary("decl-test", "different content\n");
$r->write_binary("decl-test", "different content\n");
$r->unlink("decl-test");
ok ! -f "decl-test";
ok ! -e "decl-test";
$r->unlink("decl-test");
$r->mkdir("decl-test");
ok -d "decl-test";
$r->mkdir("decl-test");
ok -d "decl-test";
$r->make_path("decl-test", "decl-deep/test");
ok -d "decl-deep/test";
$r->make_path("decl-test", "decl-deep/test");
$r->rmdir("decl-test");
ok ! -d "decl-test";
ok ! -e "decl-test";
$r->rmdir("decl-test");
$r->remove_tree("decl-test", "decl-deep/test");
ok ! -d "decl-deep/test";
$r->remove_tree("decl-test", "decl-deep/test");
$r->system("date");
$r->run(["date"]);
$r->system("hostname", "-f");
$r->run(["hostname", "-f"]);
$r->cond_run(cmd => [qw(echo unconditional cond_run)]);
$r->cond_run(if => sub { 1 }, cmd => [qw(echo always true)]);
$r->cond_run(if => sub { 0 }, cmd => [qw(echo), 'never true, should never happen!!!']);
$r->cond_run(if => sub { rand(1) < 0.5 }, cmd => [qw(echo yes)]);

$r->install_generic_cmd('never_executed', sub { 0 }, sub { die "never executed" });
$r->never_executed();
$r->install_generic_cmd('mytest', sub {
			    my($self, $args) = @_;
			    @$args;
			}, sub {
			    my($self, $args) = @_;
			    warn "args is @$args";
			});
$r->mytest(1);
$r->mytest(0);

__END__
