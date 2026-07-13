# Security Policy

## Reporting

Report suspected vulnerabilities privately through this repository's GitHub
Security tab. Do not open a public issue containing credentials, private keys,
production host details, or exploit instructions for an active deployment.

## Supported Code

Security fixes target the current `main` branch.

## Deployment Boundary

Alice Brain is an untrusted outbound worker. Keep Ollama private, use a scoped
worker token, and never install production database, storage, SSH, or wallet
credentials on a worker node.
