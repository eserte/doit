# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Doit::File;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Doit::Log;
use Doit::Util qw(copy_stat new_scope_cleanup);

sub new { bless {}, shift }
sub functions { qw(file_atomic_write_fh) }

sub file_atomic_write_fh {
    my($doit, $file, $code, %opts) = @_;

    if (!defined $file) {
	error "File parameter is missing";
    }
    if (!defined $code) {
	error "Code parameter is missing";
    } elsif (ref $code ne 'CODE') {
	error "Code parameter should be an anonymous subroutine or subroutine reference";
    }

    require File::Basename;
    require Cwd;
    my $dest_dir = Cwd::realpath(File::Basename::dirname($file));

    my $suffix = delete $opts{suffix} || '.tmp';
    my $dir = delete $opts{dir}; if (!defined $dir) { $dir = $dest_dir }
    error "Unhandled options: " . join(" ", %opts) if %opts;

    my($tmp_fh,$tmp_file);
    my(@cleanup_files, @cleanup_fhs);
    my $tempfile_scope = new_scope_cleanup {
	for my $cleanup_fh (@cleanup_fhs) { # required on Windows, otherwise unlink won't work
	    close $cleanup_fh if fileno($cleanup_fh);
	}
	for my $cleanup_file (@cleanup_files) {
	    unlink $cleanup_file if -e $cleanup_file;
	}
    };
    if ($dir eq '/dev/full') {
	# This is just used for testing error on close()
	$tmp_file = '/dev/full';
	open $tmp_fh, '>', $tmp_file
	    or error "Can't write to $tmp_file: $!";
    } else {
	require File::Temp;
	($tmp_fh,$tmp_file) = File::Temp::tempfile(SUFFIX => $suffix, DIR => $dir, UNLINK => 1);
	push @cleanup_files, $tmp_file;
	push @cleanup_fhs, $tmp_fh;
    }
    my $same_fs = do {
	my $tmp_dev  = (stat($tmp_file))[0];
	my $dest_dev = (stat($dest_dir))[0];
	$tmp_dev == $dest_dev;
    };

    if ($same_fs) {
	if (-e $file) {
	    copy_stat $file, $tmp_file;
	}
    } else {
	require File::Copy; # for move()
    }

    eval { $code->($tmp_fh) };
    if ($@) {
	error $@;
    }

    if ($] < 5.010001) { $! = 0 }
    $tmp_fh->close
	or error "Error while closing temporary file $tmp_file: $!";
    if ($] < 5.010001 && $! != 0) { # at least perl 5.8.8 and 5.8.9 are buggy and do not detect errors at close time --- 5.10.1 is correct
	error "Error while closing temporary file $tmp_file: $!";
    }

    if ($same_fs) {
	$doit->rename($tmp_file, $file);
    } else {
	my @dest_stat;
	if (-e $file) {
	    @dest_stat = stat($file)
		or warning "Cannot stat $file: $! (cannot preserve permissions)"; # XXX should this be an error?
	}
	$doit->move($tmp_file, $file);
	if (@dest_stat) { # In dry-run mode effectively a noop
	    copy_stat [@dest_stat], $file, ownership => 1, mode => 1;
	}
    }
}

1;

__END__
