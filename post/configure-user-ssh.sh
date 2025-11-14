#!/usr/bin/env bash
set -euo pipefail

echo "=== Configuring SSH for workshop users (NFS-aware) ==="

for i in {1..100}; do
    username="user${i}"
    user_home="/home/${username}"

    echo "Setting up SSH for ${username}..."

    # Get the user's UID/GID
    user_uid=$(id -u ${username})
    user_gid=$(id -g ${username})

    # Create .ssh directory as root first
    mkdir -p ${user_home}/.ssh

    # Generate SSH key as root (will fix ownership after)
    if [ ! -f "${user_home}/.ssh/id_rsa" ]; then
        ssh-keygen -t rsa -b 2048 -f ${user_home}/.ssh/id_rsa -N "" -q
        echo "Generated SSH key for ${username}"
    fi

    # Create authorized_keys
    cat ${user_home}/.ssh/id_rsa.pub > ${user_home}/.ssh/authorized_keys

    # Fix ownership (do this BEFORE chmod on NFS)
    chown -R ${user_uid}:${user_gid} ${user_home}
    chown -R ${user_uid}:${user_gid} ${user_home}/.ssh

    # Now set permissions (as root, after ownership is correct)
    chmod 700 ${user_home}
    chmod 700 ${user_home}/.ssh
    chmod 600 ${user_home}/.ssh/id_rsa
    chmod 644 ${user_home}/.ssh/id_rsa.pub
    chmod 600 ${user_home}/.ssh/authorized_keys

    # Accept localhost host key
    sudo -u ${username} ssh -o StrictHostKeyChecking=no localhost "exit" 2>/dev/null || true

    echo "✓ ${username} configured"
done

echo "SSH setup complete!"

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
for i in {1..100}; do
    cp /etc/skel/example-job.sh /home/user${i}/
    chown user${i}:user${i} /home/user${i}/example-job.sh
    chmod +x /home/user${i}/example-job.sh
done

echo "Example job scripts created!"
