
# Monitoring Node/Pods in kubernetes

This repo contains scripts that allow for the installation of Prometheus and various exporters. The goal is to streamline the process, making it easy and quick from installation to viewing reports in Grafana.

## Install prometheus

This will install Prometheus, Grafana, Node-Exporter, and cAdvisor.

```sh
./deploy.sh create
```
## Export UI dashboards 

- Prometheus:

`kubectl port-forward svc/prometheus-operated 9090 --namespace prometheus`

- Grafana

`kubectl port-forward deployment/prometheus-grafana 3000 --namespace prometheus`

## Delete prometheus

```sh
./deploy.sh delete
```

