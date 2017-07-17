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

package Doit::Ssl; # Convention: all commands here should be prefixed with 'ssl_'

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use File::Basename 'basename';
use IPC::Run 'run';

use Doit::Log;

sub new { bless {}, shift }
sub functions { qw(ssl_install_ca_certificate) }
sub add_component { qw(extcmd) }

sub can_openssl {
    require Doit::Extcmd;
    Doit::Extcmd::is_in_path('openssl') ? 1 : 0;
}

sub ssl_install_ca_certificate {
    my($self, %args) = @_;
    my $ca_file = delete $args{ca_file} || error "Please specify ca_file";
    error "Unhandled options: " . join(" ", %args) if %args;

    if (!can_openssl) {
	error "openssl is not available";
    }

    my $fingerprint;
    {
	my @cmd = (qw(openssl x509 -noout -fingerprint -in), $ca_file);
	run([@cmd], '>', \$fingerprint)
	    or error "Running '@cmd' failed";
    }

    my $cert_file = '/etc/ssl/certs/ca-certificates.crt'; # XXX what about non-Debians?
    if (open my $fh, '<', $cert_file) {
	my $buf;
	while(<$fh>) {
	    if (/BEGIN CERTIFICATE/) {
		$buf = $_;
	    } else {
		$buf .= $_;
		if (/END CERTIFICATE/) {
		    my $check_fingerprint;
		    my @cmd = qw(openssl x509 -noout -fingerprint);
		    run([@cmd], '<', \$buf, '>', \$check_fingerprint)
			or error "Running '@cmd' failed";
		    if ($fingerprint eq $check_fingerprint) {
			# Found certificate, nothing to do
			return 0;
		    }
		}
	    }
	}
    } else {
	warning "No file '$cert_file' found --- is this the first certificate on this system?";
    }

    my $dest_file = basename $ca_file;
    if ($dest_file !~ m{\.crt$}) {
	$dest_file .= '.crt';
    }
    my $sudo = $< == 0 ? $self: $self->do_sudo; # unprivileged? -> upgrade to sudo
    $sudo->copy($ca_file, "/usr/local/share/ca-certificates/$dest_file");
    if (!$sudo->is_dry_run) {
	$sudo->system('update-ca-certificates');
    } else {
	info "Would need to run update-ca-certificates";
    }

    return 1;
}

1;

__END__