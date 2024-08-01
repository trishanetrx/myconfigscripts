#!/bin/bash

# Update package lists
sudo apt update

# Create the id_rsa file
cat <<EOF > ~/.ssh/id_rsa

EOF
chmod 600 ~/.ssh/id_rsa

# Add the SSH key to the SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa

# Download and install kind based on architecture
if [ $(uname -m) = x86_64 ]; then
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
elif [ $(uname -m) = aarch64 ]; then
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-arm64
else
  echo "Unsupported architecture"
  exit 1
fi
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Install kubectl, kubeadm, and helm via snap
sudo snap install kubectl --classic
sudo snap install kubeadm --classic
sudo snap install helm --classic

# Create a kind cluster
kind create cluster
kubectl cluster-info --context kind-kind

# Add and update the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.crds.yaml

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.11.0

# Create namespace and secret for actions-runner-controller
kubectl create ns actions-runner-system
kubectl create secret generic controller-manager \
    -n actions-runner-system \
    --from-literal=github_token=

# Add and install actions-runner-controller Helm chart
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm upgrade --install --namespace actions-runner-system --create-namespace \
             --wait actions-runner-controller actions-runner-controller/actions-runner-controller

# Clone the GitHub repository
git clone git@github.com:warolv/github-actions-series.git
cd github-actions-series/scale-runners

# Create myrunner.yaml file
cat <<EOF > myrunner.yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: testlab-runner-deployment
spec:
  template:
    spec:
      organization: testlab-01
      labels:
        - sh-k8s-runner
---
apiVersion: actions.summerwind.dev/v1alpha1
kind: HorizontalRunnerAutoscaler
metadata:
  name: testlab-runner-deployment-autoscaler
spec:
  scaleTargetRef:
    kind: RunnerDeployment
    name: testlab-runner-deployment
  minReplicas: 1
  maxReplicas: 4
  metrics:
  - type: TotalNumberOfQueuedAndInProgressWorkflowRuns
    repositoryNames:
    - testrepo01 
EOF

# Apply the runner deployment configuration
kubectl apply -f myrunner.yaml
