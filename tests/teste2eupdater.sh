#!/bin/bash
set -e # Exit on any error
# Set default values that can be overridden by environment variables
STACK_NAME=${STACK_NAME:-"factorio-server-test"}
REGION="us-east-1"
FACTORIO_IMAGE_TAG=${FACTORIO_IMAGE_TAG:-"2.0.30"}
SERVER_STATE=${SERVER_STATE:-"Running"}
HOSTED_ZONE_ID=${HOSTED_ZONE_ID:-""}
RECORD_NAME=${RECORD_NAME:-""}

function get_versions() {
  echo "\n🔍 Getting current stack parameters..."
  STACK_VERSION=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Parameters[?ParameterKey==`FactorioImageTag`].ParameterValue' \
    --output text)

  echo "📦 Getting ECS cluster name..."
  CLUSTER_NAME="${STACK_NAME}-cluster"

  echo "🚀 Getting ECS service name..."
  SERVICE_NAME="${STACK_NAME}-ecs-service"

  echo "⏳ Waiting for service to stabilize..."
  aws ecs wait services-stable \
    --cluster "${CLUSTER_NAME}" \
    --services "${SERVICE_NAME}"

  echo "🐳 Getting running container version..."
  TASK_ARN=$(aws ecs list-tasks \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --query 'taskArns[0]' \
    --output text)

  CONTAINER_VERSION=$(aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $TASK_ARN \
    --query 'tasks[0].containers[0].image' \
    --output text | cut -d':' -f2)

  echo "\n📊 Current versions:"
  echo "├─ Stack parameter version: $STACK_VERSION"
  echo "└─ Running container version: $CONTAINER_VERSION"
  echo "----------------------------------------\n"
}

function invoke_updater() {
  echo "🔍 Looking for AutoUpdate Lambda in stack: $STACK_NAME"
  LAMBDA_NAME=$(aws cloudformation describe-stack-resources \
    --stack-name $STACK_NAME \
    --query "StackResources[?ResourceType=='AWS::Lambda::Function' && contains(LogicalResourceId, 'AutoUpdate')].PhysicalResourceId" \
    --output text)

  if [ -z "$LAMBDA_NAME" ]; then
    echo "❌ AutoUpdate Lambda function not found in stack. This might be because:"
    echo "  - The stack name is incorrect"
    echo "  - Auto-updates were not enabled for this stack"
    echo "  - The Lambda function hasn't been created yet"
    exit 1
  fi

  echo "📦 Found Lambda: $LAMBDA_NAME"
  echo "------------------------------------------------"

  # Invoke the Lambda function
  echo "🚀 Invoking Lambda function..."
  local payload='{
    "source": "aws.events",
    "detail-type": "Scheduled Event",
    "detail": {}
  }'
  RESPONSE=$(aws lambda invoke \
    --log-type Tail \
    --cli-read-timeout 0 \
    --function-name "$LAMBDA_NAME" \
    --payload "$(echo "$payload" | base64)" \
    /dev/stdout)
  # Print the response regardless of exit code

  if [ $? -eq 0 ]; then
    echo "✅ Lambda function executed successfully"
    echo "------------------------------------------------"

    # Extract components using regex patterns
    RESPONSE_JSON=$(echo "$RESPONSE" | sed -E 's/^(.*)\$LATEST.*[[:space:]]+[^[:space:]]+$/\1/')
    BASE64_LOGS=$(echo "$RESPONSE" | sed -E 's/^.*\$LATEST[[:space:]]+([^[:space:]]+)[[:space:]]+[0-9]+$/\1/')
    STATUS_CODE=$(echo "$RESPONSE" | sed -E 's/^.*[[:space:]]+([0-9]+)$/\1/')

    # Parse and display the response JSON
    echo "📊 Response:"
    echo "$RESPONSE_JSON" | jq -r '.body' | jq '.'
    echo

    # Decode and display the logs
    echo "📝 Execution Logs:"
    echo "$BASE64_LOGS" | base64 -d
    echo

    # Display the status code
    echo "🔢 Status Code: $STATUS_CODE"
    echo "------------------------------------------------"
  else
    echo "❌ Failed to invoke Lambda function"
    exit 1
  fi

  # Check if response contains statusCode 200
  if [ "$(echo "$RESPONSE_JSON" | jq -r '.statusCode')" -eq 200 ]; then
    echo "✅ Update check completed successfully"
  else
    echo "❌ Update check failed - response did not indicate success"
    exit 1
  fi
}

function create_stack() {

  aws cloudformation deploy \
    --template-file cf.yml \
    --stack-name $STACK_NAME --capabilities CAPABILITY_IAM \
    --parameter-overrides \
    FactorioImageTag=$FACTORIO_IMAGE_TAG \
    ServerState=$SERVER_STATE \
    InstancePurchaseMode=Spot \
    InstanceType="" \
    SpotPrice=0.05 \
    SpotMinMemoryMiB=2048 \
    SpotMinVCpuCount=2 \
    KeyPairName="factorio-server" \
    YourIp="" \
    HostedZoneId=$HOSTED_ZONE_ID \
    RecordName=$RECORD_NAME \
    EnableRcon=false \
    DlcSpaceAge=true \
    UpdateModsOnStart=true \
    AutoUpdateServer=true
  echo "Waiting for stack creation to complete..."
  aws cloudformation wait stack-create-complete --stack-name $STACK_NAME

  wait_for_stack_update
}

function wait_for_stack_update() {
  echo "⏳ Waiting for stack update to complete..."
  while true; do
    STATUS=$(aws cloudformation describe-stacks \
      --stack-name $STACK_NAME \
      --query 'Stacks[0].StackStatus' \
      --output text)

    echo "📊 Current stack status: $STATUS"

    # Check if we've reached a final state
    case $STATUS in
    *COMPLETE | *FAILED)
      break
      ;;
    esac

    sleep 10
  done

  # Check if the final state is a failure
  if [[ $STATUS == *"ROLLBACK_COMPLETE"* ]]; then
    echo "❌ Stack update failed and rolled back"
    exit 1
  elif [[ $STATUS == *"COMPLETE"* ]]; then
    echo "✅ Stack update completed successfully"
  else
    echo "❌ Stack update failed with status: $STATUS"
    exit 1
  fi
}

function do_test() {

  echo "🚀 Step 1: Creating initial stack with version 2.0.30..."
  create_stack

  echo "\n📊 Initial state:"
  get_versions

  echo "🔄 Step 2: Running auto-updater lambda for the first time..."
  echo "📦 Running auto-updater lambda..."
  invoke_updater

  wait_for_stack_update

  echo "\n📊 State after first update:"
  get_versions

  echo "🔄 Step 3: Running auto-updater lambda for the second time..."
  invoke_updater

  wait_for_stack_update

  echo "\n📊 State after second update:"
  get_versions

  echo "✅ Test complete!\n"
}

if [ -z "$SKIP_E2E_TEST" ]; then
  do_test
else
  echo "⏭️ Skipping E2E test due to SKIP_E2E_TEST being set"
fi
