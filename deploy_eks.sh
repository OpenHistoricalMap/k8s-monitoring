#!/bin/bash
# Install the minimal Prometheus agent on EKS: it scrapes that cluster and
# pushes everything to the central Prometheus in k3s (values/prometheus.eks.yaml).
# Usage: copy .env.example to .env, fill it in, then:
#   ./deploy_eks.sh create
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a; source "$SCRIPT_DIR/.env"; set +a
fi

CLUSTER_NAME=$(kubectl config current-context)

install_agent() {
    : "${REMOTE_WRITE_URL:?set REMOTE_WRITE_URL}"
    : "${CF_ACCESS_CLIENT_ID:?set CF_ACCESS_CLIENT_ID}"
    : "${CF_ACCESS_CLIENT_SECRET:?set CF_ACCESS_CLIENT_SECRET}"

    read -p "Install/upgrade the Prometheus agent in CLUSTER \"${CLUSTER_NAME}\" pushing to ${REMOTE_WRITE_URL}? (y/n): " confirm
    [[ $confirm == [Yy] ]] || exit 0

    kubectl get namespace monitoring >/dev/null 2>&1 || kubectl create namespace monitoring

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    envsubst '${REMOTE_WRITE_URL} ${CF_ACCESS_CLIENT_ID} ${CF_ACCESS_CLIENT_SECRET}' < values/prometheus.eks.yaml | \
        helm upgrade --install prometheus prometheus-community/prometheus \
        -n monitoring -f -

    kubectl -n monitoring get pods
    echo
    echo "Check the push works:"
    echo "  kubectl -n monitoring port-forward svc/prometheus-server 9091:80"
    echo "  then query: prometheus_remote_storage_shards (expect >= 1)"
}

delete_agent() {
    read -p "Delete the Prometheus agent from CLUSTER \"${CLUSTER_NAME}\"? (y/n): " confirm
    [[ $confirm == [Yy] ]] || exit 0
    helm delete prometheus -n monitoring || true
}

case "${1:-}" in
    create) install_agent ;;
    delete) delete_agent ;;
    *) echo "Usage: $0 <create|delete>" ;;
esac
