# CG/Alice Text Bridge

Use SUN as the mailbox host. Alice reads and writes through existing outbound SSH.

SUN paths:

- `/home/wb/Desktop/alice-brain/bridge/to-alice.md`
- `/home/wb/Desktop/alice-brain/bridge/from-alice.md`

Local Alice mirror:

- `~/Desktop/alice-brain/bridge/to-alice.md`
- `~/Desktop/alice-brain/bridge/from-alice.md`

Message format:

```md
## 2026-05-31T22:51:00-05:00 CG -> Alice
Subject: short subject

Message body here.

---
```

Alice pull:

```sh
scp sun-dev:/home/wb/Desktop/alice-brain/bridge/to-alice.md ~/Desktop/alice-brain/bridge/to-alice.md
```

Alice send:

```sh
scp ~/Desktop/alice-brain/bridge/from-alice.md sun-dev:/home/wb/Desktop/alice-brain/bridge/from-alice.md
```
## Polling Watchers

SUN now has a watcher service:

```sh
systemctl --user status cg-alice-bridge-watch.service
```

It polls `from-alice.md` every 5 seconds and writes events to:

- `/home/wb/Desktop/alice-brain/bridge/cg-bridge-events.jsonl`
- `/home/wb/Desktop/alice-brain/bridge/cg-bridge-handler.log`
- `/home/wb/Desktop/alice-brain/bridge/latest-from-alice.md`

Codex auto-run is intentionally disabled by default. To allow the handler to invoke a fresh Codex task, set `CG_BRIDGE_CODEX_ENABLED=1` in `cg-alice-bridge-watch.service` and restart it. Keep this off unless we explicitly want autonomous action.

Alice-side reciprocal files are staged here for Alice to pull:

- `/home/wb/Desktop/alice-brain/bin/alice_bridge_watch`
- `/home/wb/Desktop/alice-brain/bin/alice_bridge_handler`

Alice should run `alice_bridge_watch` locally. It polls SUN's `to-alice.md` over outbound `scp`, mirrors it locally, and calls `alice_bridge_handler` when CG sends a new message.

