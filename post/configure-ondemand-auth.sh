#!/usr/bin/env bash
set -euo pipefail

echo "Configuring Open OnDemand for basic authentication..."
echo "WARNING: this is super basic, for production clusters use LDAP"

# Install Apache basic auth tools
dnf install -y httpd-tools

# Create the directory if it doesn't exist
mkdir -p /etc/httpd/

# Set the htpasswd file location (Rocky Linux 8 path)
HTPASSWD_FILE="/etc/httpd/.htpasswd"

# Remove old file if exists
rm -f ${HTPASSWD_FILE}

# Create the file with first user (use -c flag)
echo "nersc1" | htpasswd -c -i -B ${HTPASSWD_FILE} user1
echo "Added user1 to Apache authentication"

# Add remaining users (without -c flag)
for i in {2..10}; do
    username="user${i}"
    password="nersc${i}"
    echo "${password}" | htpasswd -i -B ${HTPASSWD_FILE} $username
    echo "Added $username to Apache authentication"
done

# Set proper permissions
chmod 640 ${HTPASSWD_FILE}
chown root:apache ${HTPASSWD_FILE}

EXTERNAL_IP=$(gcloud compute instances describe sc25worksh-slurm-login-001 \
  --zone=us-central1-a \
  --project=nersc-sc25-demo \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo "Open OnDemand URL: http://${EXTERNAL_IP}"

echo "Configuring Open OnDemand to use IP address (above) and not FQDN..."
echo "WARNING WARNING WARNING this is not meant for a production cluster. For production deployments use FQDN"
# Configure OnDemand to use basic auth. This will only work if you disable CSRF
# (below), for production clusters use REAL FQDN and LDAP

mkdir -p /etc/ood/config
tee > /etc/ood/config/ood_portal.yml <<EOF
---
# Open OnDemand Portal Configuration

# Use basic authentication
auth:
  - 'AuthType Basic'
  - 'AuthName "SC25 Workshop - Enter your username and password"'
  - 'AuthBasicProvider file'
  - 'AuthUserFile "${HTPASSWD_FILE}"'
  - 'Require valid-user'

# Don't use user mapping - just use REMOTE_USER directly
user_env: 'REMOTE_USER'

# Set the servername (replace with your actual hostname or IP)
servername: ${EXTERNAL_IP}

# Passenger configuration
passenger_min_instances: 1
passenger_start_timeout: 600

host_regex: '.*nersc-sc25-demo\.internal'
node_uri: '/node'
rnode_uri: '/rnode'
EOF

# Update the portal configuration
/opt/ood/ood-portal-generator/sbin/update_ood_portal

# Restart Apache
systemctl restart httpd

echo "Open OnDemand authentication configured!"
echo "Password file created at: ${HTPASSWD_FILE}"


echo "Disabling CSRF in Job Composer system app..."
echo "WARNING WARNING WARNING: this is NOT a permanent solution, and only meant to work with IP-based (i.e. temporary and insecure) deployments"

# This will disable CSRF, remove this for deployments with REAL FQDN

# 1. Add to app's initializers
tee /var/www/ood/apps/sys/myjobs/config/initializers/zzz_disable_csrf.rb <<'EOF'
# WORKSHOP ONLY - Disable CSRF
Rails.application.config.to_prepare do
  ApplicationController.class_eval do
    skip_before_action :verify_authenticity_token, raise: false

    def protect_against_forgery?
      false
    end

    def verified_request?
      true
    end
  end
end

Rails.application.config.action_controller.allow_forgery_protection = false
EOF

# 2. Set permissions
sudo chmod 644 /var/www/ood/apps/sys/myjobs/config/initializers/zzz_disable_csrf.rb

# 3. Touch restart file to force app reload
sudo touch /var/www/ood/apps/sys/myjobs/tmp/restart.txt

# 4. Clean PUNs
sudo /opt/ood/nginx_stage/sbin/nginx_stage nginx_clean

# 5. Restart Apache
sudo systemctl restart httpd
