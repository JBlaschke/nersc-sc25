#!/usr/bin/env bash
set -xeuo pipefail

exec > >(tee /var/log/ondemand-install.log)
exec 2>&1

echo "Installing Open OnDemand ..."

# Enable required modules for OnDemand
dnf module reset nodejs ruby -y
dnf module enable nodejs:20 ruby:3.3 -y
dnf module install nodejs:20 ruby:3.3 -y

# Install OnDemand repository
dnf install -y https://yum.osc.edu/ondemand/latest/ondemand-release-web-latest-1-6.noarch.rpm

# Install OnDemand and tools
dnf install -y ondemand git vim tmux htop nmap-ncat

echo "Open OnDemand software installed"

echo "Installing Jupyer ..."

# Create a shared Python environment for Jupyter
sudo mkdir -p /deploy/jupyter
sudo python3 -m venv /deploy/jupyter/venv

# Install JupyterLab and common packages
sudo /deploy/jupyter/venv/bin/pip install --upgrade pip
sudo /deploy/jupyter/venv/bin/pip install \
  jupyterlab \
  notebook \
  ipykernel \
  numpy \
  scipy \
  matplotlib \
  pandas \
  scikit-learn \
  seaborn

# Make accessible to all users
sudo chmod -R 755 /deploy/jupyter

echo "Jupyter software installed"

echo "Adding Jupyter to Open OnDemand, and Starting OOD portal ..."

sudo dnf install -y ondemand-bc_osc_jupyter 2>/dev/null || echo "Already installed"

# Configure OnDemand
/opt/ood/ood-portal-generator/sbin/update_ood_portal

# Enable and start Apache (use 'httpd' not 'httpd24-httpd')
systemctl enable httpd
systemctl start httpd

# Configure firewall
firewall-cmd --permanent --add-service=http 2>/dev/null || true
firewall-cmd --permanent --add-service=https 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true

echo "Open OnDemand startup complete!"

echo "Deploying Workshop Software and Programming Environment ..."

mkdir -p /deploy
cd /deploy
git clone https://github.com/JBlaschke/nersc-sc25.git
git clone https://github.com/JuliaParallel/DeploymentsOnHPC

cd DeploymentsOnHPC

# workaround to ensure that LMOD is initialized
export MODULEPATH="/opt/apps/modulefiles"
source /opt/apps/lmod/lmod/init/bash
ml av

make juliaup SITE=gcp MODE=global
make julia   SITE=gcp MODE=global
make kernels SITE=gcp MODE=global

echo "Workshop Software And Programming Environment Successfull Deployed"
