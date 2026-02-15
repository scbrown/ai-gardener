---
title: "The Golden Rules of Autonomous Agent Operations"
description: "Fifteen mechanical rules that let AI agents operate infrastructure safely and continuously — earned through real production experience."
pubDate: 2026-02-15
---

When you let AI agents operate your infrastructure autonomously, you discover something fast: good intentions don't scale. What scales is mechanical discipline — rules that are simple enough to follow without judgment, strict enough to prevent cascading failures, and universal enough to apply in every context.

These are the golden rules we've developed running autonomous AI agents against real production infrastructure. They aren't aspirational. They're mechanical. Always enforced. No exceptions.

## Why Mechanical Rules?

AI agents are capable of sophisticated reasoning, but that's precisely the problem. A reasoning agent can talk itself into anything. "I'll skip the test this one time because the change is obviously correct." "I'll bundle these three fixes into one commit to save time." "The service seems fine, no need to verify."

Every one of those rationalizations has caused a production incident in our system.

Mechanical rules short-circuit the reasoning. You don't need to evaluate whether this particular situation warrants an exception. The rule is the rule. This turns out to be a feature, not a bug — agents operating under clear mechanical constraints are more reliable than agents operating under nuanced guidelines that require judgment calls.

The rules also create a trust foundation. When a human operator can review an agent's work and see that every commit is atomic, every change is tested, every session ends clean — that builds the kind of trust that lets you expand the agent's autonomy over time.

## The Rules

### 1. Every significant action gets a git commit with a clear message

If it happened and there's no commit, it didn't happen. Git history is the audit trail. An agent that makes changes without committing is an agent whose work can evaporate on the next context cycle.

This sounds obvious until you watch an agent spend twenty minutes tuning a configuration, get interrupted by a higher-priority alert, and lose all the tuning work because it never committed. Now multiply that by dozens of agents across dozens of sessions.

### 2. Check health before AND after changes

The before-check establishes baseline. If the service was already broken when you arrived, your change didn't cause the failure — but you need proof. The after-check verifies your change actually worked and didn't break something adjacent.

Agents that skip the before-check end up chasing phantom regressions. Agents that skip the after-check ship broken changes with false confidence.

### 3. Never skip verification to make something work

When a test fails, the answer is never to disable the test. When a pre-commit hook blocks a commit, the answer is never `--no-verify`. These mechanisms exist because someone — probably after an incident — decided they were necessary.

An agent that bypasses safety checks is worse than an agent that does nothing. At least the idle agent doesn't introduce new failure modes.

### 4. Use DNS names, not IPs

Hardcoded IPs are the cockroaches of infrastructure configuration. They survive every refactor, hide in every corner, and break at the worst possible time when someone finally renumbers a subnet.

DNS names are the abstraction layer that lets infrastructure change underneath without breaking the consumers. Agents that use DNS names produce configurations that are portable and resilient. Agents that hardcode IPs produce configurations that are time bombs.

The exception is bootstrapping and network debugging — sometimes you need the raw IP to get DNS working in the first place.

### 5. Use task runners before raw commands

If your project has a task runner (Make, Just, npm scripts, etc.), use it. Run `just --list` (or equivalent) before reaching for raw commands. The task runner encodes institutional knowledge: the right flags, the correct order of operations, the environment setup that's easy to forget.

An agent running `just deploy` is executing a tested, documented procedure. An agent running a sequence of raw shell commands is improvising.

### 6. One concern per commit

Atomic commits aren't about aesthetics. They're about reversibility. When something breaks and you need to revert, you want to undo exactly the change that caused the problem — not a bundle of three changes where only one is guilty.

Agents love efficiency. They'll naturally want to batch changes. This rule forces them to slow down and keep each commit focused, which pays massive dividends when something inevitably needs to be rolled back.

### 7. If something breaks, revert first, investigate second

The instinct — for humans and agents alike — is to understand why something broke before fixing it. This is backwards in production. First, stop the bleeding. Revert to the last known good state. *Then* investigate at your leisure, with the service healthy.

Agents are especially prone to the "just one more debug attempt" loop, where they keep poking at a broken service trying to understand the failure while the outage clock ticks. The revert-first rule breaks this loop.

### 8. Three failures on the same approach: stop, escalate, try a different angle

This is the anti-brute-force rule. Agents will sometimes get stuck in a loop: try a fix, it fails, try the same fix with minor tweaks, it fails again, tweak again, fail again. Each attempt consumes time and context, and the underlying problem is usually that the approach itself is wrong.

Three strikes forces a step back. Either escalate to a human for fresh perspective, or fundamentally rethink the approach. Don't keep pushing on a door that's clearly bolted shut.

### 9. Never leave a repository in a dirty state at session end

When an agent session ends — whether by completion, timeout, or context limits — the workspace should be clean. All changes committed or stashed. Nothing left in limbo.

This matters because another agent (or a future instance of the same agent) will pick up the workspace next. A dirty repo means merge conflicts, confusion about what was intentional versus in-progress, and lost work. Clean state at session boundaries is a gift to your future self.

### 10. When a gap appears in the rules, propose an update

Rules aren't static. When an agent encounters a situation the rules don't cover, the right response isn't to "just remember for next time." The right response is to propose a new rule or update an existing one.

This creates a feedback loop where the rules get better over time, driven by real operational experience. The alternative — agents accumulating unwritten tribal knowledge — doesn't work when agent contexts reset regularly.

### 11. When access is denied, escalate immediately

Authentication failures, permission denials, and access errors are not retry problems. They're configuration problems. An agent that retries a denied operation ten times is wasting context and potentially triggering lockout mechanisms.

One attempt. If it fails with an access error, escalate to the human operator immediately. The human can fix the permission. The agent cannot.

### 12. Land all work before session handoffs

Agent sessions have finite context. When it's time to hand off to a fresh session, all work must be committed and pushed to the remote. Local-only changes are lost when the session ends.

This sounds simple, but the failure mode is subtle: an agent spends a productive session implementing a fix, writes a detailed handoff note describing the fix, then doesn't push. The next session reads the handoff, tries to build on the fix, and finds it doesn't exist. The work was only local to the previous session's filesystem.

Push first. Document second.

### 13. Bead (issue) closures must include evidence

When closing a work item, include the commit SHAs, any follow-up issues created, and clear reasoning about what changed and why. "Fixed" is not sufficient. "Fixed by correcting the auth header format in commit abc123, follow-up filed for related endpoint at issue #456" is sufficient.

This creates a chain of accountability. Any future investigator can trace from the issue to the exact code changes and understand the reasoning. It also prevents premature closure — if you can't cite a commit, the work probably isn't landed.

### 14. Every code change must reference its tracking issue

The reverse of rule 13. Every commit that changes code or configuration should reference the issue that motivated it. This creates bidirectional traceability: from issue to code, and from code to issue.

When something breaks in production six months from now, the first question is "why was this changed?" The commit message with an issue reference answers that instantly.

### 15. Test deployments before closing the ticket

Don't assume it works. Run the smoke test. Hit the endpoint. Verify the service responds. This is the final gate before declaring victory.

Agents are especially prone to "it compiled, therefore it works" reasoning. The deploy succeeded, the container started, the logs look clean — but nobody actually tested whether the service *does the thing it's supposed to do*. The smoke test catches the gap between "running" and "working."

## The Meta-Rule: Human Input Sovereignty

Above all the mechanical rules sits one principle: human input is the highest authority in the system. Agents can add, propose, and suggest. They cannot remove, override, or weaken anything a human put in place.

This isn't about distrust. It's about maintaining a clear hierarchy of authority in a system where multiple agents operate concurrently. When an agent encounters a human directive it disagrees with, the correct action is to file a proposal explaining the disagreement — not to quietly modify the directive.

This creates an asymmetry that's essential for safety: expanding agent capability requires human approval, but restricting agent capability can be done at any time. The system can always be made more conservative, never less so, without human involvement.

## Why This Works

These rules are deliberately simple. An agent doesn't need to understand distributed systems theory to follow "one concern per commit" or "revert first, investigate second." The rules work because they're mechanical, not because they're clever.

They also compose well. A session where every commit is atomic (rule 6), every change is tested (rules 2 and 15), every issue is properly closed (rules 13 and 14), and the workspace is clean at the end (rule 9) is a session that leaves the system in a strictly better state than it found it. Multiply that across hundreds of sessions, and you get a system that improves continuously.

The real insight is that autonomy and discipline aren't opposites — they're prerequisites for each other. An agent operating under strict mechanical rules earns the trust that lets you expand its scope. An agent operating without rules can never be trusted with more responsibility, because you can never predict what it will do next.

Start with tight rules. Let the agents prove they can follow them. Then, carefully, expand the boundary.

---

*This post is part of a series on operating autonomous AI agents in production environments. These rules come from real operational experience — every one was earned the hard way.*
