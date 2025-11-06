#!/usr/bin/env bash
set -xeuo pipefail

exec > >(tee /var/log/ondemand-install.log)
exec 2>&1

echo "Installing Open OnDemand..."

# Enable required modules for OnDemand
dnf module reset nodejs ruby -y
dnf module enable nodejs:20 ruby:3.3 -y
dnf module install nodejs:20 ruby:3.3 -y

# Install OnDemand repository
dnf install -y https://yum.osc.edu/ondemand/latest/ondemand-release-web-latest-1-6.noarch.rpm

# Install OnDemand and tools
dnf install -y ondemand git vim tmux htop

# Configure OnDemand
/opt/ood/ood-portal-generator/sbin/update_ood_portal

# Enable and start Apache (use 'httpd' not 'httpd24-httpd')
systemctl enable httpd
systemctl start httpd

# Configure firewall
firewall-cmd --permanent --add-service=http 2>/dev/null || true
firewall-cmd --permanent --add-service=https 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true

echo "Open OnDemand installation complete!"

git clone https://github.com/JBlaschke/nersc-sc25.git
