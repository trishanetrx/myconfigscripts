#!/bin/bash

set -e

# Function to install required packages and setup kind on VM
setup_vm() {
    # Install Docker
    sudo apt update
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker

    # Install kubectl, kubeadm, and helm
    sudo snap install kubectl --classic
    sudo snap install kubeadm --classic
    sudo snap install helm --classic

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

    # Create a kind cluster
    kind create cluster
}

# Function to setup Kubernetes cluster and required configurations
setup_kubernetes_cluster() {
    # Ask for GitHub token
    read -p "Please enter your GitHub token: " GITHUB_TOKEN

    # Create namespace and secret for actions-runner-controller
    kubectl create ns actions-runner-system
    kubectl create secret generic controller-manager \
        -n actions-runner-system \
        --from-literal=github_token="$GITHUB_TOKEN"

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

    # Add and install actions-runner-controller Helm chart
    helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
    helm upgrade --install --namespace actions-runner-system --create-namespace \
                 --wait actions-runner-controller actions-runner-controller/actions-runner-controller

    # Clone the GitHub repository
    git clone git@github.com:warolv/github-actions-series.git
    cd github-actions-series/scale-runners

    # Ask for GitHub organizations and repository names
    read -p "Please enter the GitHub organization name: " GITHUB_ORG
    read -p "Please enter the GitHub repository names (comma-separated): " REPOS

    # Create myrunner.yaml file
    cat <<EOF > myrunner.yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: runner-deployment
  namespace: actions-runner-system
spec:
  template:
    spec:
      organization: $GITHUB_ORG
      labels:
        - sh-k8s-runner
---
apiVersion: actions.summerwind.dev/v1alpha1
kind: HorizontalRunnerAutoscaler
metadata:
  name: booleanlab-runner-deployment-autoscaler
  namespace: actions-runner-system
spec:
  scaleTargetRef:
    kind: RunnerDeployment
    name: runner-deployment
  minReplicas: 1
  maxReplicas: 8
  metrics:
  - type: TotalNumberOfQueuedAndInProgressWorkflowRuns
    repositoryNames:
$(echo "$REPOS" | sed 's/,/\n    - /g')
EOF

    # Apply the runner deployment configuration
    kubectl apply -f myrunner.yaml
}

# Main script execution
echo "Is this script running on a Kubernetes cluster? (yes/no): "
read ENV_TYPE

if [ "$ENV_TYPE" = "yes" ]; then
    # If running on Kubernetes cluster
    read -p "Please provide the path to your kubeconfig file: " KUBECONFIG_PATH

    if [ ! -f "$KUBECONFIG_PATH" ]; then
        echo "kubeconfig file not found at $KUBECONFIG_PATH"
        exit 1
    fi

    export KUBECONFIG="$KUBECONFIG_PATH"
    setup_kubernetes_cluster

else
    # If running on VM
    echo "Do you want to provide a path to your SSH private key file or paste the key content? (path/content): "
    read KEY_INPUT_TYPE

    if [ "$KEY_INPUT_TYPE" = "path" ]; then
        read -p "Please enter the path to your OpenSSH private key file: " SSH_KEY_PATH
        if [ ! -f "$SSH_KEY_PATH" ]; then
            echo "File not found: $SSH_KEY_PATH"
            exit 1
        fi
        cp "$SSH_KEY_PATH" ~/.ssh/id_rsa
    elif [ "$KEY_INPUT_TYPE" = "content" ]; then
        echo "Please paste your OpenSSH private key (end with an empty line):"
        PRIVATE_KEY=""
        while IFS= read -r line; do
            if [[ -z "$line" ]]; then
                break
            fi
            PRIVATE_KEY+="$line"$'\n'
        done
        echo "$PRIVATE_KEY" > ~/.ssh/id_rsa
    else
        echo "Invalid input. Exiting."
        exit 1
    fi

    chmod 600 ~/.ssh/id_rsa

    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_rsa

    setup_vm
    setup_kubernetes_cluster
fi
