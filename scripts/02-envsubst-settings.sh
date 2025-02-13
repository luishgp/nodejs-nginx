#!/bin/sh

# Replace ENV vars in nginx configuration files
tmpfile=$(mktemp)
cat /etc/nginx/nginx.conf | envsubst "$(env | cut -d= -f1 | sed -e 's/^/$/')" | tee "$tmpfile" > /dev/null
mv "$tmpfile" /etc/nginx/nginx.conf
