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
STACK_NAME=${STACK_NAME:-factorio-servers}

# Get public IP address
PUBLIC_IP=$(get_public_ip)

# Default parameter values
ECSAMI=${ECSAMI:-/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id}
FACTORIO_IMAGE_TAG=${FACTORIO_IMAGE_TAG:-latest}
INSTANCE_TYPE=${INSTANCE_TYPE:-m6a.large}
SPOT_PRICE=${SPOT_PRICE:-0.05}
KEY_PAIR_NAME=${KEY_PAIR_NAME:-""}
YOUR_IP=${YOUR_IP:-$PUBLIC_IP}
HOSTED_ZONE_ID=${HOSTED_ZONE_ID:-""}
ENABLE_RCON=${ENABLE_RCON:-false}
UPDATE_MODS_ON_START=${UPDATE_MODS_ON_START:-false}

# Server Specific variables

SERVER_STATE_1=${SERVER_STATE_1:-Stopped}
SERVER_STATE_2=${SERVER_STATE_2:-Stopped}
SERVER_STATE_3=${SERVER_STATE_3:-Stopped}
SERVER_STATE_4=${SERVER_STATE_4:-Stopped}
SERVER_STATE_5=${SERVER_STATE_5:-Stopped}
SERVER_STATE_6=${SERVER_STATE_6:-Stopped}
SERVER_STATE_7=${SERVER_STATE_7:-Stopped}
SERVER_STATE_8=${SERVER_STATE_8:-Stopped}
SERVER_STATE_9=${SERVER_STATE_9:-Stopped}
SERVER_STATE_10=${SERVER_STATE_10:-Stopped}
SERVER_STATE_11=${SERVER_STATE_11:-Stopped}
SERVER_STATE_12=${SERVER_STATE_12:-Stopped}
SERVER_STATE_13=${SERVER_STATE_13:-Stopped}
SERVER_STATE_14=${SERVER_STATE_14:-Stopped}
SERVER_STATE_15=${SERVER_STATE_15:-Stopped}
SERVER_STATE_16=${SERVER_STATE_16:-Stopped}
SERVER_STATE_17=${SERVER_STATE_17:-Stopped}
SERVER_STATE_18=${SERVER_STATE_18:-Stopped}
SERVER_STATE_19=${SERVER_STATE_19:-Stopped}
SERVER_STATE_20=${SERVER_STATE_20:-Stopped}
RECORD_NAME_1=${RECORD_NAME_1:-""}
RECORD_NAME_2=${RECORD_NAME_2:-""}
RECORD_NAME_3=${RECORD_NAME_3:-""}
RECORD_NAME_4=${RECORD_NAME_4:-""}
RECORD_NAME_5=${RECORD_NAME_5:-""}
RECORD_NAME_6=${RECORD_NAME_6:-""}
RECORD_NAME_7=${RECORD_NAME_7:-""}
RECORD_NAME_8=${RECORD_NAME_8:-""}
RECORD_NAME_9=${RECORD_NAME_9:-""}
RECORD_NAME_10=${RECORD_NAME_10:-""}
RECORD_NAME_11=${RECORD_NAME_11:-""}
RECORD_NAME_12=${RECORD_NAME_12:-""}
RECORD_NAME_13=${RECORD_NAME_13:-""}
RECORD_NAME_14=${RECORD_NAME_14:-""}
RECORD_NAME_15=${RECORD_NAME_15:-""}
RECORD_NAME_16=${RECORD_NAME_16:-""}
RECORD_NAME_17=${RECORD_NAME_17:-""}
RECORD_NAME_18=${RECORD_NAME_18:-""}
RECORD_NAME_19=${RECORD_NAME_19:-""}
RECORD_NAME_20=${RECORD_NAME_20:-""}

# The update command

update_stack() {
    aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --use-previous-template \
        --parameters \
        ParameterKey=ECSAMI,ParameterValue="$ECSAMI" \
        ParameterKey=FactorioImageTag,ParameterValue="$FACTORIO_IMAGE_TAG" \
        ParameterKey=InstanceType,ParameterValue="$INSTANCE_TYPE" \
        ParameterKey=SpotPrice,ParameterValue="$SPOT_PRICE" \
        ParameterKey=KeyPairName,ParameterValue="$KEY_PAIR_NAME" \
        ParameterKey=YourIp,ParameterValue="$YOUR_IP" \
        ParameterKey=HostedZoneId,ParameterValue="$HOSTED_ZONE_ID" \
        ParameterKey=EnableRcon,ParameterValue="$ENABLE_RCON" \
        ParameterKey=UpdateModsOnStart,ParameterValue="$UPDATE_MODS_ON_START" \
        ParameterKey=ServerState1,ParameterValue="$SERVER_STATE_1" \
        ParameterKey=RecordName1,ParameterValue="$RECORD_NAME_1" \
        ParameterKey=ServerState2,ParameterValue="$SERVER_STATE_2" \
        ParameterKey=RecordName2,ParameterValue="$RECORD_NAME_2" \
        ParameterKey=ServerState3,ParameterValue="$SERVER_STATE_3" \
        ParameterKey=RecordName3,ParameterValue="$RECORD_NAME_3" \
        ParameterKey=ServerState4,ParameterValue="$SERVER_STATE_4" \
        ParameterKey=RecordName4,ParameterValue="$RECORD_NAME_4" \
        ParameterKey=ServerState5,ParameterValue="$SERVER_STATE_5" \
        ParameterKey=RecordName5,ParameterValue="$RECORD_NAME_5" \
        ParameterKey=ServerState6,ParameterValue="$SERVER_STATE_6" \
        ParameterKey=RecordName6,ParameterValue="$RECORD_NAME_6" \
        ParameterKey=ServerState7,ParameterValue="$SERVER_STATE_7" \
        ParameterKey=RecordName7,ParameterValue="$RECORD_NAME_7" \
        ParameterKey=ServerState8,ParameterValue="$SERVER_STATE_8" \
        ParameterKey=RecordName8,ParameterValue="$RECORD_NAME_8" \
        ParameterKey=ServerState9,ParameterValue="$SERVER_STATE_9" \
        ParameterKey=RecordName9,ParameterValue="$RECORD_NAME_9" \
        ParameterKey=ServerState10,ParameterValue="$SERVER_STATE_10" \
        ParameterKey=RecordName10,ParameterValue="$RECORD_NAME_10" \
        ParameterKey=ServerState11,ParameterValue="$SERVER_STATE_11" \
        ParameterKey=RecordName11,ParameterValue="$RECORD_NAME_11" \
        ParameterKey=ServerState12,ParameterValue="$SERVER_STATE_12" \
        ParameterKey=RecordName12,ParameterValue="$RECORD_NAME_12" \
        ParameterKey=ServerState13,ParameterValue="$SERVER_STATE_13" \
        ParameterKey=RecordName13,ParameterValue="$RECORD_NAME_13" \
        ParameterKey=ServerState14,ParameterValue="$SERVER_STATE_14" \
        ParameterKey=RecordName14,ParameterValue="$RECORD_NAME_14" \
        ParameterKey=ServerState15,ParameterValue="$SERVER_STATE_15" \
        ParameterKey=RecordName15,ParameterValue="$RECORD_NAME_15" \
        ParameterKey=ServerState16,ParameterValue="$SERVER_STATE_16" \
        ParameterKey=RecordName16,ParameterValue="$RECORD_NAME_16" \
        ParameterKey=ServerState17,ParameterValue="$SERVER_STATE_17" \
        ParameterKey=RecordName17,ParameterValue="$RECORD_NAME_17" \
        ParameterKey=ServerState18,ParameterValue="$SERVER_STATE_18" \
        ParameterKey=RecordName18,ParameterValue="$RECORD_NAME_18" \
        ParameterKey=ServerState19,ParameterValue="$SERVER_STATE_19" \
        ParameterKey=RecordName19,ParameterValue="$RECORD_NAME_19" \
        ParameterKey=ServerState20,ParameterValue="$SERVER_STATE_20" \
        ParameterKey=RecordName20,ParameterValue="$RECORD_NAME_20" \
        --capabilities CAPABILITY_IAM
}

update_stack
