#!/usr/bin/env bash
set -euo pipefail

EXTERNAL_IP=$(gcloud compute instances describe sc25worksh-slurm-login-001 \
  --zone=us-central1-a \
  --project=nersc-sc25-demo \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo "Open OnDemand URL: http://${EXTERNAL_IP}"
