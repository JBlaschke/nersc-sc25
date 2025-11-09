#!/usr/bin/env bash
set -euo pipefail

echo "Configuring Open OnDemand cluster settings..."

mkdir -p /etc/ood/config/clusters.d

# # This needs to run on the login node
# slurm_login_node=$(hostname)

cat > /etc/ood/config/clusters.d/sc25-workshop.yml <<'EOF'
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

cat > /etc/ood/config/clusters.d/cluster.yml.template <<'EOF'
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

cat > /etc/ood/config/nginx_stage.yml <<EOF
---
pun_custom_env:
  PATH: "/usr/local/bin:/usr/bin:/bin"
EOF

mkdir -p /etc/ood/config/apps/bc_jupyter

tee /etc/ood/config/apps/bc_jupyter/form.yml <<'EOF'
---
cluster: "sc25-workshop"

attributes:
  bc_account:
    label: "Account"
    value: "workshop"

  partition:
    widget: "select"
    label: "Partition"
    options:
      - ["Static GPU", "staticgpu"]
      - ["Dynamic GPU", "dynamicgpu"]
    value: "staticgpu"

  bc_num_hours:
    widget: "number_field"
    label: "Number of hours"
    value: 2
    min: 1
    max: 8
    step: 1
    help: "Maximum time for Jupyter session"

  bc_num_slots:
    widget: "number_field"
    label: "Number of nodes"
    value: 1
    min: 1
    max: 1
    help: "Jupyter runs on a single node"

  num_cores:
    widget: "number_field"
    label: "Number of CPU cores"
    value: 4
    min: 1
    max: 8
    step: 1

  bc_email_on_started:
    help: "Not configured for this cluster"

form:
  - partition
  - bc_num_hours
  - num_cores
  - bc_email_on_started
EOF

mkdir -p /etc/ood/config/apps/bc_jupyter

tee /etc/ood/config/apps/bc_jupyter/template/before.sh.erb <<'EOF'
# Load the shared Jupyter environment
export PATH="/shared/jupyter/venv/bin:${PATH}"
export JUPYTER_PATH="/shared/jupyter/venv/share/jupyter"

# Set up Jupyter config directory
export JUPYTER_CONFIG_DIR="${HOME}/.jupyter"
mkdir -p "${JUPYTER_CONFIG_DIR}"

# Create minimal config if needed
if [ ! -f "${JUPYTER_CONFIG_DIR}/jupyter_notebook_config.py" ]; then
  cat > "${JUPYTER_CONFIG_DIR}/jupyter_notebook_config.py" <<'PYEOF'
c.NotebookApp.ip = '*'
c.NotebookApp.open_browser = False
c.NotebookApp.allow_origin = '*'
PYEOF
fi
EOF

/opt/ood/nginx_stage/sbin/nginx_stage nginx_clean
systemctl restart httpd

echo "OnDemand cluster configuration complete!"
