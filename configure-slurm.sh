#!/usr/bin/env bash
set -euo pipefail

# On the controller node or login node with sacctmgr access
sudo sacctmgr add account workshop Description="SC25 Workshop Account" -i

for i in {1..10}; do
    sudo sacctmgr add user user${i} account=workshop -i
done

# Verify
sacctmgr show user
