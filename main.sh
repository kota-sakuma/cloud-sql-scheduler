#!/bin/bash

### Environment variables
INSTANCES="${INSTANCES}" # Comma-separated list of Cloud SQL instances
PROJECT_ID="${PROJECT_ID}"
REGION="${REGION:-asia-northeast1}"
START_SCHEDULE="${START_SCHEDULE:-0 9 * * 1-5}" # 9:00 AM, Monday to Friday
STOP_SCHEDULE="${STOP_SCHEDULE:-0 18 * * 1-5}"  # 6:00 PM, Monday to Friday
TIMEZONE="${TIMEZONE:-Asia/Tokyo}"

### Usage
usage() {
  echo "Usage: $0 [deploy|delete]"
  echo "  deploy: Deploy Cloud Pub/Sub, Cloud Function, and Cloud Scheduler."
  echo "  delete: Delete Cloud Pub/Sub, Cloud Function, and Cloud Scheduler."
  exit 1
}

### Validate the required environment variables
validate_envs() {
  if [ -z "${PROJECT_ID}" ]; then
    echo "PROJECT_ID is not set."
    exit 1
  fi

  if [ -z "${INSTANCES}" ]; then
    echo "INSTANCES is not set."
    exit 1
  fi

  local regex="^[a-zA-Z0-9_-]+(,[a-zA-Z0-9_-]+)*$"

  if [[ ! "${INSTANCES}" =~ ${regex} ]]; then
    echo "Invalid INSTANCES format: ${INSTANCES}"
    exit 1
  fi
}

### Deploy Cloud Pub/Sub
deploy_pubsub() {
  echo "Creating Pub/Sub topic, 'cloud-sql-scheduler'..."
  gcloud pubsub topics create "cloud-sql-scheduler" \
    --project="${PROJECT_ID}" \
  || echo "Failed to create Pub/Sub topic, 'cloud-sql-scheduler'."
}

### Delete Cloud Pub/Sub
delete_pubsub() {
  echo "Deleting Pub/Sub topic, 'cloud-sql-scheduler'..."
  gcloud pubsub topics delete "cloud-sql-scheduler" \
    --project="${PROJECT_ID}" \
  || echo "Failed to delete Pub/Sub topic, 'cloud-sql-scheduler'."
}

### Deploy Cloud Function
deploy_function() {
  echo "Creating a Cloud Function, 'cloud-sql-scheduler'..."
  gcloud functions deploy "cloud-sql-scheduler" \
    --runtime="go122" \
    --trigger-topic="cloud-sql-scheduler" \
    --entry-point="ProcessPubSub" \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --set-env-vars="TIMEZONE=${TIMEZONE}" \
    --gen2 \
  || echo "Failed to create Cloud Function, 'cloud-sql-scheduler'."
}

### Delete Cloud Function
delete_function() {
  echo "Deleting Cloud Function, 'cloud-sql-scheduler'..."
  gcloud functions delete "cloud-sql-scheduler" \
    --project="${PROJECT_ID}" \
    --region="${REGION}" \
    --quiet \
  || echo "Failed to delete Cloud Function, 'cloud-sql-scheduler'."
}

### Deploy Cloud Scheduler
deploy_scheduler() {
  local action="$1"
  local schedule=""

  if [ "${action}" == "start" ]; then
    schedule="${START_SCHEDULE}"
  elif [ "${action}" == "stop" ]; then
    schedule="${STOP_SCHEDULE}"
  fi

  echo "Creating a Cloud Scheduler job, '${action}-cloud-sql'..."
  gcloud scheduler jobs create pubsub "${action}-cloud-sql" --location="${REGION}"\
    --schedule="${schedule}" \
    --time-zone="${TIMEZONE}" \
    --topic="cloud-sql-scheduler" \
    --location="${REGION}" \
    --message-body="{
      \"Action\":\"${action}\",
      \"Instance\":\"${INSTANCES}\",
      \"Project\":\"${PROJECT_ID}\"
    }" \
    --project="${PROJECT_ID}" \
  || echo "Failed to create Cloud Scheduler job, '${action}-cloud-sql'."
}

### Delete Cloud Scheduler
delete_scheduler() {
  local action="$1"

  echo "Deleting Cloud Scheduler job, '${action}-cloud-sql'..."
  gcloud scheduler jobs delete "${action}-cloud-sql" \
    --project="${PROJECT_ID}" \
    --location="${REGION}" \
    --quiet \
  || echo "Failed to delete Cloud Scheduler job, '${action}-cloud-sql'."
}

### Check if the Cloud SQL Admin API is enabled
check_api() {
  local api="sqladmin.googleapis.com"
  local status

  status=$(gcloud services list \
              --project="${PROJECT_ID}" \
              --enabled \
              --format="value(config.name)" \
              --filter="config.name:${api}")
  echo "Checking if the Cloud SQL Admin API is enabled..."

  if [ "${status}" != "${api}" ]; then
    echo "Enabling the Cloud SQL Admin API..."
    gcloud services enable "${api}" \
      --project="${PROJECT_ID}" \
    || echo "Failed to enable the Cloud SQL Admin API."
  else
    echo "The Cloud SQL Admin API is already enabled."
  fi
}


### Deploy Instances
deploy() {
  check_api
  deploy_pubsub
  deploy_function
  deploy_scheduler "start"
  deploy_scheduler "stop"
}

### Delete Instances
delete() {
  delete_scheduler "start"
  delete_scheduler "stop"
  delete_function
  delete_pubsub
}


### Main

# Check if there are any arguments
if [ "$#" -ne 1 ]; then
  usage
fi

# Validate the required environment variables
validate_envs

# Check if the action is valid
if [ "$1" == "deploy" ]; then
  deploy
elif [ "$1" == "delete" ]; then
  delete
else
  echo "Invalid action: $1"
  usage
  exit 1
fi