#!/usr/bin/env bash
gcloud compute firewall-rules create sc25-workshop-allow-http \
  --network=sc25-workshop-net \
  --allow=tcp:80,tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --project=nersc-sc25-demo
