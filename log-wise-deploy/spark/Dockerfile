# Spark 3.1.2 Dockerfile optimized for Java JAR applications
# Using multi-stage build for better caching
FROM eclipse-temurin:8-jdk as base

# Set Spark version
ARG SPARK_VERSION=3.1.2
ARG HADOOP_VERSION=3.2

# Set environment variables
ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:${SPARK_HOME}/bin:${SPARK_HOME}/sbin
ENV SPARK_VERSION=${SPARK_VERSION}
# JAVA_HOME is already set in eclipse-temurin:8-jdk base image

# Install minimal dependencies for Java JAR applications only
# Removed: python3, python3-pip (not needed for Java apps)
RUN apt-get update --allow-releaseinfo-change && \
    apt-get install -y --no-install-recommends \
    curl \
    wget \
    bash \
    ca-certificates \
    file \
    && rm -rf /var/lib/apt/lists/*

# Create spark user and app directory (cached layer)
RUN groupadd -r spark && useradd -r -g spark spark && \
    mkdir -p /opt/app && \
    chown -R spark:spark /opt/app

# Download Spark in separate layer for better caching
FROM base as downloader
ARG SPARK_VERSION=3.1.2
ARG HADOOP_VERSION=3.2
RUN cd /tmp && \
    SPARK_FILE="spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" && \
    echo "Downloading Spark ${SPARK_VERSION}..." && \
    curl -L -f --connect-timeout 30 --max-time 600 --retry 2 --retry-delay 3 --progress-bar \
    -o "${SPARK_FILE}" \
    "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_FILE}" || \
    (echo "Primary mirror failed, trying Berkeley mirror..." && \
     curl -L -f --connect-timeout 30 --max-time 600 --retry 2 --retry-delay 3 --progress-bar \
     -o "${SPARK_FILE}" \
     "https://mirrors.ocf.berkeley.edu/apache/spark/spark-${SPARK_VERSION}/${SPARK_FILE}") && \
    echo "Verifying download..." && \
    file "${SPARK_FILE}" && \
    (file "${SPARK_FILE}" | grep -q "gzip\|POSIX tar" || (echo "ERROR: Invalid archive" && head -c 200 "${SPARK_FILE}" && exit 1))

# Final stage - extract and setup (optimized for Java JAR apps)
FROM base
ARG SPARK_VERSION=3.1.2
ARG HADOOP_VERSION=3.2
ARG HADOOP_AWS_VERSION=3.2.0
ARG AWS_SDK_VERSION=1.11.375
ARG SPARK_KAFKA_VERSION=3.1.2
ARG KAFKA_CLIENTS_VERSION=2.6.0
ARG SPARK_TOKEN_PROVIDER_VERSION=3.1.2
COPY --from=downloader /tmp/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz /tmp/
RUN cd /tmp && \
    SPARK_FILE="spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" && \
    echo "Extracting Spark..." && \
    tar -xzf "${SPARK_FILE}" && \
    mv spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} ${SPARK_HOME} && \
    rm "${SPARK_FILE}" && \
    # Remove Python-related directories to reduce image size (not needed for Java JAR apps)
    rm -rf ${SPARK_HOME}/python ${SPARK_HOME}/pyspark ${SPARK_HOME}/bin/pyspark* ${SPARK_HOME}/bin/spark-submit.cmd 2>/dev/null || true && \
    # Download and install required JARs for S3 and Kafka support
    echo "Downloading required JARs (Hadoop AWS, AWS SDK, Spark Kafka, Kafka Clients)..." && \
    cd ${SPARK_HOME}/jars && \
    # S3 support JARs
    curl -L -f --connect-timeout 30 --max-time 300 --retry 2 --retry-delay 3 --progress-bar \
    -o "hadoop-aws-${HADOOP_AWS_VERSION}.jar" \
    "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar" && \
    curl -L -f --connect-timeout 30 --max-time 300 --retry 2 --retry-delay 3 --progress-bar \
    -o "aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar" \
    "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar" && \
    # Kafka support JARs
    curl -L -f --connect-timeout 30 --max-time 300 --retry 2 --retry-delay 3 --progress-bar \
    -o "spark-sql-kafka-0-10_2.12-${SPARK_KAFKA_VERSION}.jar" \
    "https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.12/${SPARK_KAFKA_VERSION}/spark-sql-kafka-0-10_2.12-${SPARK_KAFKA_VERSION}.jar" && \
    curl -L -f --connect-timeout 30 --max-time 300 --retry 2 --retry-delay 3 --progress-bar \
    -o "spark-token-provider-kafka-0-10_2.12-${SPARK_TOKEN_PROVIDER_VERSION}.jar" \
    "https://repo1.maven.org/maven2/org/apache/spark/spark-token-provider-kafka-0-10_2.12/${SPARK_TOKEN_PROVIDER_VERSION}/spark-token-provider-kafka-0-10_2.12-${SPARK_TOKEN_PROVIDER_VERSION}.jar" && \
    curl -L -f --connect-timeout 30 --max-time 300 --retry 2 --retry-delay 3 --progress-bar \
    -o "kafka-clients-${KAFKA_CLIENTS_VERSION}.jar" \
    "https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/${KAFKA_CLIENTS_VERSION}/kafka-clients-${KAFKA_CLIENTS_VERSION}.jar" && \
    echo "Required JARs installed successfully" && \
    # Ensure proper permissions
    chown -R spark:spark ${SPARK_HOME} && \
    mkdir -p ${SPARK_HOME}/logs ${SPARK_HOME}/work && \
    chown -R spark:spark ${SPARK_HOME}/logs ${SPARK_HOME}/work && \
    # Create Spark worker configuration to set memory explicitly
    mkdir -p ${SPARK_HOME}/conf && \
    echo "spark.worker.memory 2048m" > ${SPARK_HOME}/conf/spark-defaults.conf && \
    echo "spark.worker.cores 2" >> ${SPARK_HOME}/conf/spark-defaults.conf && \
    chown -R spark:spark ${SPARK_HOME}/conf && \
    # Create app directory for JAR files
    mkdir -p /opt/app && \
    chown -R spark:spark /opt/app && \
    echo "Spark ${SPARK_VERSION} installed successfully (Java JAR optimized with S3 support)"

# Set working directory
WORKDIR ${SPARK_HOME}

# Run as root (matching apache/spark:latest behavior)
# This allows docker-compose commands to create directories and files
USER root

# Expose ports
# 7077: Spark master port
# 8080: Spark master web UI
# 8081: Spark worker web UI
# 6066: Spark REST API
EXPOSE 7077 8080 8081 6066

# Default command (can be overridden in docker-compose)
CMD ["/bin/bash"]
