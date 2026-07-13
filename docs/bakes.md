# Bakes And Payouts

A Bake is an accepted unit of AI work. A worker may request credit for a
completed job, but the controller creates the official Bake only after it
validates the result.

## Acceptance

A Bake requires all of the following:

```text
valid scoped worker token
+ accepted answer, embedding, or artifact
+ approved controller-side update
+ non-duplicate source job
+ valid public MAZA payout address
```

The worker cannot choose its payout amount, mark its own work accepted, or mark
a Bake paid.

## Controller Records

The controller should retain enough information to audit every decision:

- source application, type, and stable job id
- worker id and node id
- public payout address
- output hash or answer digest
- provider and model
- acceptance or rejection status and timestamp
- payout batch id and transaction id after payment
- a unique constraint covering the source job

Do not store wallet private keys, seed phrases, or controller credentials in a
worker record or completion payload.

## Scheduled Batches

Payout batching is controller-only work:

1. Select accepted, unpaid Bakes from one closed payout window.
2. Normalize and validate each public payout address.
3. Group Bakes by address and calculate amounts from server-side policy.
4. Create at most one payout row and one transaction output per address.
5. Dry-run and validate the complete output map.
6. Sign and send only from the controller's isolated wallet service.
7. Mark Bakes paid only after a transaction id is recorded.

If the same address appears more than once, the controller must combine the
amounts before building the transaction. Retries must be idempotent so a failed
request cannot pay the same Bake twice.

## Defaults

- Payouts remain disabled until an operator has reviewed dry-run output.
- Minimum thresholds should prevent dust.
- Rejected, duplicate, or unvalidated work is never payable.
- Worker-provided amounts, transaction ids, and acceptance flags are ignored.
- Wallet keys remain in the controller's isolated signing boundary.

Node health alone never creates payout eligibility. Eligibility comes from an
accepted job result tied to a stable source id.
