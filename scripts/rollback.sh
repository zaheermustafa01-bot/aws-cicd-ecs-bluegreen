#!/usr/bin/env bash
# Manually stop an in-progress CodeDeploy deployment and roll back to the
# previous (blue) task set. Use this if auto-rollback didn't trigger or
# you need to abort a deployment mid-flight.
#
# Usage: ./rollback.sh <application-name> <deployment-group-name>

set -euo pipefail

APP_NAME="${1:?Usage: rollback.sh <application-name> <deployment-group-name>}"
DEPLOYMENT_GROUP="${2:?Usage: rollback.sh <application-name> <deployment-group-name>}"

echo "Looking up the most recent in-progress deployment for ${APP_NAME}/${DEPLOYMENT_GROUP}..."

DEPLOYMENT_ID=$(aws deploy list-deployments \
  --application-name "$APP_NAME" \
  --deployment-group-name "$DEPLOYMENT_GROUP" \
  --include-only-statuses "InProgress" \
  --query 'deployments[0]' \
  --output text)

if [ "$DEPLOYMENT_ID" == "None" ] || [ -z "$DEPLOYMENT_ID" ]; then
  echo "No in-progress deployment found. Nothing to roll back."
  exit 0
fi

echo "Found in-progress deployment: $DEPLOYMENT_ID"
echo "Stopping deployment and rolling back..."

aws deploy stop-deployment \
  --deployment-id "$DEPLOYMENT_ID" \
  --auto-rollback-enabled

echo "Rollback initiated. Check status with:"
echo "  aws deploy get-deployment --deployment-id $DEPLOYMENT_ID"
