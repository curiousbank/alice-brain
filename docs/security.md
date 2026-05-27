# Security Notes

Alice is a worker, not a public authority.

- Pinball decides what work Alice may perform.
- Alice should not hold production MAZA keys.
- Alice should not write directly to production databases.
- Alice should not expose a public HTTP port unless it is protected by a tunnel, firewall, and shared secret.
- Logs must avoid prompt secrets, private credentials, wallet secrets, and user recovery data.

