# Performance results comparing the groupbytrace processor with the tailsampling processor

## Introduction

This repository contains the results for the performance tests comparing the [`groupbytrace`](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/groupbytraceprocessor) processor with the [`tailsampling`](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/tailsamplingprocessor) processor. Both processors are able to hold traces in memory before dispatching them to the next consumer. Given that the tail-based sampling processor also makes sampling decisions, the sampling decision code has been extracted into its own processor, called `policysamplingprocessor`. The configuration for this new processor is compatible with the similar attribute from the tail-sampling processor, and the same policy has been used across all tests. This new processor isn't published yet, but might depending on the results of this test. The end effect is that the overhead of calling a second processor is taken into account, whereas the sampling decision itself is neutralized.

## Motivation

The tail-based sampling has two main roles:
- holds traces in memory for a specific period of time, so that a decision is made based on the trace as a whole
- makes the sampling decision based on the configured policy

There is a discussion in the community about splitting this processor into two, so that those two concerns are handled by different processors. This is particularly appealing given that the `groupbytrace` processor exists, covering a big part of the work done by the tail-based sampling processor.

In order to make a better informed decision on whether to deprecate the existing tail-based sampling processor in favor of the existing `groupbytrace` processor plus `policysamplingprocessor`, this performance test was created.

## Setup

In order to make the test reproducible, they were executed in a set of Equinix bare metal machines sponsored by the CNCF, as follows:

- c3.small.x86 (1x Intel(R) Xeon(R) E-2278G CPU @ 3.40GHz, 32GB RAM) for the OpenTelemetry Collector
- x1.small.x86 (1x Intel(R) Xeon(R) CPU E3-1578L v5 @ 2.00GHz, 32GB RAM) Basic with 2GB RAM for Prometheus

CentOS 8 has been used as the Linux distribution for all machines.

Load is generated using the [`tracegen`](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/tracegen) utility. This load generator isn't representative of a real load, but is able to generate a fixed number of traces at a steady rate, making it ideal for this case. For those interested in extending this benchmark, the [Omnition/synthetic-load-generator](https://github.com/Omnition/synthetic-load-generator) might be a good alternative. The following command was used with both scenarios:

    $ ./runner.sh

For the test, a custom build of the OpenTelemetry Collector Contrib was used based on the `main` branch on Apr 29 (`4be4a1adcdbb0de95872275e99f40e2406e46d4c`), plus the PR [#1710](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/1710). The runner script above expects the binary to exist in your machine under `~/bin/otelcontribcol_linux_amd64`. This is then trasfered to the Equinix machine during the `_setup/prepare-hosts.sh` script. The `tracegen` utility was installed using `go get github.com/open-telemetry/opentelemetry-collector-contrib/tracegen` locally and is transfered with the setup script as well. The OpenTelemetry Collector was started with:

    $ ./otelcontribcol_linux_amd64 --config config.groupbytrace.yaml --metrics-addr 0.0.0.0:8888 2>&1 | tee otelcol.log

The script inside the `_setup` directory was used to prepare the hosts.

## Configuration

The file `config.groupbytrace.yaml` contains the configuration used for the test using the groupbytrace processor, while the `config.tailsampling.yaml` contains the configuration for the test using the tailsampling processor.

The `prometheus.yaml` contains the Prometheus configuration to scrape the endpoints.

## Results

The [`results`](./results) directory contains the raw metrics and logs for the two scenarios.

The screenshots were genereted while the following PromQL queries were loaded:
```
otelcol_process_runtime_heap_alloc_bytes{instance="otel-collector:8888", job="otel-collector"}
rate(otelcol_exporter_sent_spans{exporter="logging", instance="otel-collector:8888", job="otel-collector"}[1m])
rate(otelcol_receiver_accepted_spans{instance="otel-collector:8888", job="otel-collector", receiver="otlp", transport="grpc"}[1m])
otelcol_processor_groupbytrace_processor_groupbytrace_num_events_in_queue
otelcol_processor_groupbytrace_processor_groupbytrace_num_traces_in_memory
```

Each result directory also contains:
- the logs from all tracegen runs
- the logs from the OpenTelemetry Collector instance under test
- a screenshot of the state of the queries from Prometheus was also recorded
- the configuration used in the run

Some runs are identical to the previous runs, to verify that the results are consistent. High standard deviation between test runs would indicate a flaw in the way the test was performed.
### To investigate

Some parameters from the `groupbytrace` might need some further tweaking, as the collector still had plenty of memory available. Also, some valleys were seen in some graphs, indicating that there might be a resource contention, possibly around the queue size.
## Takeaways

- The configuration used by the `groupbytrace` had 5GB memory usage at its maximum, with a throughput between ~110k and ~130k spans / sec.
- The `tailsampling` configuration produced a very irregular throughput, with a peak of ~550k spans / sec, and lows of ~180k spans / sec, with a memory consumption peaking ~30GB.
- Once the max number of events from the `groupbytrace` processor is reached, its throughput is compromised, causing the processor to block until the queue is cleaned up.
- All spans from the `groupbytrace` were accounted for across all runs (metrics `otelcol_receiver_accepted_spans` vs. `otelcol_exporter_sent_spans`)
- Considerable amount of spans are missing for the `tailsampling` (metrics `otelcol_receiver_accepted_spans` vs. `otelcol_exporter_sent_spans`)

### Next steps

- Run the tests on a bare metal, where the performance can be more reliable. While this last test was consistent in the sense that all tests got a similar throughput, previous runs had different throughput levels. Having a bare metal for this test would allow to test the hypothesis of noisy neighbours influencing the virtual machine. A machine [has been requested](https://github.com/cncf/cluster/issues/167) for this purpose.