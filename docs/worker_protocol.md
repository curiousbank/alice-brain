# Secure Worker Protocol

Alice Brain nodes are treated as untrusted compute providers.

## Actors

- **SUN/PB controller**: owns queue, policy, validation, storage, frontend records, and MAZA bake accounting.
- **Oven Registry**: Pinball web interface for node enrollment, public payout address registration, scoped worker-token issuance, and health/payout visibility.
- **Alice Brain node**: polls work, computes locally, returns a file or answer, and reports health.
- **RoRe**: private Redis/file control-plane for agent messages, receipts, and health events.

## Rules

1. Nodes do not receive production database credentials.
2. Nodes do not receive object-storage credentials.
3. Nodes do not receive MAZA wallet private keys.
4. Nodes do not choose public file URLs or storage keys.
5. Nodes call token-protected worker endpoints over outbound HTTPS. Loopback HTTP
   is allowed only for explicit local development.
6. Nodes include `worker_id`, `node_id`, `MAZA_ADDRESS`, model names, file hashes, and manifest metadata in completion payloads.
7. SUN/PB accepts or rejects completed work.
8. Accepted work can become a Bake.
9. Oven Registry records public node identity and scoped credentials, never private wallet or infrastructure secrets.
10. Pending, paused, and revoked ovens must not authenticate.

## Job Lifecycle

```text
user registers oven on /ai
  -> SUN/PB records approved default oven with scoped safe lanes
  -> SUN/PB shows one-time setup bundle
  -> node saves .env locally and opens outbound tunnels
SUN/PB queues job
  -> node polls /next with X-Autos-Worker-Queue
  -> SUN returns scoped payload and complete/fail/heartbeat endpoints
  -> node runs local embedder/LLM/vision
  -> node creates artifact and manifest
  -> node POSTs complete with file payload
  -> SUN validates file and manifest
  -> SUN stores the file at an approved object-storage path
  -> SUN updates frontend record
  -> SUN records accepted Bake for MAZA payout
```

`X-Autos-Worker-Queue` can be:

- `all`: any PB/AUTOS answer job.
- `web`: non-Telegram PB/AUTOS answer jobs.
- `telegram`: Telegram-only PB/AUTOS answer jobs.
- `embeddings`: embedding jobs only.
- `sms_bot`: private, customer-facing SMS drafts only.

Run `telegram` as a second worker process when chat responsiveness matters.
Run `sms_bot` as a dedicated process. Generic workers do not claim this lane,
and the SMS worker rejects any payload outside the `sms_bot_compute` surface.
It uses only controller-supplied, scoped business context and does not run
embeddings or add Alice Brain's public product context.

## Completion Manifest Requirements

Nodes should include:

- `worker_id`
- `node_id`
- `maza_address`
- `provider`
- `model`
- `embedder_model`
- `word_count` or task-specific output metrics
- `byte_size`
- `docx_signature` or file type proof
- `file_sha256` in `bake`
- `source_artifact_id`
- `source_deal_id` or source job id
- `quality_errors`
- `quality_warnings`
- `pipeline`
- `bake`

Example:

```json
{
  "worker_id": "alice-example-01",
  "node_id": "alice-example-01",
  "maza_address": "public_maza_address",
  "provider": "qwen/local",
  "model": "qwen3:8b",
  "embedder_model": "qwen3-embedding:4b",
  "bake": {
    "eligible": true,
    "unit": "completed_answer",
    "source": "pinball.answer",
    "source_artifact_id": 123,
    "worker_id": "alice-example-01",
    "node_id": "alice-example-01",
    "maza_address": "public_maza_address",
    "file_sha256": "..."
  }
}
```

## RoRe Boundary

RoRe is useful for:

- health checks,
- ACKs,
- status messages,
- operator coordination,
- non-secret diagnostics.

RoRe is not:

- the production database,
- the file storage layer,
- a public message bus,
- a payment ledger,
- a wallet.

Alice Brain advertises its safe worker capabilities through the authenticated
HTTPS request. SUN/PB is the only gateway to RoRe's coordination store:
PostgreSQL remains authoritative for policy, job state, billing, and results,
while Redis Streams may coordinate queue hints, leases, heartbeats, ACKs, and
retry recovery. Oven nodes never need a Redis URL or Redis credential.
