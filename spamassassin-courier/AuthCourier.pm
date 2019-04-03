#    Copyright (C) 2003  Corporation of Balclutha.  All rights reserved.
#
#    Visit us at http://www.balclutha.org for all of your open source
#    software development and support requirements and hosted solutions.
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
package Mail::SpamAssassin::AuthCourier;

$VERSION=1.0.1;

#
# A mechanism which uses the Courier MTA's authdaemond server to
# determine mail account information.  Courier is found at http://courier-mta.org
#
# This module automagically overrides the builtin getpwnam and getpwuid
# functions.
#
use Exporter;
use IO::Socket::UNIX;


@ISA = qw(Exporter);
@EXPORT = qw( getpwnam getpwuid );

#
# ensure overriding for our own internal usage as well ...
#
use subs qw( getpwnam getpwuid );

#
# For some frustrating reason, the socket seems to be unusable unless set each time.
# Please contact us if you have the solution to this enhancement.
#

BEGIN {
    # $socket = IO::Socket::UNIX->new('/usr/lib/courier/var/authdaemon/socket');
}

END {
    $socket->close if $socket;
}

sub getpwnam {
    my $name = shift;
    my $socket = IO::Socket::UNIX->new('/usr/lib/courier/var/authdaemon/socket');
         $socket = IO::Socket::UNIX->new('/var/run/courier/authdaemon/socket') unless $socket;
         $socket = IO::Socket::UNIX->new('/run/authdaemon/socket') unless $socket;
         die "authdaemond socket error: $!\n" unless $socket;

    print $socket "PRE . login $name\n";

    my %results = ();
    my ($k, $v);
    while (<$socket>) {
	($k,$v) = split '=', $_, 2;
	chomp $v if $v;
	$results{$k} = $v;
    }

    $socket->close if $socket;

    # some auth mechanisms don't return UID - these must be fetched from /etc/passwd or
    # it's moral equivalent until Sam patches these as per my request...
    my $uid = $results{'UID'} || CORE::getpwnam($name); 

    # the same seems to be true for the GID
    my $gid = $results{'GID'} || CORE::getgrnam($name);

    # stop some naf 'uninitialized' errors ...
    return wantarray ? ('','','','','','','') : undef unless $uid; # uid 0 = root !!!

    return wantarray ? ( $results{'USERNAME'}, 
			 $results{'PASSWD'},
			 int($uid),
			 int($gid),
			 $results{'QUOTA'},
			 $results{'COMMENT'},
			 $results{'GCOS'},
			 $results{'HOME'},
			 '/bin/bash') : $uid;
}

sub getpwuid {
    return (getpwnam($_[0]))[2];
}


1;


__END__

=head1 SYNOPSIS

  use Mail::SpamAssassin::AuthCourier;


=head1 DESCRIPTION

  Overrides the builtin functions getpwnam, and getpwuid to return 
  information as per the Courier Mail (http://courier-mta.org) 
  authdaemond process rather than from the /etc/passwd file (or it's
  moral equivalent).

  All of the magick happens courtesy of the Exporter module.  If you 
  need the old functions, these are still available via the CORE module.


=head1 INSTALLATION

  Copy this file into the Mail/SpamAssassin directory on your @INC path
  and edit spamd as per the SYNOPSIS.


=head1 AUTHOR

Alan Milligan <alan\x40balclutha.org> ("\x40" is "@" of course)

=cut
