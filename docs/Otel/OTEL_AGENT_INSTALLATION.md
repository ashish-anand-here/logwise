# OpenTelemetry Agent Installation Guide

This guide provides step-by-step instructions for installing OpenTelemetry (OTEL) agents as standalone processes for Java, Python, and Node.js applications.

## Overview

OpenTelemetry agents automatically instrument your applications to collect observability data including logs, traces, and metrics. This guide covers standalone agent installation that runs alongside your applications without containerization.

### Architecture

```
Application Process → OTEL Agent Process → OTEL Collector → Observability Backend
```

## Prerequisites

Before installing OTEL agents, ensure you have:

- **OTEL Collector running**
- **Required permissions** for auto-instrumentation
- **System resources** for running additional processes

## System Requirements

- **Linux/Unix** systems (Ubuntu, CentOS, Amazon Linux, etc.)
- **Java 8+** for Java applications
- **Node.js 14+** for Node.js applications  
- **Python 3.7+** for Python applications
- **2GB RAM** minimum for agent processes
- **Network access** to OTEL Collector

## Java Agent Installation

### Step 1: Download Java Agent

```bash
# Create agent directory
sudo mkdir -p /opt/otel-agent/java
cd /opt/otel-agent/java

# Download the latest Java agent JAR
sudo curl -L -o opentelemetry-javaagent.jar \
  https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar

# Set proper permissions
sudo chmod 644 opentelemetry-javaagent.jar
sudo chown root:root opentelemetry-javaagent.jar
```

### Step 2: Create Configuration

```bash
# Create configuration file
sudo tee /opt/otel-agent/java/agent.conf > /dev/null <<EOF
# OTEL Agent Configuration for Java
OTEL_SERVICE_NAME=my-java-app
OTEL_SERVICE_VERSION=1.0.0
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_LOGS_EXPORTER=otlp
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=none
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production,service.namespace=backend
EOF
```

### Step 3: Create Systemd Service

```bash
# Create systemd service file
sudo tee /etc/systemd/system/otel-java-agent.service > /dev/null <<EOF
[Unit]
Description=OpenTelemetry Java Agent
After=network.target

[Service]
Type=simple
User=otel-agent
Group=otel-agent
WorkingDirectory=/opt/otel-agent/java
EnvironmentFile=/opt/otel-agent/java/agent.conf
ExecStart=/usr/bin/java -javaagent:/opt/otel-agent/java/opentelemetry-javaagent.jar -jar /path/to/your/application.jar
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create otel-agent user
sudo useradd -r -s /bin/false otel-agent
sudo chown -R otel-agent:otel-agent /opt/otel-agent/java

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable otel-java-agent.service
```

### Step 4: Start Agent Service

```bash
# Start the agent service
sudo systemctl start otel-java-agent.service

# Check status
sudo systemctl status otel-java-agent.service

# View logs
sudo journalctl -u otel-java-agent.service -f
```

### Manual Execution

```bash
# Load environment variables
source /opt/otel-agent/java/agent.conf

# Run your Java application with agent
java -javaagent:/opt/otel-agent/java/opentelemetry-javaagent.jar \
     -Dotel.service.name=$OTEL_SERVICE_NAME \
     -Dotel.service.version=$OTEL_SERVICE_VERSION \
     -Dotel.exporter.otlp.endpoint=$OTEL_EXPORTER_OTLP_ENDPOINT \
     -Dotel.exporter.otlp.protocol=$OTEL_EXPORTER_OTLP_PROTOCOL \
     -Dotel.logs.exporter=$OTEL_LOGS_EXPORTER \
     -Dotel.traces.exporter=$OTEL_TRACES_EXPORTER \
     -Dotel.metrics.exporter=$OTEL_METRICS_EXPORTER \
     -Dotel.resource.attributes=$OTEL_RESOURCE_ATTRIBUTES \
     -jar your-application.jar
```

## Node.js Agent Installation

### Step 1: Install Node.js Agent

```bash
# Create agent directory
sudo mkdir -p /opt/otel-agent/nodejs
cd /opt/otel-agent/nodejs

# Install Node.js OTEL packages globally
sudo npm install -g @opentelemetry/api @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node @opentelemetry/exporter-trace-otlp-http @opentelemetry/exporter-logs-otlp-http

# Create agent initialization script
sudo tee /opt/otel-agent/nodejs/otel-init.js > /dev/null <<'EOF'
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPLogExporter } = require('@opentelemetry/exporter-logs-otlp-http');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT + '/v1/traces',
  }),
  logRecordProcessor: new BatchLogRecordProcessor(
    new OTLPLogExporter({
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT + '/v1/logs',
    })
  ),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
console.log('OTEL SDK initialized for Node.js');
EOF
```

### Step 2: Create Configuration

```bash
# Create configuration file
sudo tee /opt/otel-agent/nodejs/agent.conf > /dev/null <<EOF
# OTEL Agent Configuration for Node.js
OTEL_SERVICE_NAME=my-nodejs-app
OTEL_SERVICE_VERSION=1.0.0
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_LOGS_EXPORTER=otlp
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=none
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production,service.namespace=backend
EOF
```

### Step 3: Create Systemd Service

```bash
# Create systemd service file
sudo tee /etc/systemd/system/otel-nodejs-agent.service > /dev/null <<EOF
[Unit]
Description=OpenTelemetry Node.js Agent
After=network.target

[Service]
Type=simple
User=otel-agent
Group=otel-agent
WorkingDirectory=/opt/otel-agent/nodejs
EnvironmentFile=/opt/otel-agent/nodejs/agent.conf
ExecStart=/usr/bin/node -r /opt/otel-agent/nodejs/otel-init.js /path/to/your/app.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Set proper permissions
sudo chown -R otel-agent:otel-agent /opt/otel-agent/nodejs

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable otel-nodejs-agent.service
```

### Step 4: Start Agent Service

```bash
# Start the agent service
sudo systemctl start otel-nodejs-agent.service

# Check status
sudo systemctl status otel-nodejs-agent.service

# View logs
sudo journalctl -u otel-nodejs-agent.service -f
```

### Manual Execution

```bash
# Load environment variables
source /opt/otel-agent/nodejs/agent.conf

# Run your Node.js application with agent
node -r /opt/otel-agent/nodejs/otel-init.js /path/to/your/app.js
```

## Python Agent Installation

### Step 1: Install Python Agent

```bash
# Create agent directory
sudo mkdir -p /opt/otel-agent/python
cd /opt/otel-agent/python

# Install Python OTEL packages globally
sudo pip3 install opentelemetry-distro[otlp] opentelemetry-instrumentation

# Install specific instrumentations based on your framework
sudo pip3 install opentelemetry-instrumentation-flask opentelemetry-instrumentation-django opentelemetry-instrumentation-fastapi opentelemetry-instrumentation-requests

# Create agent initialization script
sudo tee /opt/otel-agent/python/otel-init.py > /dev/null <<'EOF'
import os
from opentelemetry import trace, logs
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.logs import LoggerProvider
from opentelemetry.sdk.logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.http.log_exporter import OTLPLogExporter

# Initialize tracing
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

# Initialize logging
log_exporter = OTLPLogExporter(endpoint=os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT') + '/v1/logs')
logger_provider = LoggerProvider()
logger_provider.add_log_record_processor(BatchLogRecordProcessor(log_exporter))
logs.set_logger_provider(logger_provider)

# Add span processor
span_processor = BatchSpanProcessor(OTLPSpanExporter(endpoint=os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT') + '/v1/traces'))
trace.get_tracer_provider().add_span_processor(span_processor)

print('OTEL SDK initialized for Python')
EOF
```

### Step 2: Create Configuration

```bash
# Create configuration file
sudo tee /opt/otel-agent/python/agent.conf > /dev/null <<EOF
# OTEL Agent Configuration for Python
OTEL_SERVICE_NAME=my-python-app
OTEL_SERVICE_VERSION=1.0.0
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_LOGS_EXPORTER=otlp
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=none
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production,service.namespace=backend
EOF
```

### Step 3: Create Systemd Service

```bash
# Create systemd service file
sudo tee /etc/systemd/system/otel-python-agent.service > /dev/null <<EOF
[Unit]
Description=OpenTelemetry Python Agent
After=network.target

[Service]
Type=simple
User=otel-agent
Group=otel-agent
WorkingDirectory=/opt/otel-agent/python
EnvironmentFile=/opt/otel-agent/python/agent.conf
ExecStart=/usr/bin/python3 -c "exec(open('/opt/otel-agent/python/otel-init.py').read()); exec(open('/path/to/your/app.py').read())"
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Set proper permissions
sudo chown -R otel-agent:otel-agent /opt/otel-agent/python

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable otel-python-agent.service
```

### Step 4: Start Agent Service

```bash
# Start the agent service
sudo systemctl start otel-python-agent.service

# Check status
sudo systemctl status otel-python-agent.service

# View logs
sudo journalctl -u otel-python-agent.service -f
```

### Manual Execution

```bash
# Load environment variables
source /opt/otel-agent/python/agent.conf

# Run your Python application with agent
opentelemetry-instrument python /path/to/your/app.py
```

## Environment-Specific Configuration

```bash
# Production environment
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=production,service.namespace=backend,team.name=platform"

# Staging environment  
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=staging,service.namespace=backend,team.name=platform"

# Development environment
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=development,service.namespace=backend,team.name=platform"
```

## Environment Variables Reference

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `OTEL_SERVICE_NAME` | Name of your service | Required | `my-app` |
| `OTEL_SERVICE_VERSION` | Version of your service | `unknown` | `1.0.0` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTEL Collector endpoint | Required | `http://otel-collector:4318` |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | Protocol to use | `grpc` | `http/protobuf` |
| `OTEL_LOGS_EXPORTER` | Log exporter to use | `none` | `otlp` |
| `OTEL_TRACES_EXPORTER` | Trace exporter to use | `none` | `otlp` |
| `OTEL_METRICS_EXPORTER` | Metrics exporter to use | `none` | `otlp` |
| `OTEL_RESOURCE_ATTRIBUTES` | Additional resource attributes | - | `deployment.environment=production` |

## Monitoring Agent Health

```bash
# Check agent processes
if pgrep -f "opentelemetry-javaagent.jar" > /dev/null; then
    echo "Java Agent: RUNNING"
else
    echo "Java Agent: NOT RUNNING"
fi

if pgrep -f "otel-init.js" > /dev/null; then
    echo "Node.js Agent: RUNNING"
else
    echo "Node.js Agent: NOT RUNNING"
fi

if pgrep -f "otel-init.py" > /dev/null; then
    echo "Python Agent: RUNNING"
else
    echo "Python Agent: NOT RUNNING"
fi
```

## Troubleshooting

### Common Issues

#### Connection Refused
```
Error: Failed to connect to OTEL Collector
```
**Solution**: Ensure OTEL Collector is running and accessible at the configured endpoint.

#### Authentication Failed
```
Error: 401 Unauthorized
```
**Solution**: Check your authentication headers and API keys.

#### No Logs Appearing
```
Issue: Logs not being sent to collector
```
**Solutions**:
- Verify `OTEL_LOGS_EXPORTER=otlp` is set
- Check OTEL Collector configuration
- Ensure proper instrumentation is loaded

### Debug Mode

Enable debug logging to troubleshoot issues:

```bash
# Java
export OTEL_LOG_LEVEL=debug

# Node.js
export OTEL_LOG_LEVEL=debug

# Python
export OTEL_LOG_LEVEL=debug
```

### Health Checks

Check if your agent processes are running:

```bash
# Check Java agent
ps aux | grep opentelemetry-javaagent.jar

# Check Node.js agent
ps aux | grep otel-init.js

# Check Python agent
ps aux | grep otel-init.py
```

## Related Documentation

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Java Instrumentation Guide](https://opentelemetry.io/docs/instrumentation/java/)
- [Node.js Instrumentation Guide](https://opentelemetry.io/docs/instrumentation/js/)
- [Python Instrumentation Guide](https://opentelemetry.io/docs/instrumentation/python/)
