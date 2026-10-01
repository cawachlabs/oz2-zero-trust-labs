# M10 · Reading the event log with jq

Every controller writes its own `/var/log/ziti/events.log` (one JSON event per line). The file is readable only by
the controller's service user, so every command needs `sudo`. These run **on a controller VM** (bash), over SSH from
your workstation:

```powershell
PS> ssh azureuser@<ctrl1-fqdn> "sudo tail -f /var/log/ziti/events.log | jq -c '{t:.namespace,e:.event_type,src:.event_src_id}'"
```

| What you want | On the controller |
|---|---|
| The live feed, one short line per event | `sudo tail -f /var/log/ziti/events.log \| jq -c '{t:.namespace,e:.event_type,src:.event_src_id}'` |
| What this controller has logged, by type | `sudo jq -r '[.namespace, (.event_type // "")] \| join("/")' /var/log/ziti/events.log \| sort \| uniq -c \| sort -rn` |
| Failed circuits, and why | `sudo jq -c 'select(.namespace=="circuit" and .event_type=="failed") \| {timestamp, failure_cause, service_id}' /var/log/ziti/events.log` |
| Cluster events (your own maintenance) | `sudo jq -c 'select(.namespace=="cluster")' /var/log/ziti/events.log` |
| Routers going on/offline | `sudo jq -c 'select(.namespace=="router") \| {timestamp, event_type, router_id}' /var/log/ziti/events.log` |

Each controller logs only what it handled: circuits land on whichever controller a router asked, entity changes
are logged by the leader, and router, link and cluster events by every member. That's why one box's log is never
the whole story — and why the shipper streams from all three into Elasticsearch.

Measured in the field build (2026-10-01): restarting ctrl1 produced five `failed` circuits for `meridian-yard`,
`failure_cause: NO_ONLINE_TERMINATORS`, in the two seconds before the routers re-registered their terminators.
