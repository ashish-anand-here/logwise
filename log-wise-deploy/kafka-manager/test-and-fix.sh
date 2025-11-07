#!/bin/bash
set -e

echo "=========================================="
echo "Testing and Fixing Kafka Manager Cluster"
echo "=========================================="
echo ""

cd "$(dirname "$0")/.."

# Check if services are running
echo "[1/4] Checking Docker services..."
if ! docker ps | grep -q "lc_kafka_manager"; then
    echo "✗ ERROR: Kafka Manager is not running"
    echo "  Run: make up"
    exit 1
fi
echo "✓ Kafka Manager is running"

if ! docker ps | grep -q "lc_kafka"; then
    echo "✗ ERROR: Kafka is not running"
    echo "  Run: make up"
    exit 1
fi
echo "✓ Kafka is running"

if ! docker ps | grep -q "lc_zookeeper"; then
    echo "✗ ERROR: Zookeeper is not running"
    echo "  Run: make up"
    exit 1
fi
echo "✓ Zookeeper is running"
echo ""

# Check if cluster exists
echo "[2/4] Checking if cluster exists..."
sleep 2
CLUSTERS=$(curl -s http://localhost:9000/api/clusters 2>&1 || echo "[]")

if echo "$CLUSTERS" | grep -q "\"logwise\""; then
    echo "✓ Cluster 'logwise' already exists"
    echo "  Testing cluster connectivity..."
    sleep 2
    TOPICS=$(curl -s http://localhost:9000/api/clusters/logwise/topics 2>&1 || echo "")
    if echo "$TOPICS" | grep -qi "error\|exception" > /dev/null 2>&1; then
        echo "⚠ WARNING: Cluster exists but has connectivity issues"
        echo "  You may need to delete and recreate it via web UI"
    else
        echo "✓ Cluster is working correctly"
        exit 0
    fi
else
    echo "✗ Cluster 'logwise' does not exist"
fi
echo ""

# Run init script
echo "[3/4] Running cluster initialization..."
echo "  This will create the 'logwise' cluster"
echo ""

# Stop and remove existing init container if it exists
docker-compose stop kafka-manager-init 2>/dev/null || true
docker-compose rm -f kafka-manager-init 2>/dev/null || true

# Run the init container
echo "  Starting init container..."
docker-compose up -d kafka-manager-init

# Wait for it to complete
echo "  Waiting for initialization to complete..."
sleep 5

# Check logs
echo ""
echo "[4/4] Checking initialization logs..."
docker logs lc_kafka_manager_init 2>&1 | tail -30

# Verify cluster was created
echo ""
echo "Verifying cluster registration..."
sleep 5
CLUSTERS_FINAL=$(curl -s http://localhost:9000/api/clusters 2>&1 || echo "[]")

if echo "$CLUSTERS_FINAL" | grep -q "\"logwise\""; then
    echo ""
    echo "=========================================="
    echo "✓ SUCCESS: Cluster 'logwise' is registered!"
    echo "=========================================="
    echo ""
    echo "Kafka Manager UI: http://localhost:9000"
    echo "Cluster name: logwise"
    echo ""
    exit 0
else
    echo ""
    echo "=========================================="
    echo "✗ ERROR: Cluster was not registered"
    echo "=========================================="
    echo ""
    echo "Check the logs:"
    echo "  docker logs lc_kafka_manager_init"
    echo ""
    echo "Or try manual registration via web UI:"
    echo "  http://localhost:9000"
    echo ""
    exit 1
fi

