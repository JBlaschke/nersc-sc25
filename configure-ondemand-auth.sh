#!/usr/bin/env bash
set -euo pipefail

echo "Configuring Open OnDemand for basic authentication..."

# Install Apache basic auth tools
dnf install -y httpd-tools

# Create password file for Apache
HTPASSWD_FILE="/opt/rh/httpd24/root/etc/httpd/.htpasswd"
rm -f $HTPASSWD_FILE

# Add all users to htpasswd
for i in {1..10}; do
    username="user${i}"
    password="nersc${i}"
    echo "$password" | htpasswd -i -B $HTPASSWD_FILE $username
    echo "Added $username to Apache authentication"
done

# Configure OnDemand to use basic auth
cat > /etc/ood/config/ood_portal.yml <<'EOF'
---
# Open OnDemand Portal Configuration

# Use basic authentication
auth:
  - 'AuthType Basic'
  - 'AuthName "SC25 Workshop"'
  - 'AuthBasicProvider file'
  - 'AuthUserFile "/opt/rh/httpd24/root/etc/httpd/.htpasswd"'
  - 'Require valid-user'

# Use user's actual username for jobs
user_map_cmd: '/opt/ood/ood_auth_map/bin/ood_auth_map.regex'

# Passenger configuration
passenger_min_instances: 1
passenger_start_timeout: 600
EOF

# Update the portal configuration
/opt/ood/ood-portal-generator/sbin/update_ood_portal

# Restart Apache
systemctl restart httpd

echo "Open OnDemand authentication configured!"
