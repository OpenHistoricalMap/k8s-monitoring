#!/bin/bash

# Check if GRAFANA_ADMINPASSWORD exist
if [ -z "$GRAFANA_ADMINPASSWORD" ]; then
    export GRAFANA_ADMINPASSWORD="1234"
fi

install_Prometheus() {
    # Install prometheus and node exporter
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    kubectl create namespace prometheus
    helm install prometheus prometheus-community/kube-prometheus-stack --namespace prometheus
    # Install cAdvisor
    kubectl apply -R -f cadvisor/
    kubectl get pods --namespace prometheus
}

delete_prometheus() {
    helm delete prometheus --namespace prometheus
    kubectl delete -R -f cadvisor/
}

start_sites() {
    kubectl port-forward svc/prometheus-operated 9090  --namespace prometheus
    kubectl port-forward deployment/prometheus-grafana 3000 --namespace prometheus
}

# Function to ask and execute
ask_and_execute() {
    echo "Which function would you like to execute?"
    echo "1) Install Prometheus"
    echo "2) Delete Prometheus"
    echo "3) Prometheus/Grafana port forward"
    echo "4) Quit"

    read -p "Enter your choice [1-4]: " choice

    case $choice in
    1)
        install_Prometheus
        ;;
    2)
        start_sites
        ;;
    3)
        delete_prometheus
        ;;
    4)
        echo "Exiting."
        exit 0
        ;;
    *)
        echo "Invalid choice."
        ;;
    esac
}

# Call the ask_and_execute function
ask_and_execute

# ## node exporter
# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
# helm repo update
# helm install node-exporter prometheus-community/prometheus-node-exporter --namespace prometheus
# kubectl get pods --namespace prometheus

# kubectl delete daemonset -l app=prometheus-node-exporter  --namespace prometheus
# helm upgrade -i node-exporter prometheus-community/prometheus-node-exporter  --namespace prometheus

# helm delete node-exporter --namespace prometheus

# # kubectl delete daemonset -l app=prometheus-node-exporter
# # helm upgrade -i prometheus-node-exporter prometheus-community/prometheus-node-exporter

# helm show values prometheus-community/prometheus-node-exporter
