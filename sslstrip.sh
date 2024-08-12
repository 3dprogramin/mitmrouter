#!/bin/bash

SSL_SPLIT_PORT=8081

# start sslsplit
echo "== starting sslsplit"
sudo sslsplit -D -l connections.log -S logdir/ -k ca.key -c ca.crt https 0.0.0.0 $SSL_SPLIT_PORT