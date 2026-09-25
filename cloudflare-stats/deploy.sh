#!/bin/bash
# Deploy the Cloudflare usage stats CronJob (requests, people, client apps)
# into the cluster that runs Prometheus + Pushgateway. Independent from the
# EKS/k3s scripts: it only needs the `monitoring` namespace and the Pushgateway.
# Usage: fill CF_ANALYTICS_* in ../.env, point kubectl at the cluster, then:
#   ./deploy.sh create     # create/update secret + CronJob
#   ./deploy.sh run        # run one job now and print its output
#   ./deploy.sh delete
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    set -a; source "$SCRIPT_DIR/../.env"; set +a
fi

NS="monitoring"
CLUSTER_NAME=$(kubectl config current-context)

create() {
    : "${CF_ANALYTICS_API_TOKEN:?set CF_ANALYTICS_API_TOKEN in .env}"
    : "${CF_ANALYTICS_ZONE_ID:?set CF_ANALYTICS_ZONE_ID in .env}"

    read -p "Install/upgrade the Cloudflare stats CronJob in CLUSTER \"${CLUSTER_NAME}\"? (y/n): " confirm
    [[ $confirm == [Yy] ]] || exit 0

    kubectl get namespace "$NS" >/dev/null 2>&1 || { echo "namespace $NS missing: install Prometheus first (../deploy_k3s.sh create)"; exit 1; }
    kubectl -n "$NS" get svc prometheus-prometheus-pushgateway >/dev/null 2>&1 || { echo "Pushgateway service missing in $NS"; exit 1; }

    # Secret keys are what the script reads inside the pod.
    local secret_args=(--from-literal=CF_API_TOKEN="$CF_ANALYTICS_API_TOKEN" --from-literal=CF_ZONE_ID="$CF_ANALYTICS_ZONE_ID")
    if [ -n "${CF_ANALYTICS_ACCOUNT_ID:-}" ] && [ -n "${CF_ANALYTICS_RUM_SITE_TAG:-}" ]; then
        secret_args+=(--from-literal=CF_ACCOUNT_ID="$CF_ANALYTICS_ACCOUNT_ID"
                      --from-literal=CF_RUM_SITE_TAG="$CF_ANALYTICS_RUM_SITE_TAG")
    fi
    if [ -n "${CF_ANALYTICS_S3_URI:-}" ]; then
        : "${AWS_ACCESS_KEY_ID:?set AWS_ACCESS_KEY_ID when CF_ANALYTICS_S3_URI is set}"
        : "${AWS_SECRET_ACCESS_KEY:?set AWS_SECRET_ACCESS_KEY when CF_ANALYTICS_S3_URI is set}"
        secret_args+=(--from-literal=S3_URI="$CF_ANALYTICS_S3_URI"
                      --from-literal=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
                      --from-literal=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY")
    fi
    kubectl -n "$NS" create secret generic cloudflare-stats "${secret_args[@]}" \
        --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f "$SCRIPT_DIR/cronjob.yaml"
    kubectl -n "$NS" get cronjob cloudflare-stats
}

run() {
    local job="cloudflare-stats-manual-$(date +%s)"
    kubectl -n "$NS" create job "$job" --from=cronjob/cloudflare-stats
    kubectl -n "$NS" wait --for=condition=complete --timeout=180s "job/$job" || true
    kubectl -n "$NS" logs "job/$job"
}

delete() {
    read -p "Delete the Cloudflare stats CronJob from CLUSTER \"${CLUSTER_NAME}\"? (y/n): " confirm
    [[ $confirm == [Yy] ]] || exit 0
    kubectl delete -f "$SCRIPT_DIR/cronjob.yaml" --ignore-not-found
    kubectl -n "$NS" delete secret cloudflare-stats --ignore-not-found
}

case "${1:-}" in
    create) create ;;
    run) run ;;
    delete) delete ;;
    *) echo "Usage: $0 <create|run|delete>" ;;
esac
