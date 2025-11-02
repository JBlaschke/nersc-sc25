# nersc-sc25

## Setting up Open OnDemand

### Ensure that HTTPD is running

```bash
sudo systemctl status httpd
```

### Get External IP address

```bash
EXTERNAL_IP=$(gcloud compute instances describe sc25worksh-slurm-login-001 \
  --zone=us-central1-a \
  --project=nersc-sc25-demo \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo "Open OnDemand URL: http://${EXTERNAL_IP}"
```

### Configuring Firewall

* Listing rules:

```bash
gcloud compute firewall-rules list \
  --filter="network~sc25-workshop" \
  --project=nersc-sc25-demo
```

* Creating rules

```bash
gcloud compute firewall-rules create sc25-workshop-allow-http \
  --network=sc25-workshop-net \
  --allow=tcp:80,tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --project=nersc-sc25-demo
```

* Deleting rules:

```bash
for fw in $(gcloud compute firewall-rules list \
  --filter="network~sc25-workshop" \
  --format="value(name)" \
  --project=nersc-sc25-demo); do
  echo "Deleting: $fw"
  gcloud compute firewall-rules delete $fw \
    --project=nersc-sc25-demo \
    --quiet
done
```
