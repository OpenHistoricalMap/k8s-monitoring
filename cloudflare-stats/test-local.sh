#!/bin/bash
# Run the stats script from your laptop against Cloudflare, without pushing
# anything: checks the token, the zone id and that every dataset answers.
# Usage: fill CF_ANALYTICS_* in ../.env, then ./test-local.sh [YYYY-MM-DD]
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a; source "$SCRIPT_DIR/../.env"; set +a
: "${CF_ANALYTICS_API_TOKEN:?set CF_ANALYTICS_API_TOKEN in .env}"
: "${CF_ANALYTICS_ZONE_ID:?set CF_ANALYTICS_ZONE_ID in .env}"
# The ConfigMap in cronjob.yaml is the source of truth; extract the script from it.
python3 - "$SCRIPT_DIR/cronjob.yaml" > "$SCRIPT_DIR/.cloudflare_stats.py" <<'PY'
import sys, yaml
for d in yaml.safe_load_all(open(sys.argv[1])):
    if d and d["kind"] == "ConfigMap":
        print(d["data"]["cloudflare_stats.py"])
PY
CF_API_TOKEN="$CF_ANALYTICS_API_TOKEN" CF_ZONE_ID="$CF_ANALYTICS_ZONE_ID" \
    CF_ACCOUNT_ID="${CF_ANALYTICS_ACCOUNT_ID:-}" CF_RUM_SITE_TAG="${CF_ANALYTICS_RUM_SITE_TAG:-}" DRY_RUN=1 STATS_DAY="${1:-}" \
    python3 "$SCRIPT_DIR/.cloudflare_stats.py"
rm -f "$SCRIPT_DIR/.cloudflare_stats.py"
