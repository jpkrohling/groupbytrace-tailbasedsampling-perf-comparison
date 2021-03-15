#!/bin/bash

OTEL_COLLECTOR=134.209.254.47
PROMETHEUS=128.199.56.242

for host in ${OTEL_COLLECTOR} ${PROMETHEUS}; do
    ssh root@${host} "dnf install screen -y"
done

## setup the Prometheus host
echo Preparing the Prometheus host
ssh root@${PROMETHEUS} "dnf install golang-github-prometheus -y"
ssh root@${PROMETHEUS} "echo ${OTEL_COLLECTOR} otel-collector >> /etc/hosts"
ssh root@${PROMETHEUS} "sed 's/127\.0\.0\.1/0.0.0.0/gi' /etc/sysconfig/prometheus -i"
scp _setup/prometheus.yaml root@${PROMETHEUS}:/etc/prometheus/prometheus.yml
ssh root@${PROMETHEUS} "systemctl start prometheus"

## setup the OpenTelemetry Collector host
echo Preparing the OpenTelemetry Collector host
scp -C ~/go/bin/otelcontribcol_linux_amd64 root@${OTEL_COLLECTOR}:/root/
scp -C ~/go/bin/tracegen root@${OTEL_COLLECTOR}:/root/
scp config.*.yaml root@${OTEL_COLLECTOR}:/root/
