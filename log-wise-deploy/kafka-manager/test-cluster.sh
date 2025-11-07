#!/bin/sh
set -euo pipefail

KAFKA_MANAGER_HOST="${KAFKA_MANAGER_HOST:-kafka-manager}"
KAFKA_MANAGER_PORT="${KAFKA_MANAGER_PORT:-9000}"
KAFKA_MANAGER_URL="http://${KAFKA_MANAGER_HOST}:${KAFKA_MANAGER_PORT}"
ZK_HOSTS="${ZK_HOSTS:-zookeeper:2181}"
CLUSTER_NAME="${CLUSTER_NAME:-logwise}"
KAFKA_HOST="${KAFKA_HOST:-kafka}"
KAFKA_JMX_PORT="${KAFKA_JMX_PORT:-9999}"

echo "=== Testing Kafka Manager Cluster Configuration ==="
echo ""

# Test 1: Check if Kafka Manager is accessible
echo "1. Testing Kafka Manager accessibility..."
if curl -sf "${KAFKA_MANAGER_URL}" > /dev/null 2>&1; then
    echo "   ✓ Kafka Manager is accessible"
else
    echo "   ✗ Kafka Manager is NOT accessible"
    exit 1
fi

# Test 2: Check if cluster exists
echo "2. Checking if cluster '${CLUSTER_NAME}' exists..."
CLUSTERS=$(curl -s "${KAFKA_MANAGER_URL}/api/clusters" || echo "")
if echo "$CLUSTERS" | grep -q "\"${CLUSTER_NAME}\""; then
    echo "   ✓ Cluster '${CLUSTER_NAME}' exists"
else
    echo "   ✗ Cluster '${CLUSTER_NAME}' does NOT exist"
    echo "   Available clusters: $CLUSTERS"
fi

# Test 3: Check Zookeeper connectivity
echo "3. Testing Zookeeper connectivity..."
if nc -z -w 2 zookeeper 2181 2>/dev/null; then
    echo "   ✓ Zookeeper is reachable on zookeeper:2181"
else
    echo "   ✗ Zookeeper is NOT reachable on zookeeper:2181"
fi

# Test 4: Check Kafka broker connectivity
echo "4. Testing Kafka broker connectivity..."
if nc -z -w 2 kafka 9092 2>/dev/null; then
    echo "   ✓ Kafka broker is reachable on kafka:9092"
else
    echo "   ✗ Kafka broker is NOT reachable on kafka:9092"
fi

# Test 5: Check JMX port connectivity
echo "5. Testing Kafka JMX port connectivity..."
if nc -z -w 2 kafka 9999 2>/dev/null; then
    echo "   ✓ Kafka JMX port is reachable on kafka:9999"
else
    echo "   ✗ Kafka JMX port is NOT reachable on kafka:9999"
fi

# Test 6: Get cluster details
echo "6. Fetching cluster details..."
CLUSTER_DETAILS=$(curl -s "${KAFKA_MANAGER_URL}/api/clusters/${CLUSTER_NAME}" || echo "")
if [ -n "$CLUSTER_DETAILS" ] && echo "$CLUSTER_DETAILS" | grep -q "error" > /dev/null 2>&1; then
    echo "   ✗ Error fetching cluster details: $CLUSTER_DETAILS"
else
    echo "   ✓ Cluster details retrieved"
    echo "   Details: $CLUSTER_DETAILS" | head -c 200
    echo ""
fi

# Test 7: Check topics API
echo "7. Testing topics API..."
TOPICS=$(curl -s "${KAFKA_MANAGER_URL}/api/clusters/${CLUSTER_NAME}/topics" || echo "")
if [ -n "$TOPICS" ]; then
    echo "   ✓ Topics API responded"
    echo "   Response preview: $TOPICS" | head -c 200
    echo ""
else
    echo "   ✗ Topics API did not respond"
fi

echo ""
echo "=== Test Complete ==="

