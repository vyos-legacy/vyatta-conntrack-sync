#!/usr/bin/perl
#
# Module: vyatta-op-conntrack-sync.pl
# 
# **** License ****
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# This code was originally developed by Vyatta, Inc.
# Portions created by Vyatta are Copyright (C) 2010 Vyatta, Inc.
# All Rights Reserved.
# 
# Author: Mohit Mehta
# Date: May 2010
# Description: op-mode script for conntrack-sync feature
# 
# **** End License ****
#

use lib '/opt/vyatta/share/perl5';
use Getopt::Long;
use Vyatta::ConntrackSync;

use warnings;
use strict;

sub is_conntracksync_configured {
  my $conntrack_sync_intf = get_conntracksync_val('returnOrigValue', 'interface');
  return "conntrack-sync not configured" if ! defined $conntrack_sync_intf;
  return;
}

sub ctsync_status {

  my @failover_mechanism =
    get_conntracksync_val( "listOrigNodes", "failover-mechanism" );
  my $ct_sync_intf = get_conntracksync_val( "returnOrigValue", "interface" );
  my $pid = `sudo pgrep conntrackd`;
  chomp $pid;

  my $cluster_grp = undef;
  my $vrrp_sync_grp = undef;
  if ($failover_mechanism[0] eq 'cluster') {
    $cluster_grp = get_conntracksync_val( 
	"returnOrigValue", 
	"failover-mechanism cluster group" );
  } elsif ($failover_mechanism[0] eq 'vrrp') {
    # get VRRP specific info 
    $vrrp_sync_grp = get_conntracksync_val( 
	"returnOrigValue", 
	"failover-mechanism vrrp sync-group" );   
  }
  
  
  print "\nconntrack-sync status\n";
  print   "---------------------\n";
  print "process id         : $pid\n";
  print "sync-interface     : $ct_sync_intf\n";
  print "failover-mechanism : $failover_mechanism[0]";
  print " [group : $cluster_grp]\n" if $failover_mechanism[0] eq 'cluster';
  print " [sync-group : $vrrp_sync_grp]\n" if $failover_mechanism[0] eq 'vrrp';
  print "\n";
  
  return; 
}

#
# main
#

my ($action);

GetOptions( "action=s" => \$action, );

die "undefined action" if !defined $action;

my ( $error, $warning );

( $error, $warning ) = is_conntracksync_configured()  if $action eq 'is_ctsync_set';
( $error, $warning ) = ctsync_status()  if $action eq 'ctsync_status';

if ( defined $warning ) {
  print "$warning\n";
}

if ( defined $error ) {
  print "$error\n";
  exit 1;
}

exit 0;

# end of file
