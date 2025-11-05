#!/usr/bin/env bash
set -euo pipefail

echo "Configuring Open OnDemand cluster settings..."

mkdir -p /etc/ood/config/clusters.d

# # This needs to run on the login node
# slurm_login_node=$(hostname)

cat > /etc/ood/config/clusters.d/sc25-workshop.yml <<EOF
---
v2:
  metadata:
    title: "SC25 Workshop Cluster"
  login:
    host: "localhost"
  job:
    adapter: "slurm"
    cluster: "sc25-workshop"
    bin: "/usr/bin"
    conf: "/etc/slurm/slurm.conf"
    submit_host: "localhost"
EOF

# Enable OnDemand apps
mkdir -p /etc/ood/config/apps/shell
cat > /etc/ood/config/apps/shell/env <<'EOF'
DEFAULT_SSHHOST=localhost
EOF

# Configure Jupyter app
mkdir -p /etc/ood/config/apps/bc_desktop
mkdir -p /etc/ood/config/apps/jupyter

cat > /etc/ood/config/apps/jupyter/form.yml <<'EOF'
---
cluster: "sc25-workshop"
attributes:
  modules: "python"
  bc_num_hours:
    value: 1
  bc_num_slots:
    value: 1
  node_type:
    widget: "select"
    options:
      - ["GPU Node", "staticgpu"]
      - ["Dynamic GPU", "dynamicgpu"]
EOF

echo "=== Configuring SSH for workshop users (NFS-aware) ==="

for i in {1..10}; do
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
    chown -R ${user_uid}:${user_gid} ${user_home}/.ssh
    
    # Now set permissions (as root, after ownership is correct)
    chmod 700 ${user_home}/.ssh
    chmod 600 ${user_home}/.ssh/id_rsa
    chmod 644 ${user_home}/.ssh/id_rsa.pub
    chmod 600 ${user_home}/.ssh/authorized_keys
    
    # Accept localhost host key
    sudo -u ${username} ssh -o StrictHostKeyChecking=no localhost "exit" 2>/dev/null || true
    
    echo "✓ ${username} configured"
done

echo "SSH setup complete!"

systemctl restart httpd

echo "OnDemand cluster configuration complete!"
