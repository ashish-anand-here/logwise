# Apache Spark

Apache Spark is the **log processing engine** in the LogWise system. It consumes logs from Kafka, transforms them as needed, and writes them to Amazon S3.

## Architecture

Spark handles:
- **Ingestion**: Reads logs from Kafka topics in near real-time
- **Partitioned Storage**: Writes logs to S3 in a hierarchical, time-based partition format
- **Schema Management**: Ensures consistent schema across logs using predefined formats

## Key Features

### Real-Time Processing
- Consumes logs from Kafka topics continuously
- Supports micro-batch and streaming modes
- Enables near real-time analytics


### Partitioned Storage in S3
- Writes logs in partitioned directories for efficient query and retrieval
- Partition format: `/env=<env>/service_name=<service_name>/year=<YYYY>/month=<MM>/day=<DD>/hour=<HH>/minute=<mm>/`
- This structure allows fast filtering based on environment, service, or time ranges.

### Fault Tolerance
- Checkpointing ensures no data loss on failures
- Kafka offsets tracked for `exactly-once` processing
- Can recover from Spark job failures automatically
### Autoscaling Logic

Spark in LogWise automatically adjusts worker count based on historical stage metrics to handle variable log volumes efficiently.

#### How It Works

1. **Stage History Collection**
    - After each job, metrics for completed stages are collected (`SparkStageHistory`):
        - `inputRecords` — number of records processed
        - `outputBytes` — size of output data
        - `coresUsed` — CPU cores utilized
        - Submission & completion timestamps

2. **Input Growth Analysis**
    - The orchestrator inspects the last N stages (configured in  `orchestrator` service).
    - Determines if input records are **incremental** or consistent across stages.
    - Computes an **incremental buffer** to anticipate growth in workload.

3. **Worker & Core Calculation**
    - Using tenant configuration (`perCoreLogsProcess`), calculates **expected executor cores**:
      ```
      expectedExecutorCores = ceil(maxInputRecordsWithBuffer / perCoreLogsProcess)
      ```
    - Converts expected cores to **worker count** while respecting tenant min/max limits.

4. **Scaling Decisions**
    - **Upscale**: Adds workers if workload exceeds current capacity.
    - **Downscale**: Removes workers if workload is below thresholds.
    - Scaling only occurs if configured conditions (`enableUpscale` / `enableDownscale`) are met.

5. **Integration with Orchestrator**
    - Stage metrics are sent to the **Orchestrator Service** after job completion.
    - Orchestrator decides worker scaling for the next job.
    - Ensures Spark adapts dynamically without manual intervention.

#### Benefits

- Efficient resource usage — scale only when needed
- Handles sudden log spikes gracefully
- Reduces costs during low-traffic periods
- Maintains high throughput and performance

---

### Kafka Integration

- Spark consumes logs from Kafka topics created by Vector.
- Supports automatic topic discovery using regular expressions.
- Tracks Kafka offsets for reliable processing.


### References

- Spark Structured Streaming: https://spark.apache.org/docs/latest/streaming/index.html
- Kafka Integration: https://spark.apache.org/docs/latest/structured-streaming-kafka-integration.html



