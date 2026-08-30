#!/bin/sh
# Proxy LocalStack onto 127.0.0.1:4566 so the same provider endpoints
# (http://localhost:4566) work from the host and from this container.
set -eu

socat TCP-LISTEN:4566,fork,reuseaddr,bind=127.0.0.1 TCP:localstack:4566 &

if [ "$#" -eq 0 ]; then
  set -- sleep infinity
fi

exec "$@"
