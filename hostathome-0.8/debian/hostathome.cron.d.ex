#
# Regular cron jobs for the hostathome package
#
0 4	* * *	root	[ -x /usr/bin/hostathome_maintenance ] && /usr/bin/hostathome_maintenance
