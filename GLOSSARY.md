# Glossary

This glossary is canonical for this repository and for the *Robot Fleet Deployment*
article series on [blog.bensoussan.de](https://blog.bensoussan.de/tags/robot-fleet/).
Both are written against these exact terms; neither uses a synonym for a concept
already named here.

## Why this exists

The source material this series is drawn from used `deployment stage`, `ring`, and
`tier` for two different concepts, with inverted numbering between them — the same
physical machine was "stage 0" in one place and "tier 3" in another. Twenty-one
articles built on top of that collision would be unreadable, and a lab meant to
prove the articles' claims would be worse: code and prose disagreeing about what a
number means. This glossary resolves it once, here, so it never has to be resolved
again per-article.

## Terms

**Site** — One deployment location: an edge server, its network, and the robot it
drives. A site is a place, not a machine and not a network in isolation — it's the
three together.

**Edge server** — The single server at a site. In production this is bare metal; in
this lab it is a VM standing in for one bare-metal box.

**Hub** — The central cluster. Every site's tunnel dials out to the hub; the hub
never dials into a site. There is exactly one hub in this topology.

**Ring** — A rollout cohort. Ring 0 is the test site. Ring 1 is canaries. Ring 2 is
the fleet. `ring` replaces `deployment stage` from the source material.
**Ring never refers to testing** — a ring is a group of machines that receive a
release in a defined order, nothing more.

**Test site** — The in-house site that always runs the newest build. It is ring 0
for rollout purposes and test level 3 for hardware-in-the-loop purposes. This is one
machine playing both roles under two different classification schemes — it does not
get two names.

**Test level** — The hardware-in-the-loop test pyramid: L1 runs in CI with no
hardware present, L2 runs on one box with a simulator, L3 runs at the test site.
**The word "tier" is not used anywhere in this repository or in the article
series** — where the source material said "tier," this glossary and everything
built on it says "test level."

**App plane** — The application software release path: changes ship via Git and
ArgoCD. A release on the app plane is a restart, never a reboot.

**OS plane** — The operating-system release path: changes ship as signed RAUC
bundles. A release on the OS plane requires a reboot, which the app plane never
does.

**Slot** — One of the two OS images (A or B) an edge server's RAUC setup can boot
into. Exactly one slot is active at a time; the other holds the previous or the
incoming build.

**Bundle** — A signed RAUC artifact installed to an edge server's inactive slot
ahead of a controlled switch. Installing a bundle does not itself take effect until
the switch happens.

**Maintenance window** — The scheduled period during which an OS-plane reboot is
permitted to execute. A bundle can be installed at any time; the switch that makes
it live waits for a maintenance window.

**Safe-to-reboot gate** — The check that must pass — the robot is not mid-motion,
no job is active — before a reboot proceeds, even inside a maintenance window. A
maintenance window says *when* a reboot is allowed; the safe-to-reboot gate says
*whether* it's allowed right now.
