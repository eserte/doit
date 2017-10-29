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
use Doit::Util qw(copy_stat);

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
    if ($dir eq '/dev/full') {
	# This is just used for testing error on close()
	$tmp_file = '/dev/full';
	open $tmp_fh, '>', $tmp_file
	    or error "Can't write to $tmp_file: $!";
    } else {
	require File::Temp;
	($tmp_fh,$tmp_file) = File::Temp::tempfile(SUFFIX => $suffix, DIR => $dir, UNLINK => 1);
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
	unlink $tmp_file;
	error $@;
    }

    $tmp_fh->close
	or error "Error while closing temporary file $tmp_file: $!";

    if ($same_fs) {
	$doit->rename($tmp_file, $file);
    } else {
	my @dest_stat;
	if (-e $file) {
	    @dest_stat = stat($file)
		or warning "Cannot stat $file: $! (cannot preserve permissions)"; # XXX should this be an error?
	}
	File::Copy::move($tmp_file, $file)
	    or error "Error while renaming $tmp_file to $file: $!";
	if (@dest_stat) {
	    copy_stat [@dest_stat], $file, ownership => 1, mode => 1;
	}
    }
}

1;

__END__