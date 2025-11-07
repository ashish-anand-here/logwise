#!/bin/sh
set -euo pipefail

KAFKA_MANAGER_HOST="${KAFKA_MANAGER_HOST:-kafka-manager}"
KAFKA_MANAGER_PORT="${KAFKA_MANAGER_PORT:-9000}"
KAFKA_MANAGER_URL="http://${KAFKA_MANAGER_HOST}:${KAFKA_MANAGER_PORT}"
ZK_HOSTS="${ZK_HOSTS:-zookeeper:2181}"
CLUSTER_NAME="${CLUSTER_NAME:-logwise}"
KAFKA_VERSION="${KAFKA_VERSION:-2.4.0}"

echo "=========================================="
echo "Kafka Manager Cluster Initialization"
echo "=========================================="
echo "Cluster Name: ${CLUSTER_NAME}"
echo "Zookeeper: ${ZK_HOSTS}"
echo "Kafka Version: ${KAFKA_VERSION}"
echo "Kafka Manager URL: ${KAFKA_MANAGER_URL}"
echo ""

# Wait for Kafka Manager to be ready
echo "[1/6] Waiting for Kafka Manager to be ready..."
max_attempts=120
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if curl -sf "${KAFKA_MANAGER_URL}" > /dev/null 2>&1; then
        echo "✓ Kafka Manager web interface is accessible"
        break
    fi
    attempt=$((attempt + 1))
    if [ $((attempt % 10)) -eq 0 ]; then
        echo "  Still waiting... (attempt $attempt/$max_attempts)"
    fi
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "✗ ERROR: Kafka Manager did not become ready after $max_attempts attempts"
    exit 1
fi

# Wait a bit for Kafka Manager to fully initialize
echo "[2/6] Waiting for Kafka Manager to fully initialize..."
sleep 15

# Check existing clusters by checking the main page
echo "[3/6] Checking existing clusters..."
MAIN_PAGE=$(curl -s "${KAFKA_MANAGER_URL}/" 2>&1 || echo "")

if echo "$MAIN_PAGE" | grep -qi "\"${CLUSTER_NAME}\"\|>${CLUSTER_NAME}<\|href.*${CLUSTER_NAME}" > /dev/null 2>&1; then
    echo "✓ Cluster '${CLUSTER_NAME}' already exists"
    echo "  Cluster is visible in Kafka Manager"
    exit 0
fi

echo "[4/6] Cluster does not exist, creating new cluster..."

# Get the add cluster page to extract CSRF token and session cookie
COOKIE_JAR=$(mktemp)
echo "[5/6] Fetching add cluster page..."
PAGE_RESPONSE=$(curl -s -c "$COOKIE_JAR" -L "${KAFKA_MANAGER_URL}/addCluster" 2>&1)

if [ $? -ne 0 ]; then
    echo "✗ ERROR: Failed to fetch add cluster page"
    rm -f "$COOKIE_JAR"
    exit 1
fi

# Extract CSRF token - try multiple methods
CSRF_TOKEN=""

# Method 1: Look for hidden input with name="csrfToken"
CSRF_TOKEN=$(echo "$PAGE_RESPONSE" | grep -o 'name="csrfToken"[^>]*value="[^"]*"' | sed 's/.*value="\([^"]*\)".*/\1/' | head -1 || echo "")

# Method 2: Look for any input with csrfToken in the value
if [ -z "$CSRF_TOKEN" ]; then
    CSRF_TOKEN=$(echo "$PAGE_RESPONSE" | grep -i 'csrf' | grep -o 'value="[^"]*"' | head -1 | sed 's/value="\([^"]*\)"/\1/' || echo "")
fi

# Method 3: Look for csrfToken in meta tags or script tags
if [ -z "$CSRF_TOKEN" ]; then
    CSRF_TOKEN=$(echo "$PAGE_RESPONSE" | grep -o 'csrfToken[^"]*"[^"]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/' | head -1 || echo "")
fi

if [ -n "$CSRF_TOKEN" ]; then
    echo "✓ Found CSRF token (length: ${#CSRF_TOKEN})"
else
    echo "⚠ WARNING: Could not extract CSRF token from page"
    echo "  Attempting to proceed without explicit CSRF token..."
    echo "  (Kafka Manager may accept the request with session cookie only)"
fi

# Build form data - use the exact form fields from the page
echo "[6/6] Submitting cluster creation request..."
FORM_DATA="name=${CLUSTER_NAME}&zkHosts=${ZK_HOSTS}&kafkaVersion=${KAFKA_VERSION}&securityProtocol=PLAINTEXT&jmxEnabled=true&jmxUser=&jmxPass=&jmxSsl=false&pollConsumers=true&filterConsumers=true&activeOffsetCacheEnabled=false&displaySizeEnabled=false&tuning.brokerViewUpdatePeriodSeconds=30&tuning.clusterManagerThreadPoolSize=2&tuning.clusterManagerThreadPoolQueueSize=100&tuning.kafkaCommandThreadPoolSize=2&tuning.kafkaCommandThreadPoolQueueSize=100&tuning.logkafkaCommandThreadPoolSize=2&tuning.logkafkaCommandThreadPoolQueueSize=100&tuning.logkafkaUpdatePeriodSeconds=30&tuning.partitionOffsetCacheTimeoutSecs=5&tuning.brokerViewThreadPoolSize=8&tuning.brokerViewThreadPoolQueueSize=1000&tuning.offsetCacheThreadPoolSize=8&tuning.offsetCacheThreadPoolQueueSize=1000&tuning.kafkaAdminClientThreadPoolSize=8&tuning.kafkaAdminClientThreadPoolQueueSize=1000&tuning.kafkaManagedOffsetMetadataCheckMillis=30000&tuning.kafkaManagedOffsetGroupCacheSize=1000000&tuning.kafkaManagedOffsetGroupExpireDays=7"

# Add CSRF token to form data if found
if [ -n "$CSRF_TOKEN" ]; then
    FORM_DATA="${FORM_DATA}&csrfToken=${CSRF_TOKEN}"
fi

# Build curl command
echo "  Submitting POST request to ${KAFKA_MANAGER_URL}/clusters..."
CURL_CMD="curl -s -w \"\n%{http_code}\" -b \"$COOKIE_JAR\" -c \"$COOKIE_JAR\" -L -X POST \"${KAFKA_MANAGER_URL}/clusters\" \
    -H \"Content-Type: application/x-www-form-urlencoded\" \
    -H \"Referer: ${KAFKA_MANAGER_URL}/addCluster\""

# Add X-CSRF-Token header if we have the token
if [ -n "$CSRF_TOKEN" ]; then
    CURL_CMD="${CURL_CMD} -H \"X-CSRF-Token: ${CSRF_TOKEN}\""
fi

# Add form data and execute
CURL_CMD="${CURL_CMD} -d \"$FORM_DATA\" 2>&1"
RESPONSE=$(eval "$CURL_CMD")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

rm -f "$COOKIE_JAR"

echo "  HTTP Response Code: $HTTP_CODE"

# Verify cluster was created by checking the main page
echo ""
echo "Verifying cluster registration..."
sleep 5

MAX_VERIFY_ATTEMPTS=15
VERIFY_ATTEMPT=0
CLUSTER_REGISTERED=false

while [ $VERIFY_ATTEMPT -lt $MAX_VERIFY_ATTEMPTS ]; do
    MAIN_PAGE_CHECK=$(curl -s "${KAFKA_MANAGER_URL}/" 2>&1 || echo "")
    
    if echo "$MAIN_PAGE_CHECK" | grep -qi "\"${CLUSTER_NAME}\"\|>${CLUSTER_NAME}<\|href.*${CLUSTER_NAME}" > /dev/null 2>&1; then
        CLUSTER_REGISTERED=true
        echo "✓ Cluster '${CLUSTER_NAME}' successfully registered!"
        break
    fi
    
    VERIFY_ATTEMPT=$((VERIFY_ATTEMPT + 1))
    if [ $VERIFY_ATTEMPT -lt $MAX_VERIFY_ATTEMPTS ]; then
        echo "  Waiting for cluster to appear... (attempt $VERIFY_ATTEMPT/$MAX_VERIFY_ATTEMPTS)"
        sleep 3
    fi
done

if [ "$CLUSTER_REGISTERED" = "false" ]; then
    echo "✗ ERROR: Cluster was not registered after submission"
    echo "  HTTP Code: $HTTP_CODE"
    echo "  Response body (first 500 chars):"
    echo "$BODY" | head -c 500
    echo ""
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check Kafka Manager logs: docker logs lc_kafka_manager"
    echo "  2. Try creating cluster manually via web UI: ${KAFKA_MANAGER_URL}/addCluster"
    echo "  3. Verify Zookeeper connectivity from Kafka Manager container"
    echo "  4. Check if cluster appears in web UI: ${KAFKA_MANAGER_URL}"
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ SUCCESS: Cluster '${CLUSTER_NAME}' is registered!"
echo "=========================================="
echo ""
echo "Kafka Manager UI: ${KAFKA_MANAGER_URL}"
echo "Cluster name: ${CLUSTER_NAME}"
echo ""
exit 0
