# Security Notes

Alice Brain is a worker, not a public authority.

## Never Store In This Repo

- worker tokens,
- API keys,
- SSH private keys,
- wallet private keys,
- MAZA seed phrases,
- Redis passwords,
- production database credentials,
- Backblaze credentials,
- generated reports or manifests,
- local bridge logs.

## Node Boundary

- Alice Brain should use outbound SSH tunnels.
- Alice Brain should not expose Redis, HTTP workers, or Ollama to the public internet.
- Alice Brain should not run Thumper.
- Alice Brain should not run a production wallet.
- Alice Brain should not connect directly to production databases.

## Controller Boundary

SUN/PB decides:

- which jobs are available,
- which workers may claim jobs,
- where files are stored,
- whether an artifact passes validation,
- whether a Bake is accepted,
- whether a MAZA payout is sent.

## Oven Registry Boundary

- Public `/ai` views should expose aggregate network health only.
- Exact node names, worker model details, registered oven rows, and setup bundles should be visible only to the owner of that oven or to an approved operator.
- Signed-in users may automatically register a default oven and receive a scoped token for safe lanes.
- Elevated/private lanes should require operator approval.
- Worker tokens should be scoped by lane and stored on SUN/PB only as HMAC digests.
- A paused, pending, or revoked oven must not authenticate against worker endpoints.
- Legacy shared worker tokens should be treated as temporary compatibility and disabled after all active nodes use scoped oven tokens.

## Public Address

`MAZA_ADDRESS` is a public payout address and is safe to include in worker manifests. It is not a private key.
