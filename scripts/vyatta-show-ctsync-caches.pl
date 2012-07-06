#!/usr/bin/perl
#
# Module: vyatta-show-ctsync-caches.pl
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
# Date: June 2010
# Description: 	Script to show conntrack-sync caches
#		This script is based off vyatta-nat-translations.pl
#
# **** End License ****
#

use Getopt::Long;
use XML::Simple;
use Data::Dumper;
use POSIX;
use lib "/opt/vyatta/share/perl5";
use Vyatta::Conntrack::ConntrackUtil;

use warnings;
use strict;

my $CONNTRACKD_BIN='/usr/sbin/conntrackd';
my $CONNTRACKD_CONFIG='/etc/conntrackd/conntrackd.conf';

my $format = "%-30s %-30s %-18s";
my $href; #reference to hash containing protocol-num to name key-value pairs

sub add_xml_root {
    my $xml = shift;

    $xml = "<data>\n" . $xml . '</data>';
    return $xml;
}

sub print_expect_xml {
    my ($data, $cache) = @_;

    my $flow = 0;

    my %flowh;
    $href = Vyatta::Conntrack::ConntrackUtil::process_protocols();
    while (1) {
        last if ! defined $data->{flow}[$flow];
        my $flow_ref = $data->{flow}[$flow];
        my ($src, $dst, $sport, $dport, $proto, $protonum);
        while (1) {
                last if ! defined $flow_ref;
                my $l3_ref    = $flow_ref->{layer3}[0];
                my $l4_ref    = $flow_ref->{layer4}[0];
                my $expected_l3 = $l3_ref->{expected}[0];
                my $expected_l4 = $l4_ref->{expected}[0];
                if (defined $expected_l3) {
                    $src = $expected_l3->{src}[0];
                    $dst = $expected_l3->{dst}[0];
                    if (defined $expected_l4) {
                        $sport = $expected_l4->{sport}[0];
                        $dport = $expected_l4->{dport}[0];
                        $proto = $l4_ref->{protoname};
                        $protonum = $l4_ref->{protonum};
                        if (($proto eq 'unknown') and (defined($protonum))) {
                          $proto = lc(${$href}{$protonum});  
                        }
                        my $mask_ref = $l4_ref->{mask}[0];
                        my $mask_sport = $mask_ref->{sport}[0];
                        if ($mask_sport eq '0') {
                            if ($sport eq '0') {
                                $sport = 'any';
                            }
                        }
                    }
                }
                $flow++;
                $flow_ref = $data->{flow}[$flow];
                my $in_src =  "|$src|"; 
                my $in_dst = "|$dst|"; 
                my $protocol = $proto . ' [' . $protonum . ']';
                $in_src .= ":$sport";
                $in_dst .= ":$dport";
                printf($format, $in_src, $in_dst, $protocol);
                print "\n";
       }
        $flow++;
    }
    return $flow;
}

sub print_xml {
    my ($data, $cache) = @_;

    my $flow = 0;

    my %flowh;
    $href = Vyatta::Conntrack::ConntrackUtil::process_protocols();
    while (1) {
        my $meta = 0;
        last if ! defined $data->{flow}[$flow];
        my $flow_ref = $data->{flow}[$flow];
        my $flow_type = $flow_ref->{type};
        my (%src, %dst, %sport, %dport, %proto, %protonum);
        while (1) {
            my $meta_ref = $flow_ref->{meta}[$meta];
            last if ! defined $meta_ref;
            my $dir = $meta_ref->{direction};
            if ($dir eq 'original' or $dir eq 'reply') {
                my $l3_ref    = $meta_ref->{layer3}[0];
                my $l4_ref    = $meta_ref->{layer4}[0];
                if (defined $l3_ref) {
                    $src{$dir} = $l3_ref->{src}[0];
                    $dst{$dir} = $l3_ref->{dst}[0];
                    if (defined $l4_ref) {
                        $sport{$dir} = $l4_ref->{sport}[0];
                        $dport{$dir} = $l4_ref->{dport}[0];
                        $proto{$dir} = $l4_ref->{protoname};
                        $protonum{$dir} = $l4_ref->{protonum};
                        if (($proto{$dir} eq 'unknown') and (defined($protonum{$dir}))) {
                          $proto{$dir} = lc(${$href}{$protonum{$dir}});  
                        }
                    }
                }
            } elsif ($dir eq 'independent') {
                # might retrieve something here in future
            }
            $meta++;
        }
        my ($proto, $protonum, $in_src, $in_dst, $out_src, $out_dst);
        $proto    = $proto{original};
        $protonum = $protonum{original};
        $in_src   = "|$src{original}|";
        $in_src  .= ":$sport{original}" if defined $sport{original};
        $in_dst   = "|$dst{original}|";
        $in_dst  .= ":$dport{original}" if defined $dport{original};

        # not using these for now
        $out_src  = "|$dst{reply}|";
        $out_src .= ":$dport{reply}" if defined $dport{reply};
        $out_dst  = "|$src{reply}|";
        $out_dst .= ":$sport{reply}" if defined $sport{reply};

        my $protocol = $proto . ' [' . $protonum . ']';
        printf($format, $in_src, $in_dst, $protocol);
        print "\n";
        $flow++;
    }
    return $flow;
}


#
# main
#

my ($cache, $expect, $main);

GetOptions("cache=s"    => \$cache,
           "expect=s"   => \$expect,
           "main=s"     => \$main,
);

if  (! -f $CONNTRACKD_BIN) {
    die "Package [conntrack] not installed";
}

my $xs = XML::Simple->new(ForceArray => 1, KeepRoot => 0);
my ($xml_main, $xml_expect, $data);

printf($format, 'Source', 'Destination', 'Protocol');
print "\n";

if ($cache eq 'internal') {
  if (defined $expect) {
      $xml_expect = `$CONNTRACKD_BIN -C $CONNTRACKD_CONFIG -i exp -x`;
  } elsif (defined $main) {
      $xml_main = `$CONNTRACKD_BIN -C $CONNTRACKD_CONFIG -i -x`;
  } else {
      $xml_main = `$CONNTRACKD_BIN -C $CONNTRACKD_CONFIG -i -x`;
      $xml_expect = `$CONNTRACKD_BIN -C $CONNTRACKD_CONFIG -i exp -x`;
  }
} elsif ($cache eq 'external') {
  if (defined $expect) {
      $xml_expect = `$CONNTRACKD_BIN -C $CONNTRACKD_CONFIG -e exp -x`;
  } elsif (defined $main) {
      $xml_main = `$CONNTRACKD_BIN -C $CONNTRACKD_CONFIG -e -x`;
  } else {
      $xml_main = `$CONNTRACKD_BIN -C $CONNTRACKD_CONFIG -e -x`;
      $xml_expect = `$CONNTRACKD_BIN -C $CONNTRACKD_CONFIG -e exp -x`;
  }
} else {
  die "unknown cache type for conntrackd";
}

if ((defined($xml_main)) && (defined($xml_expect))) {
    printf("\nMain Table Entries:\n\n");
    $xml_main = add_xml_root($xml_main);
    $data = $xs->XMLin($xml_main);
    print_xml($data, $cache);

    printf("\nExpect Table Entries:\n\n");
    $xml_expect = add_xml_root($xml_expect);
    $data = $xs->XMLin($xml_expect);
    print_expect_xml($data, $cache);
}
if (defined ($xml_main)) {
    $xml_main = add_xml_root($xml_main);
    $data = $xs->XMLin($xml_main);
    print_xml($data, $cache);
}
if (defined ($xml_expect)) {
    $xml_expect = add_xml_root($xml_expect);
    $data = $xs->XMLin($xml_expect);
    print_expect_xml($data, $cache);
}

# end of file
