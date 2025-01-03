
# Monitoring Nodes/Pods in Kubernetes and Ingress

This repository contains scripts to install Prometheus, various exporters, and Grafana. The goal is to streamline the entire process—making it quick and easy to go from installation to viewing reports in Grafana about the OpenHistoricalMap infrastructure.

## Authentication for Prometheus

Before installing Prometheus, create basic authentication credentials for the Prometheus endpoint:

```sh
htpasswd -c auth prometheus-user
kubectl create secret generic prometheus-basic-auth --from-file=auth -n monitoring
```

After this step, you can proceed with Prometheus installation and configure the Ingress to use this basic authentication.

## Install prometheus and Grafana

This will install Prometheus, Grafana.


```sh
export ENVIROMENT=staging
#export ENVIROMENT=Production
./deploy.sh create
## Delete apps
./deploy.sh delete
```


## Install Dashboard

Import the file dashboard.json into Grafana.

Result:
https://prometheus.openhistoricalmap.org/

![image](https://github.com/user-attachments/assets/ca986706-5a56-4f2d-9f1c-148b602a053a)



## Adding Hetzner node exporter


Hetzner server is going to be installed manually the exporter

```sh
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar -xvzf node_exporter-1.6.1.linux-amd64.tar.gz
sudo cp node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
sudo useradd --no-create-home --shell /bin/false node_exporter
sudo nano /etc/systemd/system/node_exporter.service
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
sudo systemctl status node_exporter
```
- In  monitoring namespace edit prometheus-server ConfigMap 

```sh
kubectl edit cm prometheus-server -n monitoring
```


```sh
    scrape_configs:
    - job_name: node-exporter-external
      scrape_interval: 1m
      scrape_timeout: 10s
      metrics_path: /metrics
      scheme: http
      static_configs:
        - targets:
          - "<HETZNER_IP>:9100"
    ....
```