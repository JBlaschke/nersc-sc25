#!/usr/bin/env bash
set -euo pipefail

echo "Creating workshop users..."

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

# Create a simple example job script
cat > /etc/skel/example-job.sh <<'EOF'
#!/bin/bash
#SBATCH --job-name=test
#SBATCH --output=output_%j.txt
#SBATCH --ntasks=1
#SBATCH --time=00:05:00
#SBATCH --partition=staticgpu

echo "Hello from Slurm!"
echo "Job ID: $SLURM_JOB_ID"
echo "Running on: $(hostname)"
nvidia-smi || echo "No GPU available"
EOF

# Copy example to existing users
for i in {1..10}; do
    cp /etc/skel/example-job.sh /home/user${i}/
    chown user${i}:user${i} /home/user${i}/example-job.sh
    chmod +x /home/user${i}/example-job.sh
done

echo "Example job scripts created!"
