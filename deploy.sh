#!/bin/bash
set -euo pipefail

echo "Pushing production branch..."
git push origin production

echo "Deploying to server..."
ssh root@167.233.225.220 "/opt/deploy-twenty.sh"

echo "Done."
