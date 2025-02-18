#!/bin/bash
set -e

export GRAFANA_ADMINPASSWORD="${GRAFANA_ADMINPASSWORD:-1234}"
export CLUSTER_NAME=$(kubectl config current-context)
export ENVIRONMENT="${ENVIRONMENT:-staging}"
export NODEGROUP_TYPE="${NODEGROUP_TYPE:-web_large}"

kubectl get namespace monitoring || kubectl create namespace monitoring

install_monitoring() {
    read -p "Are you sure you want to upgrade/install Prometheus, Grafana, and Loki in CLUSTER \"${CLUSTER_NAME}\"? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        # Install/Upgrade Prometheus
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        helm upgrade --install prometheus prometheus-community/prometheus \
            --namespace monitoring \
            --set server.persistentVolume.enabled=true \
            --set server.persistentVolume.size=20Gi \
            --set server.persistentVolume.storageClass="gp2" \
            --set server.retention=30d \
            --set nodeSelector."nodegroup_type"="$NODEGROUP_TYPE"

        kubectl get pods -n monitoring | grep prometheus

        # Install/Upgrade Grafana
        helm repo add grafana https://grafana.github.io/helm-charts
        helm repo update
        helm upgrade --install grafana grafana/grafana \
            --namespace monitoring \
            --set persistence.enabled=true \
            --set persistence.size=20Gi \
            --set persistence.storageClass="standard" \
            --set-string adminPassword="$GRAFANA_ADMINPASSWORD" \
            --set forceSecretRewrite=true \
            --set nodeSelector."nodegroup_type"="$NODEGROUP_TYPE"

        kubectl get pods -n monitoring | grep grafana

        # Install/Upgrade Loki (without adding as a Grafana datasource)
        helm repo add grafana https://grafana.github.io/helm-charts
        helm repo update
        helm upgrade --install loki grafana/loki-stack \
            --namespace monitoring \
            --set loki.persistence.enabled=true \
            --set loki.persistence.size=20Gi \
            --set loki.persistence.storageClassName="gp2" \
            --set promtail.enabled=true \
            --set nodeSelector."nodegroup_type"="$NODEGROUP_TYPE" \
            --set loki.config.table_manager.retention_deletes_enabled=true \
            --set loki.config.table_manager.retention_period=30d

        kubectl get pods -n monitoring | grep loki

        # Apply Ingress for Loki, Prometheus, and Grafana
        kubectl apply -f ingress/${ENVIRONMENT}-ingress.yml --namespace monitoring
    fi
}

delete_monitoring() {
    read -p "Are you sure you want to delete Prometheus, Grafana, and Loki from CLUSTER \"${CLUSTER_NAME}\"? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        helm delete prometheus --namespace monitoring
        helm delete grafana --namespace monitoring
        helm delete loki --namespace monitoring
        kubectl delete -f ingress/${ENVIRONMENT}-ingress.yml --namespace monitoring
    fi
}

### Main
ACTION=${1:-default}
if [ "$ACTION" == "create" ]; then
    install_monitoring
elif [ "$ACTION" == "delete" ]; then
    delete_monitoring
else
    echo "The action is unknown."
fi
