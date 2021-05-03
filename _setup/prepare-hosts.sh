#!/bin/bash

OTEL_COLLECTOR=145.40.93.141
PROMETHEUS=139.178.86.191

for host in ${OTEL_COLLECTOR} ${PROMETHEUS}; do
    ssh root@${host} "dnf install epel-release -y"
    ssh root@${host} "dnf install screen -y"
done

## setup the Prometheus host
echo Preparing the Prometheus host
ssh root@${PROMETHEUS} "dnf install https://kojipkgs.fedoraproject.org//packages/golang-github-prometheus/2.24.1/4.el8/x86_64/golang-github-prometheus-2.24.1-4.el8.x86_64.rpm -y"
ssh root@${PROMETHEUS} "echo ${OTEL_COLLECTOR} otel-collector >> /etc/hosts"
ssh root@${PROMETHEUS} "sed 's/127\.0\.0\.1/0.0.0.0/gi' /etc/sysconfig/prometheus -i"
scp _setup/prometheus.yaml root@${PROMETHEUS}:/etc/prometheus/prometheus.yml
ssh root@${PROMETHEUS} "systemctl start prometheus"

## setup the OpenTelemetry Collector host
echo Preparing the OpenTelemetry Collector host
scp -C ~/bin/otelcontribcol_linux_amd64 root@${OTEL_COLLECTOR}:/root/
scp -C ~/go/bin/tracegen root@${OTEL_COLLECTOR}:/root/
scp config.*.yaml root@${OTEL_COLLECTOR}:/root/
scp runner.sh root@${OTEL_COLLECTOR}:/root/
