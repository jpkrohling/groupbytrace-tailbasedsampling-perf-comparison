#!/bin/bash

OTEL_COLLECTOR=134.209.254.47
PROMETHEUS=128.199.56.242

curl ${OTEL_COLLECTOR}:8888/metrics > otelcol-metrics.txt
scp root@${OTEL_COLLECTOR}:/root/otelcol.log otelcol.log
scp root@${OTEL_COLLECTOR}:/root/tracegen.log tracegen.log
