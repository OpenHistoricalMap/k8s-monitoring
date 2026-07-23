# OHM Monitoring: Prometheus and Grafana

This repository installs **Prometheus**, **Grafana** and exporters to monitor the **OpenHistoricalMap** infrastructure. 

## Install

Installs into the `monitoring` namespace:

- **Prometheus** (server, alertmanager, node-exporter, kube-state-metrics, pushgateway), `local-path` storage, 30d retention.
- **Grafana** with the Prometheus datasource and the dashboards from `dashboards/` provisioned automatically.
- Alert rules for pods (CrashLoop, NotReady, OOMKilled) and nodes (NotReady, disk), plus a `Watchdog` heartbeat. External site up/down checks are handled by UptimeRobot, not here. See issue [#1000](https://github.com/OpenHistoricalMap/issues/issues/1000).

### Deploy

```sh
cp .env.example .env   # fill in credentials (gitignored)
./deploy_k3s.sh create
```

Quick check without exposing anything:

```sh
kubectl port-forward svc/grafana 3000:80 -n monitoring
kubectl port-forward svc/prometheus-server 9090:80 -n monitoring
```

### Exposing Grafana through the Cloudflare tunnel

- `monitoring.openhistoricalmap.org` → Type `HTTP` → `grafana.monitoring.svc.cluster.local:80`

Then point the `monitoring.openhistoricalmap.org` DNS record to the tunnel. Do not expose Prometheus or Alertmanager without auth; keep them on port-forward, or add a tunnel hostname protected by a Cloudflare Access policy.

## EKS agent (while EKS is alive)

A minimal Prometheus in EKS (`values/prometheus.eks.yaml`: no Grafana/Alertmanager, 6h retention) scrapes that cluster and pushes everything to the k3s Prometheus via `remote_write`. Metrics arrive labeled `cluster=aws-eks`. Remove it when EKS is shut down.

One-time setup in Cloudflare:

1. Public Hostname on the tunnel: `prometheus.openhistoricalmap.org` → `HTTP` → `prometheus-server.monitoring.svc.cluster.local:80`.
2. Zero Trust → Access → create an Application for `prometheus.openhistoricalmap.org` with a **Service Auth** policy, and create a **Service Token**. Use its credentials below.

Install the agent (kubectl context must be the EKS cluster):

```sh
# REMOTE_WRITE_URL and CF_ACCESS_* come from .env
./deploy_eks.sh create
```
