#!/bin/bash

#
# After running repro.sh, you'll likely end up with petclinic having not
# been injected.
# Run this script, which will force the agent to restart, and then redeploy
# petclinic. It will then work.
#

set -euo pipefail

echo "Deleting datadog-agent pods..."
kubectl delete pods -n default -l agent.datadoghq.com/component=agent

echo "Deleting datadog-cluster-agent pods..."
kubectl delete pods -n default -l agent.datadoghq.com/component=cluster-agent


echo "Deleting petclinic deployment..."
kubectl delete -f petclinic.yml -n system --ignore-not-found=true

echo "Waiting for petclinic to be fully deleted..."
kubectl wait --for=delete deployment/petclinic -n system --timeout=60s || true

echo "Waiting for DatadogAgent to reach Running state..."
sleep 30
kubectl wait --for=jsonpath='{.status.agent.state}'=Running datadogagent/datadog --timeout=600s
kubectl wait --for=jsonpath='{.status.clusterAgent.state}'=Running datadogagent/datadog --timeout=600s
kubectl get pods -A
echo "DatadogAgent is fully running."

echo "Redeploying petclinic application..."
kubectl apply -f petclinic.yml -n system

echo "Waiting for petclinic deployment to be ready..."
kubectl wait --for=condition=Available deployment/petclinic -n system --timeout=300s

echo "Number of init containers in petclinic pod:"
kubectl get pods -n system -l app=petclinic -o json | jq '.items[0].spec.initContainers // [] | length'

echo "Done! Petclinic should now be properly injected."
