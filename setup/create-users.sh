#!/usr/bin/env bash
set -euo pipefail

echo "Creating workshop users..."
echo "WARNING: this is super basic, for production clusters use LDAP"

# Create users user1 through user10
for i in {1..10}; do
    username="user${i}"
    password="nersc${i}"

    # Create user if doesn't exist
    if ! id "$username" &>/dev/null; then
        useradd -m -s /bin/bash "$username"
        echo "Created user: $username"
    else
        echo "User $username already exists"
    fi

    # Set password
    echo "${username}:${password}" | chpasswd
    echo "Set password for $username"

    # Create .ssh directory for the user
    mkdir -p /home/$username/.ssh
    chmod 700 /home/$username/.ssh
    chown -R $username:$username /home/$username/.ssh

    # Create a simple welcome message
    cat > /home/$username/README.txt <<EOF
Welcome to the SC25 Workshop!

Username: $username
Password: nersc${i}

You can:
- Submit Slurm jobs: sbatch myjob.sh
- Check job status: squeue
- Access via Open OnDemand: http://<LOGIN_NODE_IP>

Happy computing!
EOF
    chown $username:$username /home/$username/README.txt

done

echo "All users created successfully!"
