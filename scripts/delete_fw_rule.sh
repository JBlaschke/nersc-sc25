#!/usr/bin/env bash
for fw in $(gcloud compute firewall-rules list \
  --filter="network~sc25-workshop" \
  --format="value(name)" \
  --project=nersc-sc25-demo); do
  echo "Deleting: $fw"
  gcloud compute firewall-rules delete $fw \
    --project=nersc-sc25-demo \
    --quiet
done
