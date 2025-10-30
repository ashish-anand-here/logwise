# OpenTelemetry Log Shipping Configuration Guide

This guide covers OpenTelemetry (OTEL) collector configurations for log shipping, including OTLP receiver setup, file log tailing, and exporter configurations with detailed explanations of each component.

## Overview

OpenTelemetry collectors can receive logs through two primary methods:
1. **OTLP Protocol**: Applications send logs directly via OTLP (gRPC/HTTP)
2. **File Log Tailing**: Collector reads from log files on the filesystem

Both methods support batching, retry logic, and persistent queuing for reliable log delivery.

## Prerequisites

Before configuring OTEL log shipping, ensure you have:

- **OTEL Collector** installed and running
- **Network access** between applications and collector
- **File system permissions** for log file access (if using filelog receiver)

## OTLP Receiver Configuration

### Basic OTLP Setup

The OTLP receiver accepts logs from applications via gRPC or HTTP protocols.

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317            # Accept OTLP over gRPC (typical default port 4317)
      http:
        endpoint: 0.0.0.0:4318            # Accept OTLP over HTTP/JSON (typical default port 4318)
```

### Complete OTLP Configuration

```yaml
extensions:
  file_storage:
    directory: /var/lib/otelcol/storage   # Disk location for persistent queues/state

  bearertokenauth:
    token: ${env:MY_LOGS_API_KEY}         # Re-usable auth object for exporters

  health_check:
    endpoint: 0.0.0.0:13133               # Simple HTTP health endpoint for liveness/readiness checks

  pprof:
    endpoint: 0.0.0.0:1777                # Go pprof server for CPU/heap profiling

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  memory_limiter:
    limit_mib: 1500                       # Soft cap for Collector memory to avoid OOM
    spike_limit_mib: 500                  # Allow short spikes above limit_mib
    check_interval: 5s                    # How often to sample memory usage

  resource:
    attributes:
      - key: service.name
        value: ${env:SERVICE_NAME}
        action: insert                    # Add attribute only if absent
      - key: environment
        value: ${env:ENVIRONMENT}
        action: insert

  batch:
    timeout: 10s                          # Flush a batch every 10s even if not full
    send_batch_size: 1024                 # Preferred batch size for exporter calls
    send_batch_max_size: 2048             # Hard cap if bursts exceed send_batch_size

exporters:
  otlphttp:
    endpoint: "http://log-endpoint:5000"  # Base URL; exporter appends /v1/logs by default
    compression: gzip                     # Compress payloads to reduce bandwidth
    auth:
      authenticator: bearertokenauth      # Use the extension above to attach Authorization: Bearer <token>
    timeout: 30s                          # Per-request timeout to the backend
    retry_on_failure:                     # Exponential backoff for transient failures
      enabled: true
      initial_interval: 1s                # Starting delay
      max_interval: 30s                   # Maximum delay between retries
      max_elapsed_time: 300s              # Total time before giving up
      multiplier: 2.0                     # How much to increase delay each time
    sending_queue:                        # Durable queue so data survives restarts
      enabled: true
      storage: file_storage               # Uses the disk path defined in extensions.file_storage
      num_consumers: 10                   # Parallel workers draining the queue
      queue_size: 1000                    # Max batches enqueued (not records)

  debug:
    verbosity: detailed                   # Only for debugging

service:
  extensions: [file_storage, bearertokenauth, health_check, pprof]
  pipelines:
    logs:
      receivers: [otlp]                                   # Ingest logs from OTLP (gRPC/HTTP)
      processors: [memory_limiter, resource, batch]       # Apply memory guard, add attributes, and batch
      exporters: [otlphttp, debug]                        # Ship to your HTTP backend
```

## File Log Receiver Configuration

### Basic File Log Setup

The filelog receiver tails log files from the filesystem and parses them into structured logs.

```yaml
receivers:
  filelog:
    include: [ /var/log/my-app/*.log, /var/log/my-app/*.log.gz ]
    start_at: beginning                       # Read from start on first discovery
    compression: auto                         # Auto-detects and decompresses .gz files
```

### Complete File Log Configuration

```yaml
extensions:
  file_storage:
    directory: /var/lib/otelcol/storage   # Disk used by exporters' persistent queues

  bearertokenauth:
    token: ${env:MY_LOGS_API_KEY}         # Read from env; attached by exporters

  health_check:
    endpoint: 0.0.0.0:13133               # /healthz endpoint for liveness/readiness checks

  pprof:
    endpoint: 0.0.0.0:1777                # Go pprof server for CPU/memory profiling

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

  filelog:
    include: [ /var/log/my-app/*.log, /var/log/my-app/*.log.gz ]
    start_at: beginning                       # Read from start on first discovery
    compression: auto                         # Auto-detects and decompresses .gz files

    operators:
      - type: regex_parser                    # Parse each line with a regex and capture fields
        regex: '^(?P<time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} IST) (?P<level>\w+) (?P<message>.*)$'
        
        timestamp:
          parse_from: attributes.time             # Use the 'time' captured by regex above
          layout: '%Y-%m-%d %H:%M:%S IST'         # Your format with a literal "IST"
          
        severity:
          parse_from: attributes.level
          mapping:
            INFO: INFO
            WARN: WARN
            ERROR: ERROR

processors:
  memory_limiter:
    limit_mib: 1500                       # Keep collector memory below ~1.5 GiB
    spike_limit_mib: 500                  # Allow brief spikes above the limit
    check_interval: 5s                    # Memory sampling cadence

  resource:
    attributes:
      - key: service.name
        value: ${env:SERVICE_NAME}
        action: insert                    # Add only if missing
      - key: environment
        value: ${env:ENVIRONMENT}
        action: insert

  batch:
    timeout: 10s                          # Flush a batch at least every 10s
    send_batch_size: 1024                 # Target batch size per exporter call
    send_batch_max_size: 2048             # Hard cap for very bursty periods

exporters:
  otlphttp:
    endpoint: "http://log-endpoint:5000"  # Base URL; appends /v1/logs for the logs signal
    compression: gzip                     # Compress payloads
    auth:
      authenticator: bearertokenauth      # Attach Authorization: Bearer <MY_LOGS_API_KEY>
    timeout: 30s                          # Per-request timeout
    retry_on_failure:                     # Exponential backoff on transient failures
      enabled: true
      initial_interval: 1s
      max_interval: 30s
      max_elapsed_time: 300s
      multiplier: 2.0
    sending_queue:                        # Durable, on-disk queue for reliability
      enabled: true
      storage: file_storage               # Uses /var/lib/otelcol/storage
      num_consumers: 10                   # Parallel workers draining the queue
      queue_size: 1000                    # Max batches enqueued (not individual records)

  debug:
    verbosity: detailed                   # Only for debugging

service:
  extensions: [file_storage, bearertokenauth, health_check, pprof]
  pipelines:
    logs:
      receivers: [otlp, filelog]                        # Accept logs from OTLP and from tailed files
      processors: [memory_limiter, resource, batch]     # Guard memory, enrich with attributes, and batch
      exporters: [otlphttp, debug]                      # Ship to backend
```

## Exporter Sending Queue Configuration

The sending queue provides reliable log delivery with retry logic and persistent storage.

### Queue Settings Reference

| **Setting**                   | **What it Controls**                                             | **Default**        | **Practical Limit**     | **Notes / Tuning Tips**                                                                    |
| ----------------------------- | ---------------------------------------------------------------- | ------------------ | ----------------------- | ------------------------------------------------------------------------------------------ |
| `sending_queue.enabled`       | Enables the async buffer in front of the exporter                | `true`             | —                       | Keep on for burst/back-pressure handling.                                                  |
| `sending_queue.queue_size`    | Max batches buffered (in memory, or on disk if `storage` is set) | `1000 batches`     | Constrained by RAM/disk | With persistent queue (`storage`), batches are stored on disk; size accordingly.           |
| `sending_queue.num_consumers` | Parallel workers draining the queue                              | `10`               | CPU/network bound       | Increase gradually for throughput; monitor CPU and backend rate limits.                    |
| `sending_queue.storage`       | Persistent queue backend (e.g., `file_storage`)                  | `none (in-memory)` | Disk capacity / I/O     | When set, queue is on disk; no in-memory queue is used. Defaults (queue size) still apply. |
| **Retry window (exporter)**   | Max time spent retrying a failed batch                           | exporter-specific  | —                       | Typical defaults: initial `5s`, max `30s`, total `120–300s`. Tune per backend SLAs.        |

### Queue Configuration Example

```yaml
exporters:
  otlphttp:
    endpoint: "http://log-endpoint:5000"
    sending_queue:
      enabled: true
      storage: file_storage               # Persistent queue on disk
      num_consumers: 10                   # Parallel workers
      queue_size: 1000                    # Max batches enqueued
    retry_on_failure:
      enabled: true
      initial_interval: 1s
      max_interval: 30s
      max_elapsed_time: 300s
      multiplier: 2.0
```

## File Log Receiver Capacity & Defaults

### Capacity Settings Reference

| **Setting**            | **Meaning**                                        | **Default**        | **Notes**                                                                                                   |
| ---------------------- | -------------------------------------------------- | ------------------ | ----------------------------------------------------------------------------------------------------------- |
| `max_concurrent_files` | Max files tailed concurrently                      | `1024`             | If more files match, they're processed in batches. Ensure OS `ulimit -n` supports it.                       |
| `poll_interval`        | Filesystem scan interval                           | `200ms`            | Lower = faster detection, higher = fewer syscalls.                                                          |
| `fingerprint_size`     | Bytes used to identify a file                      | `1 KiB`            | Lets the receiver follow renames/rotation.                                                                  |
| `initial_buffer_size`  | Initial read buffer for entries                    | `16 KiB`           | Grows as needed; tune only for extremely large lines.                                                       |
| `max_batches`          | Cap batches per poll when `> max_concurrent_files` | `0 (no limit)`     | Applies only when batching is needed due to many files.                                                     |
| `start_at`             | Where to start on first read                       | *(set explicitly)* | Options: `beginning` or `end`. Set deliberately to avoid surprises across versions.                         |
| `compression`          | Read compressed archives                           | `none`             | Options: `gzip` or `auto` (auto-detect `.gz`). Use a separate receiver for archives if mixing live + `.gz`. |

### Capacity Configuration Example

```yaml
receivers:
  filelog:
    include: [ /var/log/my-app/*.log ]
    max_concurrent_files: 256        # Max files to read simultaneously
    poll_interval: 200ms            # Filesystem scan interval
    fingerprint_size: 1024          # Bytes for file identification
    initial_buffer_size: 16384      # Initial read buffer
    start_at: beginning             # Read from start on first discovery
    compression: auto               # Auto-detect .gz files
```

## Log Rotation & Compression Behavior

### Rotation Scenarios

| **Scenario**                                                        | **Behavior in `filelog`**                                                                                |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Rename/create rotation (e.g., `app.log → app.log.1`, new `app.log`) | Tracked via fingerprint; continues reading seamlessly; new file is tailed.                               |
| `copytruncate` rotation                                             | Can cause lost or duplicate lines during truncate window.                                                |
| Archives compressed to `.gz`                                        | Supported when `compression: gzip` or `auto`; `.gz` files are read from start.                           |
| Live + archives ingested together                                   | Rotated `.gz` may be treated as a new file → contents re-read ⇒ potential duplicates.                    |
| Compressed fingerprinting                                           | Fingerprint for `.gz` normally uses raw bytes; optional feature gate can fingerprint decompressed bytes. |

### Rotation Configuration Example

```yaml
receivers:
  filelog:
    include: [ /var/log/my-app/*.log, /var/log/my-app/*.log.* ]
    start_at: beginning
    compression: auto
    max_concurrent_files: 256
    # Handles both live logs and rotated .gz files
```

## Best Practices

### Configuration Recommendations

1. **Memory Management**: Set `memory_limiter` limits below container memory limits
2. **Batch Sizing**: Balance latency vs throughput with appropriate batch sizes
3. **Retry Logic**: Configure retry settings based on backend SLAs
4. **Persistent Queues**: Use `file_storage` for production reliability
5. **Resource Attributes**: Add consistent service identification

### Performance Tuning

- **Increase `num_consumers`** for higher throughput (monitor CPU usage)
- **Adjust `queue_size`** based on available disk space
- **Tune `send_batch_size`** for optimal backend performance
- **Set appropriate `timeout`** values for your network conditions

### Monitoring

- **Health Checks**: Use the health check endpoint for liveness probes
- **Profiling**: Enable pprof for performance analysis
- **Debug Logging**: Use debug exporter for troubleshooting (disable in production)

## Troubleshooting

### Common Issues

1. **Memory Issues**: Reduce `limit_mib` or increase container memory
2. **File Permission Errors**: Ensure collector has read access to log files
3. **Network Timeouts**: Increase `timeout` values for slow networks
4. **Duplicate Logs**: Check rotation configuration and fingerprint settings

### Debug Configuration

```yaml
exporters:
  debug:
    verbosity: detailed                   # Enable detailed debug output

service:
  pipelines:
    logs:
      exporters: [otlphttp, debug]       # Include debug exporter for troubleshooting
```

## Related Documentation

- [OTEL Agent Installation Guide](OTEL_AGENT_INSTALLATION.md)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Collector Configuration Reference](https://opentelemetry.io/docs/collector/configuration/)
- [File Log Receiver Documentation](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/filelogreceiver)
