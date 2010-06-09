#!/usr/bin/perl
#
# Module: vyatta-conntrack-sync.pl
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
# Description: Script to configure conntrackd
#
# **** End License ****
#

use Getopt::Long;

use lib '/opt/vyatta/share/perl5';
use Vyatta::ConntrackSync;

use warnings;
use strict;

my $HA    = undef;

my $DAEMON         = '/usr/sbin/conntrackd';
my $INIT_SCRIPT    = '/etc/init.d/conntrackd';
my $CLUSTER_UPDATE = '/opt/vyatta/sbin/vyatta-update-cluster.pl';
my $VRRP_UPDATE = '/opt/vyatta/sbin/vyatta-keepalived.pl';
my $CONNTRACK_SYNC_ERR = 'conntrack-sync error:';

sub conntrackd_restart {
  my $err = 0;
  $err = run_cmd("$INIT_SCRIPT restart >&/dev/null");
  die "$CONNTRACK_SYNC_ERR $INIT_SCRIPT failed to start $DAEMON!" if $err != 0;

  # failover mechanism daemon should be indicated 
  # that it needs to execute conntrackd actions
  if ( $HA eq 'cluster' ) {
    $err = run_cmd("$CLUSTER_UPDATE --conntrackd_service='vyatta-cluster-conntracksync'");
    die "$CONNTRACK_SYNC_ERR error restarting clustering!" if $err != 0;
  } elsif ( $HA eq 'vrrp' ) {
    $err = run_cmd("$VRRP_UPDATE --vrrp-action update --ctsync true");
    die "$CONNTRACK_SYNC_ERR error restarting VRRP daemon!" if $err != 0;
  } else {
    die "$CONNTRACK_SYNC_ERR undefined HA!";
  }
}

sub conntrackd_stop {
  my $err = 0;
  $err = run_cmd("$INIT_SCRIPT stop >&/dev/null");
  die "$CONNTRACK_SYNC_ERR $INIT_SCRIPT failed to stop $DAEMON!" if $err != 0;

  # failover mechanism daemon should be indicated that
  # it NO longer needs to execute conntrackd actions
  if ( $HA eq 'cluster' ) {
    $err = run_cmd("$CLUSTER_UPDATE");
    die "$CONNTRACK_SYNC_ERR error restarting clustering!" if $err != 0;
  } elsif ( $HA eq 'vrrp' ) {
    $err = run_cmd("$VRRP_UPDATE --vrrp-action update --ctsync true");
    die "$CONNTRACK_SYNC_ERR error restarting VRRP daemon!" if $err != 0;
  } else {
    die "$CONNTRACK_SYNC_ERR undefined HA!";
  }
}

sub validate_vyatta_conntrackd_config {
  my $err_string = undef;

  # validate interface params
  $err_string = interface_checks();
  return $err_string if defined $err_string;

  # validate failover mechanism params
  $err_string = failover_mechanism_checks();
  return $err_string if defined $err_string;

  return $err_string;
}

sub vyatta_enable_conntrackd {

  my $error = undef;

  # validate vyatta config
  $error = validate_vyatta_conntrackd_config();
  return ( $error, ) if defined $error;

  # set HA mechanism for conntrack sync start|stop functions
  my @failover_mechanism =
    get_conntracksync_val( "listNodes", "failover-mechanism" );
  $HA = $failover_mechanism[0];

  # generate conntrackd config
  my $config = generate_conntrackd_config();
  return ( 'Error generating daemon config file', ) if !defined $config;

  # write to $CONF_FILE
  conntrackd_write_file($config);
  print_dbg_config_output($config);

  # start conntrackd
  print "Starting conntrack-sync...\n";
  conntrackd_restart();
  return;

}

sub vyatta_disable_conntrackd {

  # set failover mechanism
  my @failover_mechanism =
    get_conntracksync_val( "listOrigNodes", "failover-mechanism" );
  $HA = $failover_mechanism[0];

  print "Stopping conntrack-sync...\n";
  conntrackd_stop();
  return;

}

#
# main
#

my ($action);

GetOptions( "action=s" => \$action, );

die "undefined action" if !defined $action;

my ( $error, $warning );

( $error, $warning ) = vyatta_enable_conntrackd()  if $action eq 'enable';
( $error, $warning ) = vyatta_disable_conntrackd() if $action eq 'disable';

if ( defined $warning ) {
  print "$warning\n";
}

if ( defined $error ) {
  print "$error\n";
  exit 1;
}

exit 0;

# end of file
