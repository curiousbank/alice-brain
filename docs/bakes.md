# Bakes And 30-Minute MAZA Payouts

Bakes are accepted units of AI work. A worker may request credit for a completed job, but SUN/PB creates the official Bake only after validation.

## Definition

A Bake is not "the node said it worked." A Bake is:

```text
valid worker token
+ accepted output file or answer
+ approved storage/database update
+ non-duplicate source job
+ public MAZA payout address
```

## Suggested PB Tables

The Oven Registry can own or display the node and payout records below.

`ai_relay_nodes`

- `worker_id`
- `node_id`
- `maza_address`
- `status`
- `last_seen_at`
- `last_ip_digest`
- `metadata`
- `created_at`
- `updated_at`

`ai_bakes`

- `source_app`
- `source_type`
- `source_id`
- `worker_id`
- `node_id`
- `maza_address`
- `status`: `accepted`, `rejected`, `paid`
- `file_sha256`
- `storage_key`
- `file_url`
- `byte_size`
- `provider`
- `model`
- `embedder_model`
- `accepted_at`
- `paid_at`
- `payout_tx_id`
- `maza_amount`
- `metadata`
- unique index on `source_app/source_type/source_id`

`ai_bake_payouts`

- `batch_id`
- `maza_address`
- `window_start`
- `window_end`
- `bake_count`
- `maza_amount`
- `tx_id`
- `output_index`
- `status`: `pending`, `sent`, `failed`
- `metadata`

`ai_bake_payout_batches`

- `window_start`
- `window_end`
- `tx_id`
- `total_addresses`
- `total_bakes`
- `total_maza_amount`
- `status`: `draft`, `sent`, `failed`
- `metadata`

## 30-Minute Thumper Flow

Run every 30 minutes on SUN/PB only:

```text
Find accepted unpaid ai_bakes for the last closed 30-minute window.
Group by maza_address.
Calculate payout amount from bake_count and configured rate.
Create one payout batch for the window.
Create one payout row/output per address inside that batch.
Send one batched MAZA transaction using PB wallet code only if AI_BAKES_PAYOUT_ENABLED=1.
Mark grouped bakes paid with the shared payout tx_id and each address output_index.
```

## Duplicate Address Rule

The payout builder must collapse duplicate addresses before it builds or sends the 30-minute batch transaction.

Required behavior:

- normalize and validate every public `maza_address`,
- group all accepted unpaid bakes by normalized address and closed 30-minute window,
- sum `maza_amount` for every bake in the group,
- create exactly one `ai_bake_payout_batches` row for the closed 30-minute window,
- create at most one `ai_bake_payouts` row per address inside that batch,
- create at most one transaction output per address in the 30-minute batch transaction,
- mark all grouped bakes paid only after the shared batch transaction has a `tx_id`.

If a payout build sees the same address twice, that is not two payments. It is one address with a larger amount.

Reference shape:

```ruby
groups = accepted_unpaid_bakes.group_by { |bake| normalize_maza_address(bake.maza_address) }
batch = create_thirty_minute_batch(window_start:, window_end:)

groups.each do |maza_address, bakes|
  total_amount = bakes.sum(&:maza_amount)
  bake_count = bakes.size
  create_or_update_payout(batch:, maza_address:, bake_count:, maza_amount: total_amount)
end
```

If duplicate pending payout rows already exist for the same `batch_id/maza_address`, PB should merge them or void the duplicates before sending. Never send two outputs to the same address in one AI bake payout batch.

## 30-Minute Batch Transaction

The preferred payout shape is one MAZA transaction every 30 minutes for all active nodes:

```text
thirty_minute_ai_bake_batch_tx
  output 0 -> node address A, summed payout for address A
  output 1 -> node address B, summed payout for address B
  output 2 -> node address C, summed payout for address C
```

This keeps fees, logs, and explorer review simple. The batch transaction is the payment proof. Each `ai_bake_payouts` row points to the shared `tx_id` plus its own `output_index`.

If the wallet RPC supports a native multi-recipient call such as `sendmany`, PB should use that for the 30-minute batch. If not, PB should build an equivalent raw transaction with one output per normalized address. Either way, the builder must preflight the output map before signing or sending:

```ruby
outputs = payouts.each_with_object({}) do |payout, map|
  map[payout.maza_address] ||= BigDecimal("0")
  map[payout.maza_address] += payout.maza_amount
end
```

Default safety:

- payout service dry-runs unless explicitly enabled,
- minimum payout threshold can prevent dust,
- never pay a bake twice,
- never pay bakes without accepted storage output,
- never let a worker provide its own payout amount.

## Suggested Env

```sh
AI_BAKES_ENABLED=1
AI_BAKES_PAYOUT_ENABLED=0
AI_OVEN_PAYOUT_INTERVAL_MINUTES=30
AI_OVEN_MAZA_PER_BAKE=5
AI_OVEN_RESERVE_PERCENT=24
AI_OVEN_PAYOUT_SOURCE_MAZA_ADDRESS=MNHxyG4ZRD5acR9HAjfWnSFBHMKmCvTGLD
AI_BAKES_MIN_PAYOUT_MAZA=5
```

`AI_BAKES_PAYOUT_ENABLED` should remain `0` until an operator has reviewed the exact dry-run batch outputs. The payout source address is public; wallet keys stay on PB/SUN only.

## Status For PB

The Oven Registry can check node health through:

- worker `/status` endpoints,
- RoRe `agent:health` stream,
- `bin/alice_node_status` JSON posted or mirrored by the node,
- last heartbeat on active jobs.

The worker node should never be trusted solely because it is online. Payout eligibility comes from accepted job results.
