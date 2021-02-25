#!/bin/bash

OTEL_COLLECTOR=164.90.164.183
PROMETHEUS=134.209.251.218

curl ${OTEL_COLLECTOR}:8888/metrics > otelcol-metrics.txt
scp root@${OTEL_COLLECTOR}:/root/otelcol.log otelcol.log
scp root@${OTEL_COLLECTOR}:/root/tracegen.log tracegen.log
