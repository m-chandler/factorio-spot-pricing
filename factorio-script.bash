SERVERS=$1

cat <<SCRIPT_BEGIN
#!/bin/bash

# Function to get public IP address
get_public_ip() {
    if command -v curl &> /dev/null; then
        curl -s ipinfo.io/ip
    elif command -v wget &> /dev/null; then
        wget -qO- ipinfo.io/ip
    elif command -v dig &> /dev/null; then
        dig +short myip.opendns.com @resolver1.opendns.com
    else
        echo ""
    fi
}

# Default stack name
STACK_NAME=\${STACK_NAME:-factorio-servers}

# Get public IP address
PUBLIC_IP=\$(get_public_ip)

# Default parameter values
ECSAMI=\${ECSAMI:-/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id}
FACTORIO_IMAGE_TAG=\${FACTORIO_IMAGE_TAG:-latest}
INSTANCE_TYPE=\${INSTANCE_TYPE:-m6a.large}
SPOT_PRICE=\${SPOT_PRICE:-0.05}
KEY_PAIR_NAME=\${KEY_PAIR_NAME:-""}
YOUR_IP=\${YOUR_IP:-\$PUBLIC_IP}
HOSTED_ZONE_ID=\${HOSTED_ZONE_ID:-""}
ENABLE_RCON=\${ENABLE_RCON:-false}
UPDATE_MODS_ON_START=\${UPDATE_MODS_ON_START:-false}
SCRIPT_BEGIN

cat <<HEADER

# Server Specific variables

HEADER

for i in $(seq 1 $SERVERS)
do
cat <<VAR_PARAMS
SERVER_STATE_${i}=\${SERVER_STATE_${i}:-Stopped}
VAR_PARAMS
done

for i in $(seq 1 $SERVERS)
do
cat <<VAR_PARAMS
RECORD_NAME_${i}=\${RECORD_NAME_${i}:-""}
VAR_PARAMS
done

cat <<UPDATE_COMMAND

# The update command

update_stack() {
    aws cloudformation update-stack \\
        --stack-name "\$STACK_NAME" \\
        --use-previous-template \\
        --parameters \\
        ParameterKey=ECSAMI,ParameterValue="\$ECSAMI" \\
        ParameterKey=FactorioImageTag,ParameterValue="\$FACTORIO_IMAGE_TAG" \\
        ParameterKey=InstanceType,ParameterValue="\$INSTANCE_TYPE" \\
        ParameterKey=SpotPrice,ParameterValue="\$SPOT_PRICE" \\
        ParameterKey=KeyPairName,ParameterValue="\$KEY_PAIR_NAME" \\
        ParameterKey=YourIp,ParameterValue="\$YOUR_IP" \\
        ParameterKey=HostedZoneId,ParameterValue="\$HOSTED_ZONE_ID" \\
        ParameterKey=EnableRcon,ParameterValue="\$ENABLE_RCON" \\
        ParameterKey=UpdateModsOnStart,ParameterValue="\$UPDATE_MODS_ON_START" \\
UPDATE_COMMAND

for i in $(seq 1 $SERVERS)
do
cat <<VAR_PARAMS
        ParameterKey=ServerState${i},ParameterValue="\$SERVER_STATE_${i}" \\
        ParameterKey=RecordName${i},ParameterValue="\$RECORD_NAME_${i}" \\
VAR_PARAMS
done

cat <<SCRIPT_END
        --capabilities CAPABILITY_IAM
}

update_stack
SCRIPT_END
