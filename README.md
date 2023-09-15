
# Monitoring Node/Pods in kubernetes

This repo contains scripts that allow for the installation of Prometheus and various exporters. The goal is to streamline the process, making it easy and quick from installation to viewing reports in Grafana.


## Display values that can be updated

```
helm show values prometheus-community/kube-prometheus-stack > values.yaml
```