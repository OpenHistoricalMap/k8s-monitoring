#!/bin/bash
set -e

export GRAFANA_ADMINPASSWORD="${GRAFANA_ADMINPASSWORD:-1234}"
export CLUSTER_NAME=$(kubectl config current-context)
export ENVIROMENT="${ENVIROMENT:-staging}"

kubectl get namespace monitoring || kubectl create namespace monitoring

install_prometheus() {
    read -p "Are you sure you want to upgrade/install prometheus in CLUSTER \"${CLUSTER_NAME}\"? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        # Install/upgrade Prometheus
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        helm upgrade --install prometheus prometheus-community/prometheus \
          --namespace monitoring \
          --set server.persistentVolume.enabled=true \
          --set server.persistentVolume.size=10Gi \
          --set server.persistentVolume.storageClass="gp2"

        kubectl get pods -n monitoring

        # Install/upgrade Grafana
        helm repo add grafana https://grafana.github.io/helm-charts
        helm repo update
        helm upgrade --install grafana grafana/grafana \
          --namespace monitoring \
          --set persistence.enabled=true \
          --set persistence.size=10Gi \
          --set persistence.storageClass="standard" \
          --set-string adminPassword="$GRAFANA_ADMINPASSWORD" \
           --set forceSecretRewrite=true \
          --set nodeSelector."nodegroup_type"="web_large"

        kubectl get pods -n monitoring | grep grafana

        # Create ingress
        kubectl apply -f ingress/${ENVIROMENT}-ingress.yml --namespace monitoring
    fi
}

delete_prometheus() {
    read -p "Are you sure you want to delete prometheus and grafana from CLUSTER \"${CLUSTER_NAME}\"? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        helm delete prometheus --namespace monitoring
        helm delete grafana --namespace monitoring
        kubectl apply -f ingress/${ENVIROMENT}-prometheus-ingress.yml --namespace monitoring
        kubectl apply -f ingress/${ENVIROMENT}-grafana-ingress.yml
    fi
}

### Main
ACTION=${1:-default}
if [ "$ACTION" == "create" ]; then
    install_prometheus
elif [ "$ACTION" == "delete" ]; then
    delete_prometheus
else
    echo "The action is unknown."
fi
