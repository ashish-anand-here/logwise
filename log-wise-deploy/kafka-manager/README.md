# Kafka Manager Cluster Initialization

This directory contains scripts to automatically register the Kafka cluster in Kafka Manager.

## Files

- `init-cluster.sh` - Main script that registers the cluster
- `test-cluster.sh` - Script to test cluster connectivity
- `test-init.sh` - Script to test the entire initialization flow

## Usage

The cluster initialization runs automatically when you start the services:

```bash
docker-compose up -d kafka-manager-init
```

Or it runs automatically after `kafka-manager` becomes healthy.

## Manual Testing

To test the initialization script manually:

```bash
# Make sure services are running
docker-compose up -d zookeeper kafka kafka-manager

# Wait for services to be healthy
docker-compose ps

# Run the init script
docker-compose run --rm kafka-manager-init
```

## Troubleshooting

If the cluster is not registered:

1. **Check Kafka Manager logs:**
   ```bash
   docker logs lc_kafka_manager
   ```

2. **Check init script logs:**
   ```bash
   docker logs lc_kafka_manager_init
   ```

3. **Verify services are running:**
   ```bash
   docker-compose ps
   ```

4. **Test connectivity:**
   ```bash
   # Test Kafka Manager
   curl http://localhost:9000/api/clusters
   
   # Test Zookeeper from Kafka Manager
   docker exec lc_kafka_manager nc -z zookeeper 2181
   
   # Test Kafka from Kafka Manager
   docker exec lc_kafka_manager nc -z kafka 9092
   ```

5. **Manual registration:**
   - Open http://localhost:9000 in your browser
   - Click "Add Cluster"
   - Use these settings:
     - Cluster name: `logwise`
     - Zookeeper hosts: `zookeeper:2181`
     - Kafka version: `2.8.0`
     - Enable JMX polling: `true`

## Configuration

The script uses these environment variables (set in docker-compose.yml):

- `CLUSTER_NAME` - Name of the cluster (default: `logwise`)
- `ZK_HOSTS` - Zookeeper connection string (default: `zookeeper:2181`)
- `KAFKA_VERSION` - Kafka version for Kafka Manager (default: `2.8.0`)
- `KAFKA_MANAGER_HOST` - Kafka Manager hostname (default: `kafka-manager`)
- `KAFKA_MANAGER_PORT` - Kafka Manager port (default: `9000`)

## How It Works

1. Waits for Kafka Manager to be ready
2. Checks if cluster already exists
3. If not, fetches the cluster creation page
4. Extracts CSRF token from the page
5. Submits cluster creation form with CSRF token and session cookie
6. Verifies cluster was created
7. Tests cluster connectivity

## Notes

- The script uses Kafka version `2.8.0` which is compatible with Kafka Manager
- The actual Kafka version (7.6.0) may differ, but Kafka Manager works with 2.8.0
- JMX is automatically detected from Kafka broker configuration
- The script handles CSRF tokens and session cookies automatically

