#!/bin/bash

# Check if remote name is provided
if [ $# -ne 1 -a $# -ne 2 ]; then
    echo "Usage: $0 <remote_name> [optional_path_to_MyKey.pem]"
    exit 1
fi

remote_name="$1"
key_path=""

# Check if remote name is provided
if [ $# -eq 2 ]; then
    key_path="-i $2"
fi

# Generate a human-readable timestamp
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")



# SSH into the remote instance to find the most recent save file
ssh_output=$(ssh $key_path "ec2-user@$remote_name" << EOF
    # Record the current directory
    current_dir=\$(pwd)

    # Find the save directory
    savedir=\$(sudo mount | grep nfs4 | cut -f3 -d ' ' | xargs -I {} echo "{}/saves")
    echo "Save directory: \$savedir"

    if [ -z "\$savedir" ]; then
        echo "ERROR: Save directory not found"
        exit 1
    fi

    # Find the most recently modified file in the save directory
    latest_file=\$(sudo ls -t \$savedir | head -1)

    if [ -z "\$latest_file" ]; then
        echo "ERROR: No files found in the save directory"
        exit 1
    fi

    echo "Latest save file: \$latest_file"

    # Copy the latest file to the current directory
    sudo cp "\$savedir/\$latest_file" "\$current_dir/"

    # Change ownership of the copied file to ec2-user
    sudo chown ec2-user:ec2-user "\$current_dir/\$latest_file"

    echo "\$current_dir/\$latest_file"
EOF
)

# Check if there was an error in the SSH command
if echo "$ssh_output" | grep -q "ERROR:"; then
    echo "$ssh_output"
    exit 1
fi

# Extract the full path of the latest file
latest_file_path=$(echo "$ssh_output" | tail -n 1)

# Extract just the filename
latest_file=$(basename "$latest_file_path")

# Download the file from the remote instance to the current local directory with the new filename
new_filename="${remote_name}_${timestamp}_${latest_file}"
scp $key_path "ec2-user@$remote_name:$latest_file_path" "./$new_filename"

# Clean up the temporary file on the remote instance
ssh $key_path "ec2-user@$remote_name" "rm -f $latest_file_path"

echo "Download complete. The latest save file has been saved as '$new_filename' in your current directory."