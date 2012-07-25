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

my $DAEMON         = '/usr/sbin/conntrackd';
my $INIT_SCRIPT    = '/etc/init.d/conntrackd';
my $CLUSTER_UPDATE = '/opt/vyatta/sbin/vyatta-update-cluster.pl';
my $VRRP_UPDATE = '/opt/vyatta/sbin/vyatta-keepalived.pl';
my $CONNTRACK_SYNC_ERR = 'conntrack-sync error:';
my $FAILOVER_STATE_FILE = '/var/run/vyatta-conntrackd-failover-state';

sub require_failover_restart {
  my $config = new Vyatta::Config;
  $config->setLevel('service conntrack-sync failover-mechanism');
  return $config->isChanged();
}

sub conntrackd_restart {
  my ($HA, $ORIG_HA) = @_;
  my $stop_orig_HA = 'false';
  if (defined $ORIG_HA) {
    $stop_orig_HA = 'true' if !( $ORIG_HA eq $HA );
  }

  my $err = 0;
  $err = run_cmd("$INIT_SCRIPT restart >&/dev/null");
  return "$CONNTRACK_SYNC_ERR $INIT_SCRIPT failed to start $DAEMON!" if $err != 0;

  # failover mechanism daemon should be indicated
  # that it needs to execute conntrackd actions
  if ( $HA eq 'cluster' ) {

    # if needed; free VRRP from conntrack-sync actions
    if ($stop_orig_HA eq 'true') {
       $err = run_cmd("$VRRP_UPDATE --vrrp-action update-ctsync --ctsync true");
       return "$CONNTRACK_SYNC_ERR error restarting VRRP daemon!" if $err != 0;
       sleep 1; # let the old mechanism settle down before switching to new one
    }

    # remove old transition state
    unlink($FAILOVER_STATE_FILE);

    if (require_failover_restart()) {
      # indicate to clustering that it needs to execute 
      # conntrack-sync actions on state transitions
      $err = run_cmd("$CLUSTER_UPDATE --conntrackd_service='vyatta-cluster-conntracksync'");
      return "$CONNTRACK_SYNC_ERR error restarting clustering!" if $err != 0;
    }
  } elsif ( $HA eq 'vrrp' ) {

    # if needed; free clustering from conntrack-sync actions
    if ($stop_orig_HA eq 'true') {
        $err = run_cmd("$CLUSTER_UPDATE");
        return "$CONNTRACK_SYNC_ERR error restarting clustering!" if $err != 0;
        sleep 1; # let the old mechanism settle down before switching to new one
    }

    # remove old transition state
    unlink($FAILOVER_STATE_FILE);

    if (require_failover_restart()) {
      # indicate to VRRP that it needs to execute
      # conntrack-sync actions on state transitions
      $err = run_cmd("$VRRP_UPDATE --vrrp-action update-ctsync --ctsync true");
      return "$CONNTRACK_SYNC_ERR error restarting VRRP daemon!" if $err != 0;
    }
  } else {
    return "$CONNTRACK_SYNC_ERR undefined HA!";
  }
  
  return;
}

sub conntrackd_stop {
  my ($ORIG_HA) = @_;

  my $err = 0;

  # failover mechanism daemon should be indicated that
  # it NO longer needs to execute conntrackd actions
  if ( $ORIG_HA eq 'cluster' ) {
    $err = run_cmd("$CLUSTER_UPDATE");
    return "$CONNTRACK_SYNC_ERR error restarting clustering!" if $err != 0;
  } elsif ( $ORIG_HA eq 'vrrp' ) {
    $err = run_cmd("$VRRP_UPDATE --vrrp-action update-ctsync --ctsync true");
    return "$CONNTRACK_SYNC_ERR error restarting VRRP daemon!" if $err != 0;
  } else {
    return "$CONNTRACK_SYNC_ERR undefined HA!";
  }
  
  # stop conntrackd daemon
  $err = run_cmd("$INIT_SCRIPT stop >&/dev/null");
  return "$CONNTRACK_SYNC_ERR $INIT_SCRIPT failed to stop $DAEMON!" if $err != 0;
  
  # remove old transition state
  unlink($FAILOVER_STATE_FILE);
  
  return;
}

sub validate_vyatta_conntrackd_config {
  my $err_string = undef;

  # validate interface params
  $err_string = interface_checks();
  return $err_string if defined $err_string;

  # validate failover mechanism params
  $err_string = failover_mechanism_checks();
  return $err_string if defined $err_string;

  # validate that all and <protocols> for expect-sync are mutually exclusive
  $err_string = expect_sync_protocols_checks();
  return $err_string if defined $err_string;

  return $err_string;
}

sub vyatta_enable_conntrackd {

  my $error = undef;
  my $HA = undef;
  my $ORIG_HA = undef;  

  # validate vyatta config
  $error = validate_vyatta_conntrackd_config();
  return ( $error, ) if defined $error;

  # set HA mechanism for conntrack sync start|stop functions
  my @failover_mechanism = ();

  @failover_mechanism =
    get_conntracksync_val( "listNodes", "failover-mechanism" );
  $HA = $failover_mechanism[0];

  @failover_mechanism =
    get_conntracksync_val( "listOrigNodes", "failover-mechanism" );
  $ORIG_HA = $failover_mechanism[0];

  # generate conntrackd config
  my $config = generate_conntrackd_config();
  return ( 'Error generating daemon config file', ) if !defined $config;

  # write to $CONF_FILE
  conntrackd_write_file($config);
  print_dbg_config_output($config);

  # start conntrackd
  $error = conntrackd_restart($HA, $ORIG_HA);
  return ( $error, ) if defined $error;

  return;

}

sub vyatta_disable_conntrackd {

  my $error = undef;
  my $ORIG_HA = undef;
  
  # set HA mechanism for conntrack sync start|stop functions
  my @failover_mechanism = ();

  @failover_mechanism =
    get_conntracksync_val( "listOrigNodes", "failover-mechanism" );
  $ORIG_HA = $failover_mechanism[0];

  $error = conntrackd_stop($ORIG_HA);
  return ( $error, ) if defined $error;

  return;

}

sub cluster_grps {
  my @cluster_grps = 
    get_config_val( 'listOrigPlusComNodes', 'cluster', 'group' );
  print "@cluster_grps\n";
  return;
}

sub vrrp_sync_grps {
  my @sync_grps = get_vrrp_sync_grps();
  print "@sync_grps\n";
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
( $error, $warning ) = cluster_grps() if $action eq 'cluster-grps';
( $error, $warning ) = vrrp_sync_grps() if $action eq 'vrrp-sync-grps';

if ( defined $warning ) {
  print "$warning\n";
}

if ( defined $error ) {
  print "$error\n";
  exit 1;
}

exit 0;

# end of file
