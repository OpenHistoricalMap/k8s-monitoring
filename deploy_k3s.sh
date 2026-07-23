#!/bin/bash
# Deploy Prometheus + Grafana on the k3s cluster.
# Usage: copy .env.example to .env, fill it in, then:
#   ./deploy_k3s.sh create
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a; source "$SCRIPT_DIR/.env"; set +a
fi

export GRAFANA_ADMINPASSWORD="${GRAFANA_ADMINPASSWORD:-1234}"
export ALERT_EMAIL_TO="${ALERT_EMAIL_TO:-}"
export SMTP_USERNAME="${SMTP_USERNAME:-}"
export SMTP_PASSWORD="${SMTP_PASSWORD:-}"
CLUSTER_NAME=$(kubectl config current-context)

if [ -z "$ALERT_EMAIL_TO" ] || [ -z "$SMTP_USERNAME" ] || [ -z "$SMTP_PASSWORD" ]; then
    echo "WARNING: ALERT_EMAIL_TO/SMTP_USERNAME/SMTP_PASSWORD not set, alert emails will not be delivered."
fi

install_monitoring() {
    read -p "Install/upgrade Prometheus and Grafana in CLUSTER \"${CLUSTER_NAME}\"? (y/n): " confirm
    [[ $confirm == [Yy] ]] || exit 0

    kubectl get namespace monitoring >/dev/null 2>&1 || kubectl create namespace monitoring

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    # grafana/grafana is deprecated since Jan 2026, chart moved to grafana-community
    helm repo add grafana-community https://grafana-community.github.io/helm-charts
    helm repo update

    envsubst '${ALERT_EMAIL_TO} ${SMTP_USERNAME} ${SMTP_PASSWORD}' < values/prometheus.k3s.yaml | \
        helm upgrade --install prometheus prometheus-community/prometheus \
        -n monitoring -f -

    # Dashboards as ConfigMaps, picked up by the Grafana sidecar
    # (fix the datasource uid placeholder in the JSONs).
    DASH_TMP=$(mktemp -d)
    for f in dashboards/*.json; do
        sed 's/PROMETHEUS_SOURCE_ID/prometheus/g' "$f" > "$DASH_TMP/$(basename "$f")"
    done
    kubectl create configmap ohm-dashboards \
        --from-file="$DASH_TMP"/ \
        -n monitoring --dry-run=client -o yaml | kubectl apply -f -
    rm -rf "$DASH_TMP"
    kubectl label configmap ohm-dashboards grafana_dashboard=1 -n monitoring --overwrite

    envsubst '${GRAFANA_ADMINPASSWORD}' < values/grafana.k3s.yaml | \
        helm upgrade --install grafana grafana-community/grafana \
        -n monitoring -f -

    kubectl get pods -n monitoring
}

delete_monitoring() {
    read -p "Delete Prometheus and Grafana from CLUSTER \"${CLUSTER_NAME}\"? (y/n): " confirm
    [[ $confirm == [Yy] ]] || exit 0
    helm delete grafana -n monitoring || true
    helm delete prometheus -n monitoring || true
    kubectl delete configmap ohm-dashboards -n monitoring || true
}

case "${1:-}" in
    create) install_monitoring ;;
    delete) delete_monitoring ;;
    *) echo "Usage: $0 <create|delete>" ;;
esac
