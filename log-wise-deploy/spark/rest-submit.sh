#!/usr/bin/env bash
set -eu
# Don't use pipefail as it can cause issues with curl

# Config via env
SPARK_REST_URL=${SPARK_REST_URL:-http://spark-master:6066/v1/submissions/create}
# Default to local JAR mounted into spark-master at /opt/app/app.jar
# If APP_RESOURCE is set to a host path, convert it to container path
APP_RESOURCE=${APP_RESOURCE:-file:/opt/app/app.jar}
# Normalize path: if it's a file:// path with a host path, convert to container path
if [[ "$APP_RESOURCE" == file:///* ]] && [[ "$APP_RESOURCE" != file:///opt/app/* ]]; then
  # If it's a host path (starts with /Users, /home, etc.), convert to container path
  if [[ "$APP_RESOURCE" =~ ^file:///(Users|home|mnt) ]]; then
    echo "Warning: Host path detected in APP_RESOURCE, converting to container path: $APP_RESOURCE -> file:/opt/app/app.jar" >&2
    APP_RESOURCE=file:/opt/app/app.jar
  fi
fi
# Also check if APP_RESOURCE is a plain path without file:// prefix and convert
if [[ "$APP_RESOURCE" == /* ]] && [[ "$APP_RESOURCE" != /opt/app/* ]]; then
  if [[ "$APP_RESOURCE" =~ ^/(Users|home|mnt) ]]; then
    echo "Warning: Host path detected in APP_RESOURCE, converting to container path: $APP_RESOURCE -> file:/opt/app/app.jar" >&2
    APP_RESOURCE=file:/opt/app/app.jar
  fi
fi
# Ensure file:// prefix if not present and it's a local path
if [[ "$APP_RESOURCE" == /opt/app/* ]] && [[ "$APP_RESOURCE" != file:* ]]; then
  APP_RESOURCE="file:$APP_RESOURCE"
fi
MAIN_CLASS=${MAIN_CLASS:-}
APP_ARGS=${APP_ARGS:-}
TENANT_HEADER=${TENANT_HEADER:-X-Tenant-Name}
TENANT_VALUE=${TENANT_VALUE:-D11-Prod-AWS}

SPARK_MASTER_URL=${SPARK_MASTER_URL:-spark://spark-master:7077}
SPARK_APP_NAME=${SPARK_APP_NAME:-d11-log-management}
SPARK_CORES_MAX=${SPARK_CORES_MAX:-4}
SPARK_DRIVER_CORES=${SPARK_DRIVER_CORES:-1}
SPARK_DRIVER_MEMORY=${SPARK_DRIVER_MEMORY:-1G}
SPARK_EXECUTOR_CORES=${SPARK_EXECUTOR_CORES:-1}
SPARK_EXECUTOR_MEMORY=${SPARK_EXECUTOR_MEMORY:-1G}
SPARK_DEPLOY_MODE=${SPARK_DEPLOY_MODE:-cluster}
SPARK_DRIVER_SUPERVISE=${SPARK_DRIVER_SUPERVISE:-false}
SPARK_DRIVER_OPTS=${SPARK_DRIVER_OPTS:-}
SPARK_EXECUTOR_OPTS=${SPARK_EXECUTOR_OPTS:-}
SPARK_JARS=${SPARK_JARS:-$APP_RESOURCE}
CLIENT_SPARK_VERSION=${CLIENT_SPARK_VERSION:-3.1.2}

if [[ -z "$APP_RESOURCE" || -z "$MAIN_CLASS" ]]; then
  echo "APP_RESOURCE and MAIN_CLASS are required for REST submission" >&2
  exit 2
fi

# Build JSON arrays safely
ARGS_JSON="[]"
if [[ -n "$APP_ARGS" ]]; then
  IFS=',' read -ra ARR <<< "$APP_ARGS"
  FIRST=1
  ARGS_JSON="["
  for a in "${ARR[@]}"; do
    a="${a## }"; a="${a%% }"
    if [[ $FIRST -eq 1 ]]; then
      ARGS_JSON="$ARGS_JSON\"$a\""
      FIRST=0
    else
      ARGS_JSON="$ARGS_JSON,\"$a\""
    fi
  done
  ARGS_JSON="$ARGS_JSON]"
fi

# Build JSON body - use printf instead of heredoc to avoid issues with set -eu
BODY=$(printf '{
  "action": "CreateSubmissionRequest",
  "appArgs": %s,
  "appResource": "%s",
  "clientSparkVersion": "%s",
  "mainClass": "%s",
  "environmentVariables": {
    "SPARK_ENV_LOADED": "1",
    "%s": "%s"
  },
  "sparkProperties": {
    "spark.app.name": "%s",
    "spark.cores.max": "%s",
    "spark.driver.cores": "%s",
    "spark.driver.extraJavaOptions": "%s",
    "spark.driver.maxResultSize": "%s",
    "spark.driver.memory": "%s",
    "spark.driver.supervise": %s,
    "spark.executor.cores": "%s",
    "spark.executor.extraJavaOptions": "%s",
    "spark.executor.memory": "%s",
    "spark.jars": "%s",
    "spark.master": "%s",
    "spark.submit.deployMode": "%s"
  }
}' \
  "${ARGS_JSON}" \
  "${APP_RESOURCE}" \
  "${CLIENT_SPARK_VERSION}" \
  "${MAIN_CLASS}" \
  "${TENANT_HEADER}" \
  "${TENANT_VALUE}" \
  "${SPARK_APP_NAME}" \
  "${SPARK_CORES_MAX}" \
  "${SPARK_DRIVER_CORES}" \
  "${SPARK_DRIVER_OPTS}" \
  "${SPARK_DRIVER_MAX_RESULT_SIZE:-2G}" \
  "${SPARK_DRIVER_MEMORY}" \
  "${SPARK_DRIVER_SUPERVISE}" \
  "${SPARK_EXECUTOR_CORES}" \
  "${SPARK_EXECUTOR_OPTS}" \
  "${SPARK_EXECUTOR_MEMORY}" \
  "${SPARK_JARS}" \
  "${SPARK_MASTER_URL}" \
  "${SPARK_DEPLOY_MODE}")

echo "Submitting via REST to ${SPARK_REST_URL}"
echo "Request body (first 500 chars): ${BODY:0:500}..." >&2

# Wait for Spark Master REST API to be ready
echo "Waiting for Spark Master REST API to be ready..."
for i in {1..30}; do
  # Check if REST API endpoint is reachable (any response is OK, even error responses mean it's up)
  if curl -s "${SPARK_REST_URL%/*}/status" >/dev/null 2>&1; then
    echo "Spark Master REST API is ready"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "ERROR: Spark Master REST API not available after 30 attempts" >&2
    exit 1
  fi
  echo "Waiting... (attempt $i/30)"
  sleep 2
done

# Submit the job
echo "Submitting job..."
RESPONSE=$(curl -s -w "\n%{http_code}" -H 'Cache-Control: no-cache' -H 'Content-Type: application/json;charset=UTF-8' \
  --data "$BODY" "$SPARK_REST_URL" 2>&1) || {
  EXIT_CODE=$?
  echo "ERROR: curl failed with exit code: $EXIT_CODE" >&2
  echo "Response: $RESPONSE" >&2
  exit $EXIT_CODE
}

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY_RESPONSE=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status Code: $HTTP_CODE"
echo "Response: $BODY_RESPONSE"

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo "REST submission successful"
  exit 0
else
  echo "ERROR: REST submission failed with HTTP code: $HTTP_CODE" >&2
  echo "Response body: $BODY_RESPONSE" >&2
  exit 1
fi


