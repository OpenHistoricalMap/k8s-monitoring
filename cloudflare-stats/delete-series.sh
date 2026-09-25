#!/bin/bash
# Delete Cloudflare stats breakdown series from Prometheus up to a given time.
# Use it after a fix in the script changed what a breakdown means (the totals
# ohm_cf_requests_*, ohm_cf_uniques_*, ohm_cf_visits_* are kept).
# Needs --web.enable-admin-api on prometheus-server (values/prometheus.k3s.yaml).
# Usage: ./delete-series.sh 2026-09-25T00:00:00Z        (kubectl context = the k3s cluster)
set -euo pipefail
END="${1:?usage: $0 <RFC3339 end time, e.g. 2026-09-25T00:00:00Z>}"
NS=monitoring
kubectl -n $NS port-forward svc/prometheus-server 9099:80 >/dev/null 2>&1 &
PF=$!; trap 'kill $PF 2>/dev/null' EXIT
for i in $(seq 1 30); do
  curl -sf --max-time 5 http://127.0.0.1:9099/-/ready >/dev/null && break
  sleep 1
  [ "$i" = 30 ] && { echo "prometheus not reachable through port-forward"; exit 1; }
done
MATCH='{__name__=~"ohm_cf_(host|agent|method|status|cdn_cgi|sample_scale).*"}'
echo "series matching before delete:"
curl -sf --max-time 60 'http://127.0.0.1:9099/api/v1/series' --data-urlencode "match[]=$MATCH" --data-urlencode "end=$END" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)["data"]))'
read -p "Delete them up to $END in cluster $(kubectl config current-context)? (y/n): " ok; [[ $ok == [Yy] ]] || exit 0
curl -s -X POST 'http://127.0.0.1:9099/api/v1/admin/tsdb/delete_series' --data-urlencode "match[]=$MATCH" --data-urlencode "end=$END" -w "delete: HTTP %{http_code}\n"
curl -s -X POST 'http://127.0.0.1:9099/api/v1/admin/tsdb/clean_tombstones' -w "clean_tombstones: HTTP %{http_code}\n"
