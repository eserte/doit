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

package Doit::Lwp; # Convention: all commands here should be prefixed with 'lwp_'

use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '0.01';

use Doit::Log;

sub new { bless {}, shift }
sub functions { qw(lwp_mirror) }

{
    my $ua; # XXX cache in object?
    sub _get_cached_ua {
	my($self) = @_;
	return $ua if $ua;
	require LWP::UserAgent;
	$ua = LWP::UserAgent->new; # XXX options?
    }
}

sub lwp_mirror {
    my($self, $url, $filename, %opts) = @_;
    if (!defined $url) { error "url is mandatory" }
    if (!defined $filename) { error "filename is mandatory" }
    my $refresh  = delete $opts{refresh} || 'always';
    if ($refresh !~ m{^(always|never)$}) { error "refresh may be 'always' or 'never'" }
    my $debug    = delete $opts{debug}; 
    my $ua       = delete $opts{ua};
    error "Unhandled options: " . join(" ", %opts) if %opts;

    if (-e $filename && $refresh eq 'never') {
	info "$url -> $filename already exists, do not refresh";
	return 0;
    }

    $ua ||= _get_cached_ua;

    if ($self->is_dry_run) {
	info "mirror $url -> $filename (dry-run)";
    } else {
	info "mirror $url -> $filename";
	my $resp = $ua->mirror($url, $filename);
	if ($debug) {
	    info "Response: " . $resp->as_string;
	}
	if ($resp->code == 304) {
	    return 0;
	} elsif (!$resp->is_success) {
	    error "mirroring failed: " . $resp->status_line;
	} elsif ($resp->header('X-Died')) {
	    error "mirroring failed: " . $resp->header('X-Died');
	} else {
	    return 1;
	}
    }
}

1;

__END__
