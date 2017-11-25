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
use Doit::Log (); # don't import: clash with Test::More::note

my $tempdir = tempdir('doit_XXXXXXXX', TMPDIR => 1, CLEANUP => 1);
chdir $tempdir or die "Can't chdir to $tempdir: $!";

my $r = Doit->init;
my $has_ipc_run = $r->can_ipc_run;

$r->touch("decl-test");
ok -f "decl-test";
$r->touch("decl-test");
ok -f "decl-test";
$r->utime(undef, undef, "decl-test");
{
    my @s = stat "decl-test"; cmp_ok $s[9], ">", 0;
}
{
    my @s_before = stat "decl-test";
    $r->create_file_if_nonexisting("decl-test");
    my @s_after = stat "decl-test";
    # unfortunately perl has integer timestamps, so this test is
    # unlikely to fail, even if we had a problem:
    is $s_after[9], $s_before[9], 'mtime should not change';
}

$r->create_file_if_nonexisting('decl-test2');
ok -f 'decl-test2', 'create_file_if_nonexisting on a non-existent file';
$r->unlink('decl-test2');

$r->chmod(0755, "decl-test"); # change expected
$r->chmod(0755, "decl-test"); # noop
eval { $r->chmod(0644, "does-not-exist") };
like $@, qr{chmod failed: };
eval { $r->chmod(0644, "does-not-exist-1", "does-not-exist-2") };
like $@, qr{chmod failed on all files: };
eval { $r->chmod(0644, "decl-test", "does-not-exist") };
like $@, qr{\Qchmod failed on some files (1/2): };
$r->chmod(0644, "decl-test"); # noop

$r->chown(-1, -1, "decl-test");
$r->chown($>, undef, "decl-test");
$r->chown($>, -1, "decl-test");
$r->chown($>, undef, "decl-test");
SKIP: {
    my $another_group = (split / /, $))[1];
    skip "No other group available for test (we have only gids: $))", 3 if !defined $another_group;
    $r->chown(undef, $another_group, "decl-test");
    $r->chown(undef, $another_group, "decl-test");

    skip "getgrnam not available on MSWin32", 1 if $^O eq 'MSWin32';
    my $another_groupname = getgrgid($another_group);
    skip "Cannot get groupname for gid $another_group", 1 if !defined $another_groupname;
    $r->chown(undef, $another_groupname, 'decl-test');
}
SKIP: {
    skip "chown never fails on MSWin32", 2 if $^O eq 'MSWin32';
    eval { $r->chown($>, undef, "does-not-exist") };
    like $@, qr{chown failed: };
    eval { $r->chown($>, undef, "does-not-exist-1", "does-not-exist-2") };
    like $@, qr{chown failed on all files: };
    # no test case for "chown failed on some files"
}
SKIP: {
    skip "getpwnam and getgrnam not available on MSWin32", 1 if $^O eq 'MSWin32';
    eval { $r->chown("user-does-not-exist", undef, "decl-test") };
    like $@, qr{\QUser 'user-does-not-exist' does not exist };
    eval { $r->chown(undef, "group-does-not-exist", "decl-test") };
    like $@, qr{\QGroup 'group-does-not-exist' does not exist };
 SKIP: {
	my $username = (getpwuid($>))[0];
	skip "Cannot get username for uid $>", 1 if !defined $username;
	$r->chown($username, undef, "decl-test");
    }
}

$r->rename("decl-test", "decl-test3");
$r->move("decl-test3", "decl-test2");
$r->rename("decl-test2", "decl-test");
$r->copy("decl-test", "decl-copy");
ok -e "decl-copy"
    or diag qx(ls -al);
$r->copy("decl-test", "decl-copy"); # no action
$r->unlink("decl-copy");
TODO: {
    todo_skip "symlinks not working on Windows", 11
	if $^O eq 'MSWin32';

    $r->symlink("tmp/decl-test", "decl-test-symlink");
    ok -l "decl-test-symlink", 'symlink created';
    is readlink("decl-test-symlink"), "tmp/decl-test", 'symlink points to expected destination';
    $r->symlink("tmp/decl-test", "decl-test-symlink");
    ok -l "decl-test-symlink", 'symlink still exists';
    is readlink("decl-test-symlink"), "tmp/decl-test", 'symlink did not change expected destination';
    $r->unlink("decl-test-symlink");
    ok ! -e "decl-test-symlink", 'symlink was removed';

    $r->ln_nsf("tmp/decl-test", "decl-test-symlink2");
    ok -l "decl-test-symlink2", 'symlink created with ln -nsf';
    is readlink("decl-test-symlink2"), "tmp/decl-test", 'symlink points to expected destination';
    $r->ln_nsf("tmp/decl-test", "decl-test-symlink2");
    ok -l "decl-test-symlink2", 'symlink still exists (ln -nsf)';
    is readlink("decl-test-symlink2"), "tmp/decl-test", 'symlink did not change expected destination';
    $r->unlink("decl-test-symlink2");
    ok ! -e "decl-test-symlink2", 'symlink was removed';

    $r->mkdir("dir-for-ln-nsf-test");
    ok -d "dir-for-ln-nsf-test";
    eval { $r->ln_nsf("tmp/decl-test", "dir-for-ln-nsf-test") };
    like $@, qr{"dir-for-ln-nsf-test" already exists as a directory};
    ok -d "dir-for-ln-nsf-test", 'directory still exists after failed ln -nsf';
}
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
$r->system($^X, '-le', 'print q{hello}');
$r->system($^X, '-le', 'print "hello"');
if ($has_ipc_run) {
    $r->run([$^X, '-le', 'print qq{hello}']);
}
if ($^O ne 'MSWin32') { # date is interactive on Windows
    $r->system("date");
    if ($has_ipc_run) {
	$r->run(["date"]);
    }
}
{
    my @hostname = ('hostname');
    if ($^O ne 'MSWin32') {
	push @hostname, '-f';
    }
    $r->system(@hostname);
    if ($has_ipc_run) {
	$r->run([@hostname]);
    }
}
if ($has_ipc_run) {
    $r->cond_run(cmd => [$^X, '-le', 'print q(unconditional cond_run)']);
    $r->cond_run(if => sub { 1 }, cmd => [$^X, '-le', 'print q(always true)']);
    $r->cond_run(if => sub { 0 }, cmd => [$^X, '-le', 'print q(never true, should never happen!!!)']);
    $r->cond_run(if => sub { rand(1) < 0.5 }, cmd => [$^X, '-le', 'print q(yes)']);
}

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

chdir '/'; # for File::Temp

__END__
