#!/usr/bin/env bash
set -euo pipefail

echo "Configuring Open OnDemand for basic authentication..."

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


# Configure OnDemand to use basic auth
mkdir -p /etc/ood/config
cat > /etc/ood/config/ood_portal.yml <<EOF
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
EOF

# Update the portal configuration
/opt/ood/ood-portal-generator/sbin/update_ood_portal

# Restart Apache
systemctl restart httpd

echo "Open OnDemand authentication configured!"
echo "Password file created at: ${HTPASSWD_FILE}"
