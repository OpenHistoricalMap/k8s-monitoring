# Monitoring Nodes and Pods in Kubernetes with Ingress

This repository contains scripts for installing **Prometheus**, various **exporters**, **Grafana** and **Loki**. The goal is to **simplify the monitoring setup**, making it quick and efficient to go from **installation to viewing detailed reports in Grafana** about the **OpenHistoricalMap** infrastructure.

## Authentication for Prometheus

Before installing **Prometheus**, set up **basic authentication credentials** for the Prometheus endpoint:

```sh
htpasswd -c auth prometheus-user
kubectl create secret generic prometheus-basic-auth --from-file=auth -n monitoring
```

Once authentication is configured, you can proceed with Prometheus installation and configure Ingress to use these credentials.

## Installing Prometheus and Grafana

This setup will install Prometheus and Grafana for monitoring your Kubernetes cluster.

### Production Deployment

```sh
export GRAFANA_ADMINPASSWORD=1234
export NODEGROUP_TYPE=web_large
export ENVIRONMENT=production
./deploy.sh create
```

## Staging Deployment

```sh
export GRAFANA_ADMINPASSWORD=1234
export NODEGROUP_TYPE=web_large
export ENVIRONMENT=staging

./deploy.sh create
```


### Deleting Applications

To remove the deployed applications, execute:

```sh
./deploy.sh delete
```
