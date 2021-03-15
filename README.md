# Performance results comparing the groupbytrace processor with the tailsampling processor

## Introduction

This repository contains the results for the performance tests comparing the [`groupbytrace`](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/groupbytraceprocessor) processor with the [`tailsampling`](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/tailsamplingprocessor) processor. Both processors are able to hold traces in memory before dispatching them to the next consumer. Given that the tail-based sampling processor also makes sampling decisions, this comparison might not be 100% fair. Considering that most of the load and memory pressure is at the related components, this comparison still holds value.

## Motivation

The tail-based sampling has two main roles:
- holds traces in memory for a specific period of time, so that a decision is made based on the trace as a whole
- makes the sampling decision based on the configured policy

There is a discussion in the community about splitting this processor into two, so that those two concerns are handled by different processors. This is particularly appealing given that the `groupbytrace` processor exists, covering a big part of the work done by the tail-based sampling processor.

In order to make a better informed decision on whether to deprecate the existing tail-based sampling processor in favor of the existing `groupbytrace` processor plus a non-existing `policysamplingprocessor`, this performance test was performed.

## Setup

In order to make the test reproducible, they were executed in a set of DigitalOcean droplets, as follows:

- CPU-Optimized with 16GB RAM for the OpenTelemetry Collector
- Basic with 2GB RAM for Prometheus

Fedora 33 has been used as the Linux distribution for all machines.

Load is generated using the [`tracegen`](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/tracegen) utility. This load generator isn't representative of a real load, but is able to generate a fixed number of traces at a steady rate, making it ideal for this case. For those interested in extending this benchmark, the [Omnition/synthetic-load-generator](https://github.com/Omnition/synthetic-load-generator) is recommended as an alternative. The following command was used with both scenarios:

    $ time tracegen -traces=2_000_000 -rate=100_000 -otlp-insecure=true 2>&1 | tee tracegen.log

For the test, the OpenTelemetry Collector Contrib v0.20.0 was used, downloaded from the project's GitHub Releases page. The `tracegen` utility was installed using `go get github.com/open-telemetry/opentelemetry-collector-contrib/tracegen` locally and is transfered with the setup script. The OpenTelemetry Collector was started with:

    $ otelcontribcol_linux_amd64 --config config.groupbytrace.yaml --metrics-addr 0.0.0.0:8888 2>&1 | tee otelcol.log

The script inside the `_setup` directory was used to prepare the hosts.

## Configuration

The file `config.groupbytrace.yaml` contains the configuration used for the test using the groupbytrace processor, while the `config.tailsampling.yaml` contains the configuration for the test using the tailsampling processor.

The `prometheus.yaml` contains the Prometheus configuration to scrape the endpoints.

## Results

The [`results`](./results) directory contains the raw metrics and logs for the two scenarios.

PromQL queries:
```
otelcol_process_runtime_heap_alloc_bytes{instance="otel-collector:8888", job="otel-collector"}
rate(otelcol_exporter_sent_spans{exporter="logging", instance="otel-collector:8888", job="otel-collector"}[1m])
rate(otelcol_receiver_accepted_spans{instance="otel-collector:8888", job="otel-collector", receiver="otlp", transport="grpc"}[1m])
otelcol_processor_groupbytrace_processor_groupbytrace_num_events_in_queue
otelcol_processor_groupbytrace_processor_groupbytrace_num_traces_in_memory
```

In the following graph, four runs can be seen. All runs are in the same machine, and have the following configurations:

- groupbytrace test with a custom version of the OpenTelemetry Collector Contrib supporting a customizable event buffer size, with the buffer set to 1 million entries
- same as above, with 10 thousand entries
- same as above, withouth the batch processor
- tail-based sampling configuration

![Prometheus graphs](prometheus.png "Prometheus graphs")

And the following are the host metrics as recorded by DigitalOcean:

![DigitalOcean graphs](metrics-from-cloud-provider.png "DigitalOcean graphs")

### To investigate

The histogram `otelcol_processor_tail_sampling_sampling_decision_timer_latency_bucket` seems to indicate that some timer is stuck pending a decision. If this is indeed the case, there might be some concurrency issue happening with the tail-based sampling processor:

## Takeaways

- The tail-based sampling processor has more than 5x higher memory consumption with the same throughput.
- Making the internal event buffer customizable didn't produce significant differences, especially as the buffer was always under 450 events.
- Only the first test was executed to completion, and all expected spans (40M) were received and exported.
- The logging exporter reports that all tests were able to process all spans that were received (`otelcol_exporter_sent_spans` vs. `otelcol_receiver_accepted_spans`).
- In the first test, a few valleys can be seen at most of the graphs, including the one for the receiver and for the exporter, like the one at 11am. There were no apparent reasons for that.

### Next steps

- Run the tests on a bare metal, where the performance can be more reliable. While this last test was consistent in the sense that all tests got a similar throughput, previous runs had different throughput levels. Having a bare metal for this test would allow to test the hypothesis of noisy neighbours influencing the virtual machine. A machine [has been requested](https://github.com/cncf/cluster/issues/167) for this purpose.