#!/usr/bin/env bash
# Build and run the app container locally so you can sanity-check it
# before it goes anywhere near the pipeline.
#
# Usage: ./local-test.sh

set -euo pipefail

IMAGE_NAME="devops-portfolio-local"
PORT="${PORT:-8080}"

echo "Building image..."
docker build -t "$IMAGE_NAME" -f app/Dockerfile app/

echo "Running container on port $PORT..."
docker run --rm -d \
  -p "${PORT}:8080" \
  -e APP_VERSION="local-test" \
  -e DEPLOY_COLOR="local" \
  --name "$IMAGE_NAME" \
  "$IMAGE_NAME"

echo "Waiting for container to become healthy..."
sleep 3

echo "Hitting /health:"
curl -sf "http://localhost:${PORT}/health" && echo

echo "Hitting /:"
curl -sf "http://localhost:${PORT}/" && echo

echo ""
echo "Container is running. Stop it with: docker stop ${IMAGE_NAME}"
