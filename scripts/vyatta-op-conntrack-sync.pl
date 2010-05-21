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

use Getopt::Long;
use POSIX;
use XML::Simple;
use Data::Dumper;

use warnings;
use strict;

#
# main
#

my ($action);

GetOptions("action=s"    => \$action
) or usage();

die "Must define action\n" if ! defined $action;

exit 1;

# end of file
