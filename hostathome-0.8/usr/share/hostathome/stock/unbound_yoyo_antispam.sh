#!/bin/sh
#
# Convert the Yoyo.org anti-ad server listing
# into an unbound dns spoof redirection list.

wget -O yoyo_ad_servers "http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&mimetype=plaintext" && \
cat yoyo_ad_servers | grep 127 | awk '{print $2}' | \
while read line ; \
    do \
    echo "local-zone: \"$line\" redirect" ;\
    echo "local-data: \"$line A 127.0.0.1\"" ;\
    done > \
/etc/unbound/unbound_ad_servers

#  then add an include line to your unbound.conf pointing to the full path of
#  the unbound_ad_servers file:
#
#   include: unbound_ad_servers
#


