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
    hidden: false
  
  login:
    host: "localhost"
  
  job:
    adapter: "slurm"
    bin: "/usr/local/bin"
    conf: "/run/slurm/conf/slurm.conf"
    
  batch_connect:
    basic:
      script_wrapper: |
        %s
      set_host: "host=$(hostname -s)"
EOF

cat > /etc/ood/config/clusters.d/cluster.yml.template <<EOF
---
v2:
  metadata:
    title: "SC25 Workshop Cluster"
  login:
    host: "localhost"
  job:
    adapter: "slurm"
    bin: "/usr/local/bin"
    conf: "/run/slurm/conf/slurm.conf"
EOF

# Enable OnDemand apps
mkdir -p /etc/ood/config/apps/shell
cat > /etc/ood/config/apps/shell/env <<'EOF'
DEFAULT_SSHHOST=localhost
EOF

# Configure Jupyter app
mkdir -p /etc/ood/config/apps/bc_desktop
mkdir -p /etc/ood/config/apps/jupyter

cat > /etc/ood/config/apps/jupyter/form.yml <<EOF
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

cat > /etc/ood/config/nginx_stage.yml <<EOF
---
pun_custom_env:
  PATH: "/usr/local/bin:/usr/bin:/bin"
EOF

systemctl restart httpd

echo "OnDemand cluster configuration complete!"
