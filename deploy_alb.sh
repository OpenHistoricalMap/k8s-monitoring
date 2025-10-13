#!/bin/bash
set -e

export GRAFANA_ADMINPASSWORD="${GRAFANA_ADMINPASSWORD:-1234}"
export CLUSTER_NAME=$(kubectl config current-context)
export NODEGROUP_TYPE="${NODEGROUP_TYPE:-downstream_apps_medium}"
export CERTIFICATE_ARN="arn:aws:acm:us-east-1:12345678:certificate/abc"

kubectl get namespace monitoring || kubectl create namespace monitoring

install_monitoring() {
    read -p "Are you sure you want to upgrade/install Prometheus, Grafana, and Loki in CLUSTER \"${CLUSTER_NAME}\"? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        # Install/Upgrade Prometheus
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        helm upgrade --install prometheus prometheus-community/prometheus \
            -n monitoring -f values/prometheus.alb.values.yaml
        kubectl get pods -n monitoring | grep prometheus

        # Install/Upgrade Grafana
        helm repo add grafana https://grafana.github.io/helm-charts
        helm repo update

        envsubst < values/grafana.alb.values.yaml | helm upgrade --install grafana grafana/grafana \
        -n monitoring -f -

        kubectl get pods -n monitoring | grep grafana

    fi
}

delete_monitoring() {
    read -p "Are you sure you want to delete Prometheus, Grafana, and Loki from CLUSTER \"${CLUSTER_NAME}\"? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        helm delete prometheus --namespace monitoring
        # helm delete grafana --namespace monitoring
        helm delete loki --namespace monitoring
        kubectl delete -f ingress/${ENVIROMENT}-ingress.yml --namespace monitoring
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
