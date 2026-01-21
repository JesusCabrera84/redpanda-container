#!/bin/bash
# Remove set -e to handle idempotent operations manually
# set -e

# Helper function to wait for Redpanda Admin API
wait_for_admin() {
  echo "Waiting for Redpanda Admin API on 9644..."
  local count=0
  until curl -s http://localhost:9644/v1/status/ready | grep "ready" > /dev/null 2>&1 || [ $count -eq 60 ]; do
    sleep 2
    count=$((count + 1))
  done
  if [ $count -eq 60 ]; then
    echo "Timeout waiting for Redpanda Admin API"
    curl -v http://localhost:9644/v1/status/ready || true
    exit 1
  fi
}

# Helper function to wait for Redpanda Kafka API
wait_for_kafka() {
  local flags=$1
  echo "Waiting for Redpanda Kafka API on 9092..."
  local count=0
  until rpk cluster info --brokers localhost:9092 $flags > /dev/null 2>&1 || [ $count -eq 60 ]; do
    sleep 2
    count=$((count + 1))
  done
  if [ $count -eq 60 ]; then
    echo "Timeout waiting for Redpanda Kafka API"
    exit 1
  fi
}

# Helper function to clear pid lock
clear_pid_lock() {
  if [ -f /var/lib/redpanda/data/pid.lock ]; then
    echo "Removing stale pid.lock..."
    rm -f /var/lib/redpanda/data/pid.lock
  fi
}

echo "[1/4] Starting Redpanda (Initial Setup)..."
clear_pid_lock
rpk redpanda start --overprovisioned --smp 1 --memory 1G --reserve-memory 0M --node-id "0" --check=false --kafka-addr PLAINTEXT://0.0.0.0:9092 --advertise-kafka-addr PLAINTEXT://localhost:9092 &
RP_PID=$!
wait_for_admin

echo "[2/4] Enabling SASL and Restarting..."
# Set config and ignore if already set to same value
rpk cluster config set enable_sasl true || true
kill $RP_PID || true
sleep 5
clear_pid_lock

rpk redpanda start --overprovisioned --smp 1 --memory 1G --reserve-memory 0M --node-id 0 --check=false --kafka-addr SASL_PLAINTEXT://0.0.0.0:9092 --advertise-kafka-addr SASL_PLAINTEXT://localhost:9092 &
RP_PID=$!
wait_for_admin

echo "[3/4] Creating Superuser and Configuring..."
# Create user and ignore if already exists
rpk security user create superuser -p secretpassword --mechanism SCRAM-SHA-256 --api-urls 127.0.0.1:9644 || echo "Superuser might already exist"
rpk cluster config set superusers "['superuser']" -X admin.hosts=127.0.0.1:9644 || true

# Restart to apply superuser
kill $RP_PID || true
sleep 5
clear_pid_lock

rpk redpanda start --overprovisioned --smp 1 --memory 1G --reserve-memory 0M --node-id 0 --check=false --kafka-addr SASL_PLAINTEXT://0.0.0.0:9092 --advertise-kafka-addr SASL_PLAINTEXT://localhost:9092 &
RP_PID=$!
wait_for_admin
wait_for_kafka "-X sasl.mechanism=SCRAM-SHA-256 -X user=superuser -X pass=secretpassword"

echo "[4/4] Creating App Users, Topics, and ACLs..."
rpk security user create siscom-producer -p producerpassword --mechanism SCRAM-SHA-256 || echo "siscom-producer already exists"
rpk security user create siscom-consumer -p consumerpassword --mechanism SCRAM-SHA-256 || echo "siscom-consumer already exists"
rpk security user create siscom-live-consumer -p liveconsumerpassword --mechanism SCRAM-SHA-256 || echo "siscom-live-consumer already exists"

# Create topics individually and ignore "already exists" errors
for topic in siscom-messages siscom-minimal caudal-events caudal-live caudal-flows; do
  rpk topic create "$topic" \
    --brokers localhost:9092 \
    -X sasl.mechanism=SCRAM-SHA-256 -X user=superuser -X pass=secretpassword || echo "Topic $topic already exists"
done

# ACLs are generally idempotent in rpk
rpk security acl create --allow-principal User:siscom-producer --operation write,describe --topic siscom-messages -X user=superuser -X pass=secretpassword || true
rpk security acl create --allow-principal User:siscom-producer --operation write,describe --topic siscom-minimal -X user=superuser -X pass=secretpassword || true
rpk security acl create --allow-principal User:siscom-consumer --operation read,describe --topic siscom-messages -X user=superuser -X pass=secretpassword || true
rpk security acl create --allow-principal User:siscom-consumer --operation read,describe --group 'siscom-consumer-group' -X user=superuser -X pass=secretpassword || true
rpk security acl create --allow-principal User:siscom-live-consumer --operation read,describe --topic siscom-minimal -X user=superuser -X pass=secretpassword || true
rpk security acl create --allow-principal User:siscom-live-consumer --operation read,describe --group 'siscom-live-consumer-group' -X user=superuser -X pass=secretpassword || true

rpk cluster config set auto_create_topics_enabled false -X admin.hosts=127.0.0.1:9644 || true

echo "Redpanda setup finished successfully."

echo "Final Cluster Info:"
rpk cluster info \
  --brokers localhost:9092 \
  -X sasl.mechanism=SCRAM-SHA-256 \
  -X user=superuser \
  -X pass=secretpassword

wait $RP_PID
