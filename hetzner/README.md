# Export the NodeExporter Log into Kubernetes

We use NodeExporter in Hetzner to collect information from the server.

```sh
kubectl edit cm prometheus-server -n monitoring
```

Inside the scrape_configs section, add this configuration:

```js
    - job_name: 'node-exporter-hetzner'
      static_configs:
        - targets: ['<HETZNER_NODE_IP>:9100']
```

- Save and Restart Prometheus

```sh
kubectl delete pod -l app.kubernetes.io/name=prometheus -n monitoring
```