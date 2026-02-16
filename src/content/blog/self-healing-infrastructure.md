---
title: "Self-Healing Infrastructure with AI Agents"
description: "How to build an automated pipeline where alerts become tracked work, remediation runs itself, and humans only intervene when it matters."
pubDate: 2026-02-15
---

There's a moment in every homelab operator's journey where you realize monitoring isn't enough. You have dashboards. You have alerts. You even have a phone that buzzes at 3 AM when something breaks. But between the alert firing and the fix landing, there's a gap — and in that gap, things get worse.

What if the system could close that gap itself?

This is the story of building self-healing infrastructure: a pipeline where alerts automatically become tracked work items, simple problems fix themselves, and humans only get pulled in when the situation actually requires judgment. It's not science fiction. It's a cron job, some bash scripts, and a clear philosophy about what to automate and what not to.

## The Alert-to-Work Pipeline

Most monitoring setups end at the alert. Prometheus fires, PagerDuty buzzes, someone investigates. The problem with this model is that alerts are ephemeral — they fire, they resolve, and unless someone documents what happened, the institutional knowledge evaporates.

The first piece of self-healing infrastructure is making alerts durable. When an alert fires in our system, it doesn't just ping a notification channel. A small script polls the alerting system every five minutes, looking for alerts that have been firing for at least five minutes (to filter transient blips). When it finds one, it automatically creates a tracked work item — a ticket, an issue, whatever your system uses.

The key details of the pipeline:

- **Severity mapping**: Critical alerts become P0 tickets. Warnings become P1. Informational alerts become P2. This means the triage is already done when a human looks at the queue.
- **Deduplication**: Each alert carries a fingerprint. The system tracks which fingerprints already have open tickets, so you don't get flooded with duplicates during an extended outage.
- **Auto-closure**: When the alert resolves, the corresponding ticket gets closed automatically. If the alert was transient and the system self-healed, the ticket closes itself — no human intervention needed.
- **State tracking**: A local state file maps alert fingerprints to ticket IDs. This survives script restarts and ensures continuity.

The result: your monitoring system generates a complete operational history. Every alert that ever fired has a paper trail. You can answer questions like "how many times did the database alert fire last month?" or "what's the mean time between failures for the message broker?" without digging through alert logs.

## Auto-Remediation: The Careful Parts

Creating tickets from alerts is useful but still reactive. The next step is letting the system fix simple problems on its own.

This is where most people get nervous, and they should. Unrestricted auto-remediation is a great way to turn a minor issue into a major outage. The key insight is that you don't automate remediation broadly — you automate it narrowly, for specific failure modes where the fix is well-understood, low-risk, and easily reversible.

In our system, alerts carry an `sre_action` label that tells the auto-remediation script what kind of response is appropriate. Here are the action categories:

### Restart

The simplest and most common remediation. A service crashed or became unresponsive, and restarting it is likely to fix the problem. The script SSHes to the appropriate host and runs `systemctl restart <service>`.

This works for stateless services, workers, and exporters. It does not work for databases, message brokers with persistent queues, or anything where a restart might cause data loss.

### Cleanup

Disk space alerts often have a predictable fix: rotate logs, clean package caches, remove temp files. The cleanup action runs a sequence of safe operations: journal vacuum (cap log storage), package manager cleanup, and temp directory pruning.

### Investigate / Scale

Some alerts don't have automated fixes. High CPU usage, memory pressure, or capacity warnings require human judgment. For these, the system creates a ticket but takes no automated action. The ticket itself is the remediation — it ensures a human will look at it.

### Credential Refresh

Expired tokens or certificates need human intervention (because the credentials themselves are a security boundary), but the system sends a high-priority notification immediately rather than waiting for someone to notice the dashboard.

## Safety Controls That Actually Work

The remediation script is wrapped in several layers of protection. Each one was added after a real incident.

### The Never-Restart List

Some services must never be restarted automatically, period. Your reverse proxy, your DNS server, your primary database — these are services where an unnecessary restart causes more damage than the original problem. We maintain a hardcoded list of services that are exempt from auto-restart, regardless of what the alert labels say.

This is a mechanical rule, not a judgment call. The script doesn't evaluate whether restarting the DNS server would be safe right now. It simply won't do it. Ever.

### Cooldown Timers

Without cooldowns, a flapping service creates a restart loop: crash, auto-restart, crash, auto-restart, each cycle potentially making things worse. Our system enforces a 30-minute cooldown between restart attempts for the same service. If the service crashes again within that window, the script logs it but takes no action.

For cleanup operations, the cooldown is 60 minutes. Disk space problems that recur within an hour indicate a leak, not a one-time spike.

### Escalation After Repeated Failures

Two restart failures for the same service triggers an escalation. The system sends a notification to the human operator with the full context: what failed, how many times, what the current service state is. This is the "I tried, I can't fix it, you need to look" signal.

The magic number is two, not three or five. In practice, if a restart didn't fix it the first time, a second restart is a coin flip. A third is wishful thinking.

### Audit Trail

Every automated remediation action creates a tracked work item with an `[AUTO-REMEDIATE]` prefix. This means the human operator can review exactly what the system did, when it did it, and what the outcome was. If auto-remediation makes a bad call, the audit trail shows exactly what happened.

State is tracked in a local JSON file that auto-cleans entries older than 24 hours. This prevents stale state from causing bizarre behavior after a long period of stability.

## Predictive Monitoring: Problems Before They Happen

Self-healing is reactive by nature — something breaks, the system fixes it. But the most interesting work happens upstream, in the predictive layer.

### Certificate Expiry

TLS certificates have a known expiry date. There's no reason to wait for them to expire and cause an outage. We push certificate expiry metrics to our monitoring system daily. Alert thresholds fire at 60 days (warning), 30 days (critical), and 14 days (emergency).

Since most modern setups use ACME for automatic renewal, these alerts primarily catch renewal failures — which is exactly the right thing to catch. If auto-renewal is working, the alerts never fire. If it breaks, you get weeks of warning instead of a sudden outage.

### Backup Freshness

Backups are worthless if they stopped running three weeks ago and nobody noticed. We push backup age metrics to our monitoring system every 30 minutes. Each backup job has a maximum acceptable age (typically 26 hours for nightly backups). If a backup is stale, the alert fires.

The key metrics:
- `backup_stale`: Has the backup exceeded its maximum age?
- `backup_exists`: Does the metric exist at all? If not, the monitoring pipeline itself is broken.
- `backup_checker_stale`: Has the freshness checker itself stopped running?

That last one is the meta-alert — monitoring the monitor. If the checker script dies, you need to know.

### Resource Trending

Disk usage that's at 70% today will be at 90% next month if the growth rate is constant. We track disk baselines and flag hosts that are approaching warning thresholds. This gives us time to clean up, resize, or migrate before an alert fires.

## The Human Escalation Boundary

The hardest part of building self-healing infrastructure is deciding where automation stops and human judgment begins. Draw the line too conservatively and you're still getting paged at 3 AM for trivial issues. Draw it too aggressively and the automation causes outages.

Our principle: **automate the response, not the decision**.

Restarting a crashed worker service is a response — there's no decision to make. Migrating a database to a larger volume is a decision — it requires understanding context, evaluating trade-offs, and accepting risk. The first should be automated. The second should be a well-documented ticket that a human picks up.

Some specific boundaries:

**Automate:**
- Service restarts for stateless services
- Log rotation and temp cleanup
- Alert-to-ticket creation
- Backup freshness monitoring
- Certificate expiry warnings

**Don't automate:**
- Database operations (migrations, failovers, schema changes)
- Network changes (firewall rules, routing, DNS delegation)
- Security responses (credential rotation, access revocation)
- Architecture changes (scaling, new service deployment)
- Anything touching money (cloud resources, paid APIs)

There's a meta-principle here too: **the system must never be able to weaken its own safety controls**. Auto-remediation cannot modify the never-restart list. The alert pipeline cannot suppress its own alerts. The escalation system cannot silence itself. These boundaries are enforced mechanically, not by policy.

## Building Your Own Pipeline

If you're running a homelab or small production environment and want to add self-healing capabilities, here's a practical starting point:

1. **Start with the alert-to-ticket pipeline**. This is the lowest risk, highest value piece. Even without auto-remediation, having a durable record of every alert transforms your operational visibility.

2. **Add auto-restart for one or two safe services**. Pick stateless services that crash occasionally and where a restart is always the right fix. Add cooldowns from day one.

3. **Build the never-restart list before you need it**. List every service where an automated restart could cause data loss or cascading failures. Hardcode it. Don't trust future-you to make good judgment calls at 3 AM.

4. **Add predictive monitoring for certificates and backups**. These are the "known unknowns" — things that will definitely break eventually, on a predictable timeline. Catching them early is free reliability.

5. **Keep the audit trail from the start**. When auto-remediation does something unexpected (and it will), you need to be able to reconstruct exactly what happened. Log everything, track state, create tickets.

The goal isn't to eliminate human involvement. It's to eliminate human involvement in situations where the correct response is already known. The humans should be thinking about architecture, capacity planning, and novel failure modes — not restarting the same crashed worker for the fifteenth time.

Self-healing infrastructure isn't a product you buy or a feature you enable. It's a pipeline you build, one carefully-scoped automation at a time. Start small, add safety controls before you add capabilities, and always maintain the escape hatch. The system should heal itself, but a human should always be able to stop it.
