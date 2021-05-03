#!/bin/bash

OTEL_COLLECTOR=145.40.93.141
PROMETHEUS=139.178.86.191

curl ${OTEL_COLLECTOR}:8888/metrics > otelcol-metrics.txt
scp root@${OTEL_COLLECTOR}:/root/otelcol.log otelcol.log
scp root@${OTEL_COLLECTOR}:/root/tracegen*.log .
