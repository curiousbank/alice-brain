# Product Positioning

Alice Brain plus SUN/PB can be described as an AI token bridge for distributed AI services.

The strongest framing:

```text
Local nodes bake AI work.
SUN/PB validates and stores the output.
Pinball accounts accepted bakes and pays MAZA.
```

## Components

- **Alice Brain**: local worker-node kit.
- **SUN/PB**: controller, validator, storage gate, token accountant.
- **Oven Registry**: Pinball web interface for enrolling worker ovens, issuing scoped tokens, showing health, and tracking bakes.
- **RoRe / Rotary Relay**: private health and coordination relay.
- **Backblaze**: controlled artifact storage selected by SUN/PB.
- **MAZA Bakes**: accepted work units eligible for hourly payout.

## What RoRe Is

RoRe is the control-plane relay. It is useful for ACKs, status, diagnostics, and operator coordination.

It should not be marketed as the storage layer, payment ledger, or job security model. The secure worker endpoints and SUN/PB validation are the job security model.

## Plain-Language Pitch

Pinball can coordinate private AI work across local machines. A worker node receives only the job it needs, processes it with local models, returns the artifact to SUN, and SUN publishes the result where the frontend expects it. If the result is accepted, PB records a Bake and can pay the node in MAZA on an hourly batch.

This is Filecoin-like in spirit for AI processing, but the current product is not Filecoin and does not claim decentralized storage consensus. It is a private, token-incentivized compute bridge.

## Oven Registry Pitch

The Oven Registry is where operators plug a local machine into Pinball's AI bake network. It does not ask for private keys. It gives the node a scoped identity, a worker token, model setup instructions, tunnel commands, and a place to register the public MAZA address that should receive accepted bake payouts.
