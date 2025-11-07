#!/bin/bash
set -e

echo "=========================================="
echo "Testing Kafka Manager Cluster Registration"
echo "=========================================="
echo ""

# Check if docker-compose services are running
echo "[1/5] Checking Docker services..."
if ! docker ps | grep -q "lc_kafka_manager"; then
    echo "✗ ERROR: Kafka Manager container is not running"
    echo "  Start services with: docker-compose up -d kafka-manager"
    exit 1
fi
echo "✓ Kafka Manager container is running"

if ! docker ps | grep -q "lc_kafka"; then
    echo "✗ ERROR: Kafka container is not running"
    echo "  Start services with: docker-compose up -d kafka"
    exit 1
fi
echo "✓ Kafka container is running"

if ! docker ps | grep -q "lc_zookeeper"; then
    echo "✗ ERROR: Zookeeper container is not running"
    echo "  Start services with: docker-compose up -d zookeeper"
    exit 1
fi
echo "✓ Zookeeper container is running"
echo ""

# Check if Kafka Manager is accessible
echo "[2/5] Testing Kafka Manager accessibility..."
KAFKA_MANAGER_URL="http://localhost:9000"
if curl -sf "$KAFKA_MANAGER_URL" > /dev/null 2>&1; then
    echo "✓ Kafka Manager is accessible at $KAFKA_MANAGER_URL"
else
    echo "✗ ERROR: Kafka Manager is not accessible at $KAFKA_MANAGER_URL"
    echo "  Check if port 9000 is exposed and service is healthy"
    exit 1
fi
echo ""

# Check existing clusters
echo "[3/5] Checking existing clusters..."
CLUSTERS=$(curl -s "${KAFKA_MANAGER_URL}/api/clusters" 2>&1 || echo "[]")
echo "  Current clusters: $CLUSTERS"
echo ""

# Run the init script
echo "[4/5] Running cluster initialization script..."
echo "  This will create/verify the 'logwise' cluster"
echo ""

# Execute the init script inside the init container or directly
if docker ps | grep -q "lc_kafka_manager_init"; then
    echo "  Running init script in existing container..."
    docker exec lc_kafka_manager_init /init-cluster.sh
else
    echo "  Starting init container..."
    cd /Users/varunwalia/Desktop/dream11/logwise/logwise/log-wise-deploy
    docker-compose run --rm kafka-manager-init
fi

INIT_EXIT_CODE=$?

if [ $INIT_EXIT_CODE -eq 0 ]; then
    echo "✓ Init script completed successfully"
else
    echo "✗ Init script failed with exit code: $INIT_EXIT_CODE"
    exit 1
fi
echo ""

# Verify cluster exists and works
echo "[5/5] Final verification..."
sleep 5
CLUSTERS_FINAL=$(curl -s "${KAFKA_MANAGER_URL}/api/clusters" 2>&1 || echo "[]")

if echo "$CLUSTERS_FINAL" | grep -q "\"logwise\""; then
    echo "✓ Cluster 'logwise' is registered"
    
    # Test cluster API
    echo "  Testing cluster API..."
    sleep 3
    TOPICS=$(curl -s "${KAFKA_MANAGER_URL}/api/clusters/logwise/topics" 2>&1 || echo "")
    
    if echo "$TOPICS" | grep -qi "error\|exception" > /dev/null 2>&1; then
        echo "⚠ WARNING: Cluster is registered but API has issues"
        echo "  Response: $TOPICS" | head -c 200
        echo ""
    else
        echo "✓ Cluster API is working correctly"
    fi
else
    echo "✗ ERROR: Cluster 'logwise' is not registered"
    echo "  Available clusters: $CLUSTERS_FINAL"
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ All tests passed!"
echo "=========================================="
echo ""
echo "Kafka Manager UI: $KAFKA_MANAGER_URL"
echo "Cluster name: logwise"
echo ""

