#!/bin/bash

for i in {1..5}; do
    echo Starting runner ${i}
    ./tracegen -duration=10m -otlp-insecure=true 2>&1 > tracegen-${i}.log &
    pid=$!
    pids[${i}]=${pid}
    echo Runner ${i} got pid ${pid}
done

for pid in ${pids[*]}; do
    echo "Waiting for runner to complete (pid: ${pid})"
    wait $pid
done