#!/bin/bash
set -e

if [ -z "$GRAFANA_ADMINPASSWORD" ]; then
    export GRAFANA_ADMINPASSWORD="1234"
fi

export CLUSTER_NAME=$(kubectl config current-context)

kubectl get namespace monitoring || kubectl create namespace monitoring

install_Prometheus() {
    read -p "Are you sure you want to upgrade/install prometheus in CLUSTER \"${CLUSTER_NAME}\"? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then

        # Install prometheus and node exporter
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        helm install prometheus prometheus-community/prometheus --namespace monitoring
        kubectl get pods -n monitoring
        kubectl apply -f ingress/staging-prometheus-ingress.yml --namespace monitoring
        
        # Install grafana
        helm repo add grafana https://grafana.github.io/helm-charts
        helm repo update
        helm install grafana grafana/grafana --namespace monitoring --set-string adminPassword=$GRAFANA_ADMINPASSWORD
        kubectl get pods -n monitoring | grep grafana
        kubectl apply -f ingress/staging-grafana-ingress.yml --namespace monitoring
    fi
}

delete_prometheus() {
    read -p "Are you sure you want to delete prometheus from CLUSTER \"${CLUSTER_NAME}\"? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        helm delete prometheus --namespace monitoring
        helm delete grafana --namespace monitoring
    fi
}

### Main
export ACTION=$1
ACTION=${ACTION:-default}
if [ "$ACTION" == "create" ]; then
    install_Prometheus
    elif [ "$ACTION" == "delete" ]; then
    delete_prometheus
else
    echo "The action is unknown."
fi
