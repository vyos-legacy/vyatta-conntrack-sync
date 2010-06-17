cfgdir            = $(datadir)/vyatta-cfg/templates
opdir		  = $(datadir)/vyatta-op/templates
share_perl5dir	  = $(datarootdir)/perl5/Vyatta
bin_sudo_usersdir = $(bindir)/sudo-users
curverdir         = $(sysconfdir)/config-migrate/current
etc_initdir = /etc/init.d/

curver_DATA = cfg-version/conntrack-sync@1

etc_init_SCRIPTS = scripts/vyatta-cluster-conntracksync

sbin_SCRIPTS    = scripts/vyatta-conntrack-sync.pl
sbin_SCRIPTS   += scripts/vyatta-vrrp-conntracksync.sh

bin_sudo_users_SCRIPTS   = scripts/vyatta-op-conntrack-sync.pl
bin_sudo_users_SCRIPTS  += scripts/vyatta-show-ctsync-caches.pl

share_perl5_DATA  = lib/Vyatta/ConntrackSync.pm

cpiop = find  . ! -regex '\(.*~\|.*\.bak\|.*\.swp\|.*\#.*\#\)' -print0 | \
  cpio -0pd

install-exec-hook:
	mkdir -p $(DESTDIR)$(cfgdir)
	cd templates-cfg; $(cpiop) $(DESTDIR)$(cfgdir)
	mkdir -p $(DESTDIR)$(opdir)
	cd templates-op; $(cpiop) $(DESTDIR)$(opdir)
