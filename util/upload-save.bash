#!/bin/bash

# Check if both arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <path_to_MySave.zip> <ec2_address>"
    exit 1
fi

# Get the file path and EC2 address from command line arguments
save_file="$1"
ec2_address="$2"

# Check if the file exists
if [ ! -f "$save_file" ]; then
    echo "File not found: $save_file"
    exit 1
fi

# Upload the save file to the EC2 instance
echo "Uploading save file to EC2 instance..."
scp "$save_file" "ec2-user@$ec2_address:~/"

# SSH into the EC2 instance and perform the required operations
ssh "ec2-user@$ec2_address" << EOF
    # Get the Factorio container ID
    container_id=\$(docker ps | grep factoriotools/factorio | awk '{print \$1}' | cut -c1-3)

    if [ -z "\$container_id" ]; then
        echo "Factorio container not found"
        exit 1
    fi

    echo "Factorio container ID: \$container_id"

    # Find the save directory
    savedir=\$(mount | grep nfs4 | cut -f3 -d ' ' | xargs -I {} echo "{}/saves")
    echo "Save directory: \$savedir"

    # Move the uploaded save to the right location
    sudo mv ~/$(basename "$save_file") \$savedir

    # Touch the save file to update its timestamp
    sudo touch \$savedir/$(basename "$save_file")

    # Force kill the Factorio docker container
    echo "Killing Factorio container..."
    docker kill \$container_id

    echo "Save file uploaded and container restarted. Please wait 30 seconds for the server to come back online."
EOF

echo "Script completed. The server should load your new save file when it restarts."