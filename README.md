
# Monitoring Node/Pods in kubernetes and Ingress

This repo contains scripts that allow for the installation of Prometheus and various exporters. The goal is to streamline the process, making it easy and quick from installation to viewing reports in Grafana.

## Install prometheus

This will install Prometheus, Grafana, Node-Exporter, and cAdvisor.

```sh
./deploy.sh create
```

## Delete prometheus

```sh
./deploy.sh delete
```

