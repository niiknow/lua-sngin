#!/bin/bash

# CMD="$RESTY_HOME/nginx/sbin/nginx -t && $RESTY_HOME/nginx/sbin/nginx -s reload;"

# Set NGINX directory
# tar command already has the leading /
dir="usr/local/openresty/nginx"

# Get initial checksum values
checksum_initial=$(tar --strip-components=2 -C / -cf - $dir | md5sum | awk '{print $1}')
checksum_now=$checksum_initial

# Start nginx
/usr/local/openresty/nginx/sbin/nginx

# Daemon that checks the md5 sum of the directory
# ff the sums are different ( a file changed / added / deleted)
# the nginx configuration is tested and reloaded on success
while true
do
    checksum_now=$(tar --strip-components=2 -C / -cf - $dir | md5sum | awk '{print $1}')

    if [ $checksum_initial != $checksum_now ]; then
        echo '[ NGINX ] A configuration file changed. Reloading...'
        $RESTY_HOME/nginx/sbin/nginx -t && $RESTY_HOME/nginx/sbin/nginx -s reload;
    fi

    checksum_initial=$checksum_now

    sleep 2
done