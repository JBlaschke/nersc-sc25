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

```bash
gcloud compute firewall-rules create sc25-workshop-allow-http \
  --network=sc25-workshop-net \
  --allow=tcp:80,tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --project=nersc-sc25-demo
```
