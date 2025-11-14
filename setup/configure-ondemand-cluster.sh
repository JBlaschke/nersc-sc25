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
    ssh_allow: true
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
      - ["Nvidia T4 [t4dws]",               "t4dws"   ]
      - ["Nvidia V100 (4/Node) [v100dws]",  "v100dws" ]
      - ["Nvidia V100 (8/Node) [v100dws8]", "v100dws8"]
    value: "Nvidia T4 [t4dws]"
  
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

  working_dir:
    widget: "path_selector"
    label: "Root Directory"
    show_hidden: false
    show_files: false   # Only display directories
    help: "Select your project directory; defaults to $HOME"

form:
  - partition
  - bc_num_hours
  - num_cores
  - mode
  - working_dir
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

## Taken from the OSC deployment example
# Set working directory to notebook root directory
cd "${NOTEBOOK_ROOT}"

# Launch the Jupyter server
set -x
jupyter <%= context.mode == "1" ? 'lab' : 'notebook' %> --config="${CONFIG_FILE}"

EOF

cp  /var/www/ood/apps/sys/bc_osc_jupyter/view.html.erb \
    /var/www/ood/apps/sys/jupyter

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
