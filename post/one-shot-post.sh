#!/usr/bin/env bash
set -euo pipefail

sudo /deploy/nersc-sc25/post/configure-user-ssh.sh
     /deploy/nersc-sc25/post/configure-slurm.sh
sudo /deploy/nersc-sc25/post/configure-ondemand-auth.sh
