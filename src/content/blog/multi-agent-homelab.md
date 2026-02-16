---
title: "Building a Multi-Agent Homelab"
description: "How we built a system where AI agents plan, execute, coordinate, and hand off work — and what we learned along the way."
pubDate: 2026-02-16
---

Running one AI agent against your infrastructure is straightforward. Running seven of them, each with different responsibilities, coordinating through shared databases and message queues while maintaining operational safety — that's a different problem entirely.

This is the story of building a multi-agent system for homelab management. Not a toy demo where agents chat with each other in a loop, but a production system where agents plan work, execute tasks, monitor infrastructure, write tests, review code, and hand off context across sessions. It works, mostly. Here's what we learned.

## The Architecture: Planners and Executors

The first design decision — and probably the most important one — was separating planning from execution.

Early on, we tried having each agent be a generalist: plan what needs to happen, do the work, verify the results. This failed in predictable ways. Agents would get tunnel vision, spending hours on implementation details without stepping back to consider whether the approach was right. They'd make architectural decisions in the middle of coding, without consulting other agents who might have relevant context.

The fix was to split agents into two tiers:

**Planners** (we call them "crew") have broad codebase access, can read and analyze anything, and are responsible for designing solutions, triaging work, and coordinating across the system. They can also write code, but their primary job is thinking.

**Executors** (we call them "polecats") are spun up for specific tasks with a narrow scope. They receive a clear assignment from a planner, execute it, and terminate. They don't make architectural decisions. They don't wander.

This mirrors how effective human teams work. The tech lead doesn't write every line of code, but they ensure the code that gets written serves the right purpose. The engineers don't spend their time in planning meetings, but they execute with full context about what needs to happen.

### The Crew Roster

Each planner agent has a defined role:

- **The Orchestrator** coordinates work across all agents. It receives tasks, breaks them into assignments, dispatches to executors, and tracks completion. Think of it as a project manager.
- **The Architect** designs infrastructure changes and reviews proposals from other agents. It understands the system topology and catches "this will break X" problems before they happen.
- **The MCP Specialist** maintains the tooling layer — the APIs and integrations that all agents use to interact with infrastructure.
- **The Operations Agent** runs end-to-end tests, monitors service health, and chases down reliability issues. If something is broken, this agent finds out first.
- **The Developer** handles feature work and bug fixes in application code.
- **The Security Agent** reviews changes for security implications and monitors for vulnerabilities.

Each agent has its own configuration file that defines its identity, responsibilities, tools, and constraints. This isn't cosmetic — it genuinely changes how the agents behave. An agent that knows it's responsible for security actually catches things that a generalist agent would skip.

## How Agents Coordinate

Multiple autonomous agents working on the same infrastructure need a coordination layer. Without one, you get race conditions, conflicting changes, and agents stepping on each other's work. We use three mechanisms.

### Message Passing

Agents can send messages to each other through a lightweight mail system. Messages have an address (the recipient agent), a subject, and a body. The mail system is persistent — messages survive across sessions.

This is how work gets dispatched. The orchestrator reads incoming tasks, decides which agent should handle each one, and sends a message with the assignment. The receiving agent picks up the message at the start of its next session and gets to work.

Messages are also how agents report findings. The operations agent discovers that a service is degrading. It sends a message to the orchestrator with the details. The orchestrator decides whether to file a ticket, dispatch a fix, or escalate to a human.

The critical design decision: messages are asynchronous and non-blocking. An agent sends a message and moves on. It doesn't wait for a response. This prevents the coordination layer from becoming a bottleneck. If agent A needs a response from agent B before proceeding, it files a ticket and yields — agent B will pick it up in its own time.

### Hooks (Direct Assignment)

Sometimes you don't want asynchronous coordination. You want an agent to start working on something immediately when it wakes up. That's what hooks do.

A hook is a piece of work attached directly to an agent's startup sequence. When the agent starts a new session, it checks for hooks first. If one is present, it executes immediately — no mail triage, no planning, just work.

We use hooks for two things: automated responses (a monitoring agent detects a failure and hooks work onto the operations agent) and handoffs (an agent runs out of context and hooks its remaining work onto a fresh session).

### Shared Database

All agents share a database of work items (we call them "beads"). Each bead has a status, priority, assignee, and history. Agents can create beads, update them, close them, and comment on them.

The database serves as the system's institutional memory. When an agent starts a session, it can query the database to understand the current state of all ongoing work. When it finishes, its changes are recorded for the next agent to build on.

This is also where audit trails live. Every significant action — code commits, service restarts, configuration changes — gets recorded as a comment on the relevant bead. If something goes wrong, you can reconstruct exactly what happened by reading the bead history.

## Memory Systems

AI agents have a fundamental limitation: they forget everything between sessions. A fresh session starts with zero context about what happened before. In a multi-agent system, this is devastating — agents need to know what other agents have done, what the current state of the infrastructure is, and what work is in flight.

We use three layers of memory:

### Hot Memory (Handoff Files)

When an agent's session ends (either by completion or context exhaustion), it writes a handoff file. This file contains: what it was working on, what it accomplished, what's still pending, and any important context the next session needs. The handoff file is attached as a hook to the next session, so the replacement agent starts with full context.

This is the most critical memory layer. Without it, every session starts from scratch. With it, work flows continuously across sessions with minimal loss.

### Warm Memory (Work Item Database)

The shared database provides medium-term memory. An agent can query "what happened with the database migration?" and get a chronological history of every action, comment, and status change. This works across agents — the developer's migration work is visible to the operations agent testing it.

### Cold Memory (Search Index)

For deep history, we maintain a search index over the codebase, documentation, and operational records. Agents can search for "how did we solve the certificate renewal problem last time?" and get relevant results. This is slower than the other layers but covers a much wider time horizon.

The key insight about memory systems: they need to be write-friendly. If recording information is cumbersome, agents won't do it. Our work items are created with a single command. Handoff files are generated automatically. Search indexing runs in the background. The less friction there is in writing, the more institutional knowledge accumulates.

## Lessons Learned

### What Works

**Separation of concerns is real.** Having a dedicated operations agent that runs tests every session catches problems that would otherwise slip through the cracks. Having a dedicated security agent means security reviews actually happen. Generalist agents skip things. Specialist agents don't.

**Asynchronous coordination scales.** Our agents don't need to be running simultaneously. They work in serial, passing context through messages and work items. This means we can run on modest hardware — one agent at a time, with context passing doing the work that "real-time communication" would do in a more complex system.

**Mechanical rules beat guidelines.** Instead of telling agents to "be careful with production changes," we give them a hardcoded list of things they must never do and things they must always do. No interpretation required. This eliminates an entire class of "the agent made a bad judgment call" failures.

**Handoff files are the single most important feature.** Everything else can degrade gracefully. If the mail system is slow, work just takes longer. If the search index is stale, agents research manually. But if handoff files break, work is lost. We invested heavily in making handoffs reliable and it's paid for itself many times over.

### What Doesn't Work

**Agents are bad at estimating scope.** A planner agent will confidently say "this should take one session" for a task that actually requires three. We've stopped relying on agent time estimates entirely and instead track actual session counts.

**Coordination overhead is real.** Having seven agents coordinate through messages and tickets creates genuine overhead. Sometimes a single generalist agent would be faster for a simple task because it doesn't need to dispatch, wait, verify, and close. We've learned to match the coordination complexity to the task complexity.

**Context drift is dangerous.** When an agent hands off to a fresh session, some nuance is always lost. After three or four handoffs on the same task, the replacement agent may be operating on subtly stale assumptions. We mitigate this by encouraging agents to re-read source files rather than trusting handoff summaries.

**Shared state needs conflict resolution.** Two agents working on the same git repository will eventually create merge conflicts. Two agents updating the same work item will eventually overwrite each other's changes. We've built conflict resolution into the workflow (rebase before push, check-before-update patterns), but it adds complexity.

### What We'd Do Differently

**Start with two agents, not seven.** The orchestrator and one executor would have covered 80% of our use cases. We added specialization too early and paid for it in coordination costs. Start simple, split when you feel the pain.

**Invest in observability from day one.** We built the agent system before we built good visibility into what agents were doing. For weeks, debugging agent behavior meant reading raw session logs. Build dashboards, metrics, and audit trails before you build the second agent.

**Design for failure modes first.** What happens when an agent crashes mid-task? When the database is unreachable? When two agents try to deploy simultaneously? We answered these questions reactively. You should answer them proactively.

## The Bigger Picture

Building a multi-agent homelab isn't about replacing human operators. It's about amplifying them. A single person managing 15+ containers, multiple databases, CI/CD pipelines, monitoring stacks, and application services cannot personally verify that everything is working, every hour, every day. But a team of agents can — and they can do it with a consistency and patience that humans don't have.

The multi-agent approach works because it maps to how organizations actually operate. You don't hire one person to do everything. You hire specialists who coordinate through well-defined interfaces. The same principle applies to agents: give each one a clear role, clear tools, and clear boundaries, and the system becomes more than the sum of its parts.

The technology to build this exists today. The hard part isn't the AI — it's the coordination, the memory systems, the safety controls, and the operational discipline. Those are engineering problems, not AI problems. And they're solvable.

Start with one agent. Give it a clear job. Add a second when the first is reliable. Build the coordination layer as you need it. And always, always maintain the escape hatch for human override. The agents work for you, not the other way around.
