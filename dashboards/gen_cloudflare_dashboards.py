# Generates ohm_usage.json, ohm_clients.json and ohm_traffic_health.json from the
# metrics pushed by cloudflare-stats/. Edit this file, run it, commit the JSONs:
#   python3 dashboards/gen_cloudflare_dashboards.py
import json, os
OUT = os.path.dirname(os.path.abspath(__file__))
DS = {"type": "prometheus", "uid": "PROMETHEUS_SOURCE_ID"}

# Fixed categorical order (dataviz palette): blue, orange, aqua, yellow, magenta, green. Never cycled.
PAL = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300"]
GRAY = "#8a8a85"
HOST_COLORS = dict(zip(["vtiles", "api", "www", "static-tiles", "nominatim", "openhistoricalmap.org"], PAL))
AGENT_COLORS = {"browser:Chrome": PAL[0], "browser:Firefox": "#6da7ec", "browser:Safari": "#9ec5f4", "browser:Edge": "#b7d3f6",
                "JOSM": PAL[1], "QGIS": PAL[2], "MapLibre": PAL[3], "curl": PAL[4], "python-requests": "#d55181",
                "bot:Anthropic": GRAY, "bot:Ahrefs": GRAY, "bot:Google": GRAY, "bot:other": GRAY, "other": "#c3c2b7"}
STATUS_COLORS = {"2xx ok": PAL[5], "3xx redirect": PAL[0], "403 blocked by Cloudflare": PAL[1], "429 rate limited": PAL[4],
                 "other 4xx": PAL[3], "5xx errors": "#c62828"}
CACHE_COLORS = {"hit": PAL[5], "stale": "#5cb85c", "revalidated": "#9ccc65", "miss": PAL[1], "expired": PAL[3],
                "dynamic": GRAY, "bypass": "#c3c2b7", "none": "#dcdbd3"}

_id = [0]
def nid():
    _id[0] += 1; return _id[0]

def overrides(colors):
    return [{"matcher": {"id": "byName", "options": k}, "properties": [{"id": "color", "value": {"mode": "fixed", "fixedColor": v}}]} for k, v in colors.items()]

def tgt(expr, legend="__auto", ref="A", instant=False, fmt=None):
    t = {"refId": ref, "datasource": DS, "expr": expr, "legendFormat": legend}
    if instant: t.update({"instant": True, "range": False})
    if fmt: t["format"] = fmt
    return t

def stat(title, expr, x, y, w=6, h=4, unit="short", desc="", color=None, decimals=0, thresholds=None):
    p = {"id": nid(), "type": "stat", "title": title, "description": desc, "datasource": DS,
         "gridPos": {"x": x, "y": y, "w": w, "h": h}, "targets": [tgt(expr, instant=True)],
         "options": {"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
                     "colorMode": "value" if thresholds else "none", "graphMode": "none", "textMode": "value", "justifyMode": "center"},
         "fieldConfig": {"defaults": {"unit": unit, "decimals": decimals}, "overrides": []}}
    if thresholds: p["fieldConfig"]["defaults"]["thresholds"] = thresholds
    if color: p["fieldConfig"]["defaults"]["color"] = {"mode": "fixed", "fixedColor": color}
    return p

def ts(title, targets, x, y, w=12, h=8, unit="short", desc="", bars=False, stack=False, colors=None, single_color=None,
       legend=True, min_=None, max_=None, repeat=None, max_per_row=None, decimals=None, interval="1d"):
    p = {"id": nid(), "type": "timeseries", "title": title, "description": desc, "datasource": DS, "interval": interval,
         "gridPos": {"x": x, "y": y, "w": w, "h": h}, "targets": targets,
         "options": {"legend": {"showLegend": legend, "displayMode": "table" if legend else "list", "placement": "right" if legend else "bottom",
                                "calcs": ["lastNotNull", "max"] if legend else [], "sortBy": "Last *", "sortDesc": True},
                     "tooltip": {"mode": "multi", "sort": "desc"}},
         "fieldConfig": {"defaults": {"unit": unit, **({"decimals": decimals} if decimals is not None else {}),
                                      "custom": {"drawStyle": "bars" if bars else "line", "fillOpacity": 70 if bars else 8, "lineWidth": 1 if bars else 2,
                                                 "spanNulls": False, "pointSize": 4, "showPoints": "never",
                                                 "stacking": {"mode": "normal" if stack else "none", "group": "A"}},
                                      "color": {"mode": "fixed", "fixedColor": single_color} if single_color else {"mode": "palette-classic"}},
                         "overrides": overrides(colors) if colors else []}}
    if min_ is not None: p["fieldConfig"]["defaults"]["min"] = min_
    if max_ is not None: p["fieldConfig"]["defaults"]["max"] = max_
    if repeat:
        p.update({"repeat": repeat, "repeatDirection": "h", "maxPerRow": max_per_row or 4})
    return p

def table(title, expr, x, y, w=12, h=10, value_name="value", unit="short", desc="", sort_by=None):
    p = {"id": nid(), "type": "table", "title": title, "description": desc, "datasource": DS,
         "gridPos": {"x": x, "y": y, "w": w, "h": h}, "targets": [tgt(expr, instant=True, fmt="table")],
         "transformations": [{"id": "organize", "options": {"excludeByName": {"Time": True, "__name__": True}, "renameByName": {"Value": value_name}}}],
         "fieldConfig": {"defaults": {"unit": unit, "decimals": 0, "custom": {"align": "auto"}}, "overrides": []},
         "options": {"sortBy": [{"displayName": sort_by or value_name, "desc": True}], "cellHeight": "sm"}}
    return p

def row(title, y):
    return {"id": nid(), "type": "row", "title": title, "collapsed": False, "gridPos": {"x": 0, "y": y, "w": 24, "h": 1}, "panels": []}

def dash(uid, title, panels, desc, templating=None, time_from="now-30d"):
    return {"uid": uid, "title": title, "description": desc, "tags": ["ohm", "cloudflare"], "timezone": "utc", "schemaVersion": 39,
            "version": 1, "editable": True, "graphTooltip": 1, "refresh": "", "time": {"from": time_from, "to": "now"},
            "templating": {"list": templating or []}, "annotations": {"list": []}, "links": [
                {"title": "OHM usage", "type": "link", "url": "/d/ohm-usage"},
                {"title": "OHM clients", "type": "link", "url": "/d/ohm-clients"},
                {"title": "OHM traffic health", "type": "link", "url": "/d/ohm-traffic-health"}],
            "panels": panels}

API = 'host="api"'; API_W = 'host="api",method=~"PUT|POST|DELETE"'; API_R = 'host="api",method="GET"'
BOTS = 'agent=~"bot:.*",blocked="no"'; NB = 'blocked="no"'; BL = 'blocked="yes"'; MH = 'host="$main_host"'; VT = 'host="vtiles"'
S403 = 'status="403"'; HITS = 'cache=~"hit|stale|revalidated",host=~"$main_host"'; MHS = 'host=~"$main_host"'
# How the daily gauges behave: the value for day D is pushed hourly from D+1 00:10 to
# D+2 00:10. Panels use a 1d step aligned to 00:00 UTC, so at the point for day D we
# read the last sample inside [D+2 00:00, D+3 00:00) = the finalized value of day D.
# That is `last_over_time(m[1d] offset -2d)` (negative offsets are on in Prometheus 3).
# Same idea for hourly gauges with a 1h step. "Yesterday" stats read the raw gauge.
D = lambda m, sel="": f'last_over_time({m}{{{sel}}}[1d] offset -2d)'
DBY = lambda m, by, sel="": f'max by ({by}) (last_over_time({m}{{{sel}}}[1d] offset -2d))'
NOW = lambda m, sel="": f'{m}{{{sel}}}'                       # raw gauge = yesterday's value
NOWBY = lambda m, by, sel="": f'max by ({by}) ({m}{{{sel}}})'
MONTH = lambda expr: f'sum_over_time(({expr})[30d:1d])'   # one finalized value per day, 30 days
H = lambda m: f'last_over_time({m}[1h] offset -2h)'

# Fixed, ordered host list (bare domain first). A query variable would sort alphabetically.
HOSTS = ["openhistoricalmap.org", "www", "api", "vtiles", "static-tiles", "nominatim", "overpass-api", "overpass-turbo",
         "tasks", "tm-api", "taginfo", "forum", "planet", "planet-stats", "osmcha", "embed", "level0"]
def custom_var(name, label, selected, hosts=HOSTS):
    return {"name": name, "label": label, "type": "custom", "query": ",".join(hosts), "multi": True, "includeAll": True, "allValue": ".*",
            "options": [{"text": "All", "value": "$__all", "selected": selected is None}] +
                       [{"text": h, "value": h, "selected": bool(selected) and h in selected} for h in hosts],
            "current": {"selected": True, "text": ["All"] if selected is None else selected, "value": ["$__all"] if selected is None else selected}}
host_var = custom_var("host", "Host", None)
# Tools with real volume; the bare domain only redirects to www and is left out.
MAIN_HOSTS = [h for h in HOSTS if h != "openhistoricalmap.org"]
main_hosts_var = custom_var("main_host", "Main hosts", ["www", "api", "vtiles", "static-tiles"], MAIN_HOSTS)

# ---------------------------------------------------------------- 1. OHM usage
y = 0; P = []
P.append(row("People on the website (Web Analytics sessions on www; JS beacon, so most bots are out)", y)); y += 1
P += [
    stat("People on www, yesterday", NOW("ohm_cf_host_visits_daily", 'host="www"'), 0, y, w=6, desc="Browser sessions on www.openhistoricalmap.org (Cloudflare Web Analytics, JS beacon). Simple bots and scripts do not run the beacon; headless browsers still can.", color=PAL[0]),
    stat("People on www, last 30 days", MONTH(D("ohm_cf_host_visits_daily", 'host="www"')), 6, y, w=6, desc="Sum of the daily sessions on www.", color=PAL[0]),
    ts("People on www per day", [tgt(D("ohm_cf_host_visits_daily", 'host="www"'), "sessions")], 12, y, w=12, h=6, bars=True, single_color=PAL[0], legend=False,
       desc="Sessions of real browsers on the website. api.* is left out on purpose: headless browsers scraping HTML there trigger the beacon too."),
]; y += 6
P.append(row("Traffic per day: requests and unique IPs (all hostnames, bots and blocked included)", y)); y += 1
P += [
    stat("Requests, yesterday", NOW("ohm_cf_requests_daily"), 0, y, w=6, desc="Every request that reached Cloudflare for *.openhistoricalmap.org, including the ones it blocked."),
    stat("Unique IPs, yesterday", NOW("ohm_cf_uniques_daily"), 6, y, w=6, desc="Distinct client IPs across the whole zone: tiles, API, JOSM, scripts and bots. Not people."),
    stat("Requests, last 30 days", MONTH(D("ohm_cf_requests_daily")), 12, y, w=6),
    stat("Blocked by Cloudflare, yesterday", f'sum({NOWBY("ohm_cf_status_requests_daily", "status", S403)}) / sum({NOW("ohm_cf_requests_daily")})', 18, y, w=6, unit="percentunit", decimals=0, desc="Share of yesterday's requests answered with 403 by WAF / rate-limit rules."),
]; y += 4
P += [
    ts("Requests per day", [tgt(D("ohm_cf_requests_daily"), "requests")], 0, y, bars=True, single_color=PAL[0], legend=False, desc="Exact, from Cloudflare. Includes blocked requests."),
    ts("Unique IPs per day", [tgt(D("ohm_cf_uniques_daily"), "unique IPs")], 12, y, bars=True, single_color=GRAY, legend=False, desc="Exact, from Cloudflare. Includes bots and scripts."),
]; y += 8
P.append(row("Traffic per hour: requests, unique IPs and sessions (all hostnames, bots and blocked included; previous full hours, UTC)", y)); y += 1
HBY = lambda m, by, sel="": f'max by ({by}) (last_over_time({m}{{{sel}}}[1h] offset -2h))'
P += [
    ts("Requests per hour, all hostnames", [tgt(H("ohm_cf_requests_hourly"), "requests")], 0, y, w=8, bars=True, single_color=PAL[0], legend=False, interval="1h",
       desc="Exact, from Cloudflare."),
    ts("Unique IPs per hour, all hostnames", [tgt(H("ohm_cf_uniques_hourly"), "unique IPs")], 8, y, w=8, bars=True, single_color=GRAY, legend=False, interval="1h",
       desc="Exact, from Cloudflare. Hours do not add up: an IP active all day counts in every hour."),
    ts("Sessions on www per hour (people)", [tgt(H('ohm_cf_host_visits_hourly{host="www"}'), "sessions")], 16, y, w=8, bars=True, single_color=PAL[0], legend=False, interval="1h",
       desc="Web Analytics sessions on www in that hour. Same meaning as 'People on www' above, hourly."),
]; y += 8
HS = lambda sel: f'sum(max by (status) (last_over_time(ohm_cf_status_requests_hourly{{{sel}}}[1h] offset -2h)))'
P += [
    ts("Requests per hour by hostname (subdomain)", [tgt(HBY("ohm_cf_host_requests_hourly", "host", 'host=~"$host"'), "{{host}}")], 0, y, w=12, h=9, bars=True, stack=True, colors=HOST_COLORS, interval="1h",
       desc="Sampled estimate scaled to the exact hourly total. Filter with the Host selector."),
    ts("Requests per hour by response class", [
        tgt(HS('status=~"2.."'), "2xx ok", "A"), tgt(HS('status=~"3.."'), "3xx redirect", "B"), tgt(HS('status="403"'), "403 blocked by Cloudflare", "C"),
        tgt(HS('status="429"'), "429 rate limited", "D"), tgt(HS('status=~"4..",status!~"403|429"'), "other 4xx", "E"), tgt(HS('status=~"5.."'), "5xx errors", "F")],
       12, y, w=12, h=9, bars=True, stack=True, colors=STATUS_COLORS, interval="1h", desc="Blocked and failing requests hour by hour. A jump in 403 = an attack being stopped; 5xx = something broke in the cluster."),
]; y += 9
P.append(row("Traffic per day by hostname (subdomain: vtiles, api, www, nominatim, ...)", y)); y += 1
P.append(ts("$host", [tgt(DBY("ohm_cf_host_requests_daily", "host", 'host=~"$host"'), "{{host}}")], 0, y, w=6, h=6, bars=True, single_color=PAL[0], legend=False,
            desc="Requests per day on this hostname. Sampled estimate scaled to the exact zone total.", repeat="host", max_per_row=4)); y += 6
P += [
    table("Requests by hostname, last 30 days", f'sort_desc(sum by (host) ({MONTH(DBY("ohm_cf_host_requests_daily", "host"))}))', 0, y, w=8, value_name="requests (30d)"),
    table("Unique IPs by hostname, yesterday (sampled, undercounts)", 'sort_desc(max by (host) (ohm_cf_host_unique_ips_daily))', 8, y, w=8, value_name="unique IPs",
          desc="Distinct IPs among Cloudflare's sampled rows. Good for ranking hostnames against each other, not an exact total (the Free plan only has exact uniques for the whole zone)."),
    table("Sessions by hostname, yesterday (Web Analytics, HTML sites only)", 'sort_desc(max by (host) (ohm_cf_host_visits_daily))', 16, y, w=8, value_name="sessions",
          desc="Only HTML sites carry the beacon. api = headless scrapers, not people."),
]; y += 10
P.append(row("Where do the requests come from? (country and device, blocked requests excluded)", y)); y += 1
P += [
    ts("Requests per day by country, top 10", [tgt(f'topk(10, {DBY("ohm_cf_country_requests_daily", "country")})', "{{country}}")], 0, y, w=12, h=9, bars=True, stack=True,
       desc="Client country from Cloudflare, ISO code. 403s excluded so a blocked scraper does not dominate. Sampled estimate."),
    table("Requests by country, last 30 days", f'sort_desc(sum by (country) ({MONTH(DBY("ohm_cf_country_requests_daily", "country"))}))', 12, y, w=6, h=9, value_name="requests (30d)"),
    ts("Requests per day by device", [tgt(DBY("ohm_cf_device_requests_daily", "device"), "{{device}}")], 18, y, w=6, h=9, bars=True, stack=True,
       colors={"desktop": PAL[0], "mobile": PAL[1], "tablet": PAL[2], "unknown": GRAY}, desc="Cloudflare's device classification from the User-Agent."),
]; y += 9
usage = dash("ohm-usage", "OHM usage", P, "How many people use OHM and how much each hostname (subdomain) is used. Source: Cloudflare, via the cloudflare-stats CronJob.", [host_var])

# ---------------------------------------------------------------- 2. OHM clients
_id[0] = 100; y = 0; P = []
P.append(row("Who sends the requests? (User-Agent family, all hostnames)", y)); y += 1
P += [
    ts("Requests per day by client, top 10 (only requests Cloudflare let through)", [tgt(f'topk(10, {DBY("ohm_cf_agent_requests_daily", "agent", NB)})', "{{agent}}")], 0, y, w=16, h=13, bars=True, stack=True, colors=AGENT_COLORS,
       desc="Classified from the User-Agent header, 403s excluded. browser:* = real or headless browsers; bot:* = declared crawlers; curl/python = scripts. Legend sorted by yesterday's value."),
    ts("Blocked by Cloudflare (403) per day by client", [tgt(f'topk(5, {DBY("ohm_cf_agent_requests_daily", "agent", BL)})', "{{agent}}")], 16, y, w=8, h=13, bars=True, stack=True, colors=AGENT_COLORS,
       desc="What the WAF / rate limit rules stopped. On 2026-09-24, 93% of all 'Chrome' traffic was one fixed UA string (Chrome/151, Windows) hammering vtiles from US, BR, CO, EC, VE, ID, and Cloudflare blocked it."),
]; y += 13
P += [
    table("Requests by client, last 30 days (let through)", f'sort_desc(sum by (agent) ({MONTH(DBY("ohm_cf_agent_requests_daily", "agent", NB))}))', 0, y, w=12, h=12, value_name="requests (30d)"),
    table("Requests by client, yesterday (let through)", 'sort_desc(max by (agent) (ohm_cf_agent_requests_daily{blocked="no"}))', 12, y, w=6, h=12, value_name="requests"),
    ts("Share of declared bots", [tgt(f'sum({DBY("ohm_cf_agent_requests_daily", "agent", BOTS)}) / sum({DBY("ohm_cf_agent_requests_daily", "agent", NB)})', "bots")],
       18, y, w=6, h=12, unit="percentunit", single_color=GRAY, legend=False, min_=0, decimals=2,
       desc="Requests from crawlers that identify themselves (Googlebot, GPTBot, Ahrefs, ClaudeBot...) over all requests. Usually under 1%: the heavy scrapers pretend to be Chrome and cannot be told apart by User-Agent."),
]; y += 12
P.append(row("Which clients use each hostname?", y)); y += 1
P.append(ts("$main_host", [tgt(f'topk(5, {DBY("ohm_cf_host_agent_requests_daily", "agent", MH)})', "{{agent}}")], 0, y, w=12, h=8, bars=True, stack=True, colors=AGENT_COLORS,
            desc="Top 5 clients per day on this hostname.", repeat="main_host", max_per_row=2)); y += 8
P.append(row("HTTP methods", y)); y += 1
P += [
    ts("Requests per day by method, all hostnames", [tgt(DBY("ohm_cf_method_requests_daily", "method"), "{{method}}")], 0, y, bars=True, stack=True,
       colors={"GET": PAL[0], "POST": PAL[1], "PUT": PAL[2], "DELETE": PAL[4], "OPTIONS": GRAY, "HEAD": "#c3c2b7"}, desc="GET dominates: tiles and map reads."),
]; y += 8
P.append({"id": nid(), "type": "barchart", "title": "Requests by hostname and method, yesterday", "datasource": DS,
    "description": "One bar per hostname, stacked by HTTP method. 403s are included here.",
    "gridPos": {"x": 0, "y": y, "w": 24, "h": 11},
    "targets": [{"refId": "A", "datasource": DS, "instant": True, "range": False, "format": "table",
                 "expr": 'max by (host, method) (ohm_cf_host_method_requests_daily)'}],
    "transformations": [
        {"id": "groupingToMatrix", "options": {"columnField": "method", "rowField": "host", "valueField": "Value", "emptyValue": "zero"}},
        {"id": "sortBy", "options": {"sort": [{"field": "GET", "desc": True}]}}],
    "options": {"orientation": "horizontal", "stacking": "normal", "xField": "host\\method", "showValue": "never", "barWidth": 0.8, "groupWidth": 0.7,
                "legend": {"showLegend": True, "displayMode": "list", "placement": "bottom"}, "tooltip": {"mode": "multi", "sort": "desc"}},
    "fieldConfig": {"defaults": {"unit": "short", "custom": {"axisPlacement": "auto", "fillOpacity": 80, "lineWidth": 1}},
                    "overrides": overrides({"GET": PAL[0], "POST": PAL[1], "PUT": PAL[2], "DELETE": PAL[4], "OPTIONS": GRAY, "HEAD": "#c3c2b7"})}}); y += 11
clients = dash("ohm-clients", "OHM clients", P, "Which apps, browsers, scripts and bots send the traffic, per hostname. Source: Cloudflare User-Agent data.", [main_hosts_var])

# ---------------------------------------------------------------- 3. OHM traffic health
_id[0] = 200; y = 0; P = []
P.append(row("Right now (hourly from Cloudflare, live from the tunnel)", y)); y += 1
P += [
    ts("Requests per hour, all hostnames", [tgt(H("ohm_cf_requests_hourly"), "requests")], 0, y, w=8, bars=True, single_color=PAL[0], legend=False, desc="Previous full hours, UTC.", interval="1h"),
    ts("Unique IPs per hour", [tgt(H("ohm_cf_uniques_hourly"), "unique IPs")], 8, y, w=8, bars=True, single_color=GRAY, legend=False, desc="Hours do not add up: an IP active all day counts in every hour.", interval="1h"),
    ts("Tunnel requests/s (Hetzner cloudflared)", [tgt('sum(rate(cloudflared_tunnel_total_requests[5m]))', "req/s", "A"), tgt('sum(rate(cloudflared_tunnel_request_errors[5m]))', "errors/s", "B")],
       16, y, w=8, unit="reqps", colors={"req/s": PAL[0], "errors/s": "#c62828"}, decimals=1, desc="Live, only the traffic that reaches the Hetzner cluster. Blocked and cached requests never get here.", interval="1m"),
]; y += 8
P.append(row("Blocked and errors (per day)", y)); y += 1
S = lambda sel: f'sum({DBY("ohm_cf_status_requests_daily", "status", sel)})'
P += [
    ts("Requests per day by response class", [
        tgt(S('status=~"2.."'), "2xx ok", "A"), tgt(S('status=~"3.."'), "3xx redirect", "B"), tgt(S('status="403"'), "403 blocked by Cloudflare", "C"),
        tgt(S('status="429"'), "429 rate limited", "D"), tgt(S('status=~"4..",status!~"403|429"'), "other 4xx", "E"), tgt(S('status=~"5.."'), "5xx errors", "F")],
       0, y, w=16, bars=True, stack=True, colors=STATUS_COLORS, desc="403 = WAF or rate-limit rules in Cloudflare. 5xx = the origin failed (Martin, Rails, cgimap)."),
    ts("Share blocked by Cloudflare (403)", [tgt(f'{S(S403)} / sum({DBY("ohm_cf_status_requests_daily", "status")})', "403 share")],
       16, y, w=8, unit="percentunit", single_color=PAL[1], legend=False, min_=0, max_=1, decimals=1, desc="On 2026-09-21 this was 58%, almost all on vtiles."),
]; y += 8
P.append(row("Cloudflare cache (tiles: a hit never reaches Martin)", y)); y += 1
C = lambda sel: f'sum by (host) (last_over_time(ohm_cf_host_cache_requests_daily{{{sel}}}[1d] offset -2d))'
P += [
    ts("Cache hit ratio per day by host", [tgt(f'{C(HITS)} / {C(MHS)}', "{{host}}")],
       0, y, unit="percentunit", colors=HOST_COLORS, min_=0, max_=1, decimals=0, desc="(hit + stale + revalidated) / all requests on that host. vtiles at 0% means every tile is rendered by Martin."),
    ts("vtiles requests per day: where they end", [
        tgt(f'sum({DBY("ohm_cf_host_status_requests_daily", "status", VT + ",status=\"403\"")})', "blocked by Cloudflare (403)", "A"),
        tgt(f'sum({DBY("ohm_cf_host_cache_requests_daily", "cache", VT + ",cache=~\"hit|stale|revalidated\"")})', "served by Cloudflare cache", "B"),
        tgt(f'clamp_min(sum({DBY("ohm_cf_host_status_requests_daily", "status", VT + ",status!=\"403\"")}) - sum({DBY("ohm_cf_host_cache_requests_daily", "cache", VT + ",cache=~\"hit|stale|revalidated\"")}), 0)', "passed to the cluster (Varnish, then Martin)", "C")],
       12, y, bars=True, stack=True,
       colors={"blocked by Cloudflare (403)": PAL[1], "served by Cloudflare cache": PAL[5], "passed to the cluster (Varnish, then Martin)": PAL[0]},
       desc="Blocked and passed come from the same per-host status breakdown. Cloudflare has no Cache Rule for .pbf, so it serves almost nothing itself; what passes reaches Varnish in the cluster (about 68% hit there) and only Varnish misses reach Martin. Varnish is not visible from Cloudflare."),
]; y += 8
P.append(row("Stats job", y)); y += 1
P += [
    stat("Minutes since last successful run", "(time() - ohm_cf_last_success_timestamp) / 60", 0, y, w=6, unit="m", desc="The CronJob runs every hour at :10.",
         thresholds={"mode": "absolute", "steps": [{"color": "green", "value": None}, {"color": "orange", "value": 90}, {"color": "red", "value": 180}]}),
    stat("Hour reported", "ohm_cf_stats_hour * 1000", 6, y, w=6, unit="dateTimeAsIso"),
    stat("Day reported", "ohm_cf_stats_day * 1000", 12, y, w=6, unit="dateTimeAsIso"),
    stat("Sampling scale", "ohm_cf_sample_scale", 18, y, w=6, decimals=3, desc="exact daily total / sum of Cloudflare's sampled estimate. Breakdowns are multiplied by this."),
]; y += 4
health = dash("ohm-traffic-health", "OHM traffic health", P, "Blocked requests, errors, cache efficiency and the live tunnel rate. For operations.", [main_hosts_var], time_from="now-7d")

for name, d in [("ohm_usage.json", usage), ("ohm_clients.json", clients), ("ohm_traffic_health.json", health)]:
    ids = [p["id"] for p in d["panels"]]; assert len(ids) == len(set(ids)), name
    json.dump(d, open(os.path.join(OUT, name), "w"), indent=2)
    print(name, "panels:", len(d["panels"]))
