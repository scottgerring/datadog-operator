#!/bin/bash
#
set -euo pipefail

wait_for_agent() {
  echo "Waiting for DatadogAgent to reach Running state..."
  kubectl wait --for=jsonpath='{.status.agent.state}'=Running datadogagent/datadog --timeout=600s
  kubectl wait --for=jsonpath='{.status.clusterAgent.state}'=Running datadogagent/datadog --timeout=600s

  kubectl get datadogagent/datadog
  
  echo "DatadogAgent is fully running."
}

kind delete cluster && true
kind create cluster
helm install my-datadog-operator datadog/datadog-operator

# Load API keys from .env file
source .env

# Create system namespace and datadog-secret
kubectl create namespace system --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic datadog-secret \
  --from-literal api-key="${DD_API_KEY}" \
  --from-literal app-key="${DD_APP_KEY}"
  # -n system

# Deploy the agent
kubectl apply -f DatadogAgent_initial.yml # -n system

# Wait for the DatadogAgent to become ready
wait_for_agent
kubectl get datadogagent/datadog

# Apply the updated DatadogAgent configuration
echo "Applying updated DatadogAgent configuration..."
kubectl apply -f DatadogAgent_updated.yml # -n system

# Wait for the DatadogAgent to reconcile the update
wait_for_agent
kubectl get datadogagent/datadog

# Deploy petclinic application
echo "Deploying petclinic application..."
kubectl apply -f petclinic.yml -n system

# Wait for petclinic deployment to be ready
echo "Waiting for petclinic deployment to be ready..."
kubectl wait --for=condition=Available deployment/petclinic -n system --timeout=300s

# Print the number of init containers
echo "Number of init containers in petclinic pod:"
kubectl get pods -n system -l app=petclinic -o json | jq '.items[0].spec.initContainers // [] | length'
