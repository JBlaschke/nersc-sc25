#!/usr/bin/env bash
set -euo pipefail

echo "Configuring Open OnDemand cluster settings..."

mkdir -p /etc/ood/config/clusters.d

# # This needs to run on the login node
# slurm_login_node=$(hostname)

tee > /etc/ood/config/clusters.d/sc25-workshop.yml <<'EOF'
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

tee > /etc/ood/config/clusters.d/cluster.yml.template <<'EOF'
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
  batch_connect:
    basic:
      script_wrapper: |
        %s
    set_host: "host=$(hostname -s)"
EOF

# Enable OnDemand apps
mkdir -p /etc/ood/config/apps/shell
tee > /etc/ood/config/apps/shell/env <<'EOF'
DEFAULT_SSHHOST=localhost
EOF

# # Configure Jupyter app
# mkdir -p /etc/ood/config/apps/bc_desktop
# mkdir -p /etc/ood/config/apps/jupyter
# tee > /etc/ood/config/apps/jupyter/form.yml <<'EOF'
# ---
# cluster: "sc25-workshop"
# attributes:
#   modules: "python"
#   bc_num_hours:
#     value: 1
#   bc_num_slots:
#     value: 1
#   node_type:
#     widget: "select"
#     options:
#       - ["GPU Node", "staticgpu"]
#       - ["Dynamic GPU", "dynamicgpu"]
# EOF
# 
# tee > /etc/ood/config/nginx_stage.yml <<EOF
# ---
# pun_custom_env:
#   PATH: "/usr/local/bin:/usr/bin:/bin"
# EOF
# 
# mkdir -p /etc/ood/config/apps/bc_jupyter
# tee /etc/ood/config/apps/bc_jupyter/form.yml <<'EOF'
# ---
# cluster: "sc25-workshop"
# 
# attributes:
#   bc_account:
#     label: "Account"
#     value: "workshop"
# 
#   partition:
#     widget: "select"
#     label: "Partition"
#     options:
#       - ["Static GPU", "staticgpu"]
#       - ["Dynamic GPU", "dynamicgpu"]
#     value: "staticgpu"
# 
#   bc_num_hours:
#     widget: "number_field"
#     label: "Number of hours"
#     value: 2
#     min: 1
#     max: 8
#     step: 1
#     help: "Maximum time for Jupyter session"
# 
#   bc_num_slots:
#     widget: "number_field"
#     label: "Number of nodes"
#     value: 1
#     min: 1
#     max: 1
#     help: "Jupyter runs on a single node"
# 
#   num_cores:
#     widget: "number_field"
#     label: "Number of CPU cores"
#     value: 4
#     min: 1
#     max: 8
#     step: 1
# 
#   bc_email_on_started:
#     help: "Not configured for this cluster"
# 
# form:
#   - partition
#   - bc_num_hours
#   - num_cores
#   - bc_email_on_started
# EOF
# 
# mkdir -p /etc/ood/config/apps/bc_jupyter/template
# tee /etc/ood/config/apps/bc_jupyter/template/before.sh.erb <<'EOF'
# # Load the shared Jupyter environment
# export PATH="/deploy/jupyter/venv/bin:${PATH}"
# export JUPYTER_PATH="/deploy/jupyter/venv/share/jupyter"
# 
# # Set up Jupyter config directory
# export JUPYTER_CONFIG_DIR="${HOME}/.jupyter"
# mkdir -p "${JUPYTER_CONFIG_DIR}"
# 
# # Create minimal config if needed
# if [ ! -f "${JUPYTER_CONFIG_DIR}/jupyter_notebook_config.py" ]; then
#   cat > "${JUPYTER_CONFIG_DIR}/jupyter_notebook_config.py" <<'PYEOF'
# c.NotebookApp.ip = '*'
# c.NotebookApp.open_browser = False
# c.NotebookApp.allow_origin = '*'
# PYEOF
# fi
# EOF

# Create app directory
mkdir -p /var/www/ood/apps/sys/jupyter/template

# Create manifest
tee /var/www/ood/apps/sys/jupyter/manifest.yml <<'EOF'
---
name: Jupyter Lab
category: Interactive Apps
subcategory: Servers
role: batch_connect
description: Launch JupyterLab on compute nodes
EOF

# Create form
tee /var/www/ood/apps/sys/jupyter/form.yml <<'EOF'
---
cluster: sc25-workshop

attributes:
  partition:
    widget: select
    label: "Partition"
    options:
      - ["Static GPU", "staticgpu"]
    value: "staticgpu"
  
  bc_num_hours:
    widget: number_field
    label: "Number of hours"
    value: 2
    min: 1
    max: 8
  
  num_cores:
    widget: number_field
    label: "Number of cores"
    value: 4
    min: 1
    max: 8

  mode:
    widget: "radio"
    value: "1"
    options:
      - ["Jupyter Lab", "1"]
      - ["Jupyter Notebook", "0"]

form:
  - partition
  - bc_num_hours
  - num_cores
  - mode
EOF

# Create submit config
tee /var/www/ood/apps/sys/jupyter/submit.yml.erb <<'EOF'
---
batch_connect:
  template: basic

script:
  batch_connect:
    min_port: 2000
    max_port: 6000
  native:
    - "-p"
    - "<%= partition %>"
    - "-n"
    - "<%= num_cores %>"
    - "-t"
    - "<%= bc_num_hours %>:00:00"
EOF

# Create launch script
tee /var/www/ood/apps/sys/jupyter/template/script.sh.erb <<'EOF'
#!/bin/bash
set -x

# Use Jupyter from /deploy
export PATH="/deploy/jupyter/venv/bin:${PATH}"

# Set up config
export JUPYTER_CONFIG_DIR="${HOME}/.jupyter"
mkdir -p "${JUPYTER_CONFIG_DIR}"

# Launch Jupyter
jupyter-lab --ip=0.0.0.0 \
           --port=${port} \
           --NotebookApp.base_url=/node/${host}/${port}/ \
           --NotebookApp.token=${password} \
           --no-browser
EOF

cp  /var/www/ood/apps/sys/bc_osc_jupyter/template/before.sh.erb \
    /var/www/ood/apps/sys/jupyter/template

cp  /var/www/ood/apps/sys/bc_osc_jupyter/template/after.sh.erb  \
    /var/www/ood/apps/sys/jupyter/template

# Set permissions
chown -R apache:apache /var/www/ood/apps/sys/jupyter
chmod -R 755 /var/www/ood/apps/sys/jupyter
chmod -R 644 /var/www/ood/apps/sys/jupyter/*.yml
chmod -R 755 /var/www/ood/apps/sys/jupyter/template
chmod -R 755 /var/www/ood/apps/sys/jupyter/template/script.sh.erb

# Create dashboard env
mkdir -p /etc/ood/config/apps/dashboard
tee /etc/ood/config/apps/dashboard/env <<'EOF'
# Dashboard configuration
OOD_DASHBOARD_TITLE="SC25 Workshop"
OOD_BATCH_CONNECT_CACHE_ATTR_VALUES=1
EOF

/opt/ood/nginx_stage/sbin/nginx_stage nginx_clean
systemctl restart httpd

echo "OnDemand cluster configuration complete!"
