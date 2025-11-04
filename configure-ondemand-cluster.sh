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

echo "Setting up SSH keys for workshop users..."

for i in {1..10}; do
    username="user${i}"
    user_home="/home/${username}"
    
    echo "Setting up SSH for ${username}..."
    
    # Generate SSH key without passphrase
    sudo -u ${username} ssh-keygen -t rsa -b 2048 -f ${user_home}/.ssh/id_rsa -N "" -q
    
    # Add public key to authorized_keys
    sudo -u ${username} cat ${user_home}/.ssh/id_rsa.pub >> ${user_home}/.ssh/authorized_keys
    
    # Set proper permissions
    sudo -u ${username} chmod 600 ${user_home}/.ssh/authorized_keys
    sudo -u ${username} chmod 700 ${user_home}/.ssh
    
    # Test SSH connection (accept host key)
    sudo -u ${username} ssh -o StrictHostKeyChecking=no localhost "echo SSH works for ${username}" || true
    
    echo "✓ SSH configured for ${username}"
done

echo "All users can now SSH to localhost!"


systemctl restart httpd

echo "OnDemand cluster configuration complete!"
