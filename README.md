
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
