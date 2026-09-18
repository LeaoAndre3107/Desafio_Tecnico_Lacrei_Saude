#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${ECS_CLUSTER:?ECS_CLUSTER is required}"
: "${ECS_SERVICE:?ECS_SERVICE is required}"
: "${TASK_FAMILY:?TASK_FAMILY is required}"
: "${IMAGE_URI:?IMAGE_URI is required}"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

aws ecs describe-task-definition \
  --region "$AWS_REGION" \
  --task-definition "$TASK_FAMILY" \
  --query 'taskDefinition' \
  --output json > "$workdir/task-definition.json"

jq --arg image "$IMAGE_URI" \
  '.containerDefinitions[0].image = $image
   | del(.taskDefinitionArn, .revision, .status, .requiresAttributes,
         .compatibilities, .registeredAt, .registeredBy)' \
  "$workdir/task-definition.json" > "$workdir/new-task-definition.json"

new_revision="$(aws ecs register-task-definition \
  --region "$AWS_REGION" \
  --cli-input-json "file://$workdir/new-task-definition.json" \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)"

echo "Registered task definition: $new_revision"

aws ecs update-service \
  --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --task-definition "$new_revision" \
  --force-new-deployment \
  --output json >/dev/null

aws ecs wait services-stable \
  --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE"

echo "ECS service is stable: $ECS_SERVICE"
