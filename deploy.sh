#!/bin/bash
set -e

export CLUSTER_NAME=$(kubectl config current-context)
# export DS_PROMETHEUS=prometheus

if [ -z "$GRAFANA_ADMINPASSWORD" ]; then
    export GRAFANA_ADMINPASSWORD="1234"
fi

create_update_configmap() {
    local configmap_name=$1
    local template_file=$2
    local json_file="${template_file//.template/}"
    envsubst <"$template_file" >"$json_file"
    kubectl delete configmap "$configmap_name" -n prometheus --ignore-not-found=true
    kubectl create configmap "$configmap_name" --from-file="$json_file" -n prometheus
    
}

install_Prometheus() {
    read -p "Are you sure you want to upgrade/install prometheus in CLUSTER \"${CLUSTER_NAME}\"? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        # Install prometheus and node exporter
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        # helm show values prometheus-community/kube-prometheus-stack > values.yaml
        # Create namespace
        kubectl apply -f namespace.yaml
        
        # Create/Update configMap
        create_update_configmap "node-exporter-full" "configMaps/1860_rev32.template.json"
        create_update_configmap "cadvisor" "configMaps/14282_rev1.template.json"
        envsubst <values.template.yaml >values.yaml
        
        helm upgrade \
        --install prometheus prometheus-community/kube-prometheus-stack \
        -f values.yaml \
        --namespace prometheus
        
        helm upgrade \
        --install kube-state-metrics prometheus-community/kube-state-metrics \
        --namespace prometheus
        
        ## Postgres exporter
        helm upgrade \
        --install postgres-exporter prometheus-community/prometheus-postgres-exporter \
        -f postgres-exporter/values.yaml \
        --namespace prometheus
        
        # Install cAdvisor
        kubectl apply -R -f cadvisor/
        kubectl get pods --namespace prometheus
    fi
}

delete_prometheus() {
    read -p "Are you sure you want to delete prometheus from CLUSTER \"${CLUSTER_NAME}\"? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        helm delete prometheus --namespace prometheus
        kubectl delete -R -f cadvisor/
        helm uninstall postgres-exporter -n prometheus
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
