#!/bin/bash

SSL_PORT=8081

# check for arguments, mitmproxy or sslstrip
if [ "$1" != "mitmproxy" ] && [ "$1" != "sslsplit" ] || [ $# != 1 ]; then
    echo "missing required argument"
    echo "$0: <sslstrip/mitmproxy>"
    exit
fi

if [ $1 = "sslsplit" ]; then
    # run sslstrip
    # sslstrip is preferred because it is less likely to be detected, it bypasses SSL pinning, HSTS, etc.
    sudo sslsplit -D -l connections.log -S logdir/ -k ca.key -c ca.crt https 0.0.0.0 $SSL_PORT
else
    # run mitmproxy
    mitmproxy --mode transparent --showhost -p $SSL_PORT -k
fi
