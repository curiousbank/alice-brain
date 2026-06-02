# CG/Alice Agent Bridge

The bridge now uses a Redis-first protocol with the original file bridge as fallback.

## Transport Order

1. Redis Streams, preferred for live agent messages.
2. File bridge over SSH/SCP, fallback and human-readable audit trail.

Redis is hosted on SUN at `127.0.0.1:6379`, DB 15 by default. Do not expose Redis publicly. Alice should reach it through an SSH tunnel.

## Streams

- `agent:cg:to_alice`
- `agent:alice:to_cg`
- `agent:health`
- `agent:events`

Messages are structured fields:

- `from`
- `to`
- `type`
- `priority`
- `subject`
- `body`
- `created_at`
- `requires_ack`

## Files

SUN paths:

- `/home/wb/Desktop/alice-brain/bridge/to-alice.md`
- `/home/wb/Desktop/alice-brain/bridge/from-alice.md`
- `/home/wb/Desktop/alice-brain/bridge/latest-from-alice.md`

Local Alice mirror:

- `~/Desktop/alice-brain/bridge/to-alice.md`
- `~/Desktop/alice-brain/bridge/from-alice.md`

File format remains:

```md
## 2026-06-01T14:18:55-04:00 CG -> Alice
Subject: short subject
Transport: redis-stream
Redis-Id: 1780338765597-0
Priority: normal

Message body here.
---
```

## CLI

Shared CLI:

```sh
~/Desktop/alice-brain/bin/agent_bridge status --role cg
~/Desktop/alice-brain/bin/agent_bridge health --role cg
~/Desktop/alice-brain/bin/agent_bridge send --from cg --to alice --subject "Status" --body "Ping"
~/Desktop/alice-brain/bin/agent_bridge poll-once --role cg
```

SUN defaults:

```sh
AGENT_BRIDGE_REDIS_URL=redis://127.0.0.1:6379/15
```

Alice should use an SSH tunnel to SUN Redis, preferably on local port `6389` so it does not collide with any local Redis:

```sh
ssh -N -L 6389:127.0.0.1:6379 sun-dev
export AGENT_BRIDGE_REDIS_URL=redis://127.0.0.1:6389/15
```

If Redis is unavailable, `agent_bridge send` writes the same message to the file bridge. If Redis is healthy, messages are also mirrored to files for audit/readability.

## Alice Without redis-cli

If Alice does not have `redis-cli`, use a tiny compatibility shim instead of installing a full Redis toolchain. The shim must support only the commands `agent_bridge` uses:

- `-u redis://127.0.0.1:6389/15 --json PING` -> JSON string `"PONG"`.
- `-u redis://127.0.0.1:6389/15 --raw XADD <stream> MAXLEN ~ <n> * <field value...>` -> plain stream id.
- `-u redis://127.0.0.1:6389/15 --json XREAD COUNT <n> STREAMS <stream> <last_id>` -> redis-cli 7 style JSON object, for example `{"agent:cg:to_alice":[["1780339268047-0",["from","cg","body","ping"]]]}`.

The shim should return a nonzero exit code and write stderr on tunnel/protocol errors. Do not implement broad Redis admin commands. Redis access must stay behind the SSH tunnel.

Example Alice runtime:

```sh
ssh -N -L 6389:127.0.0.1:6379 sun-dev
export AGENT_BRIDGE_REDIS_CLI=~/Desktop/alice-brain/bin/redis_bridge_cli
export AGENT_BRIDGE_REDIS_URL=redis://127.0.0.1:6389/15
~/Desktop/alice-brain/bin/agent_bridge status --role alice
~/Desktop/alice-brain/bin/agent_bridge poll-once --role alice
```

## Watchers

SUN watcher:

```sh
systemctl --user status cg-alice-bridge-watch.service
```

It polls Redis first through `agent_bridge poll-once --role cg`, then checks `from-alice.md` for file fallback changes.

Alice watcher template:

```sh
~/Desktop/alice-brain/bin/alice_bridge_watch
```

It polls Redis first through `agent_bridge poll-once --role alice`, then falls back to pulling SUN's `to-alice.md` over `scp`.

## Health Contract

Both agents should be able to report bridge health at any time:

```sh
~/Desktop/alice-brain/bin/agent_bridge status --role cg
~/Desktop/alice-brain/bin/agent_bridge status --role alice
```

Health output includes:

- Redis reachable or not.
- Preferred transport.
- File fallback paths.
- Current Redis stream names.
- Last consumed Redis message id.

Health events are also written to `agent:health` when Redis is available and to `agent-bridge-events.jsonl` locally.

## Safety

- Redis must stay bound to localhost.
- Alice should connect through SSH tunnel only.
- The file bridge stays as backup and manual override.
- Codex auto-run remains disabled unless `CG_BRIDGE_CODEX_ENABLED=1` is intentionally set in the SUN watcher service.
