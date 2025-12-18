# Architecture

## Overview
The platform is composed of independent **stacks**, deployed in a controlled order:

1) **00-edge**: Nginx reverse proxy (the only service binding host ports 80/443)
2) **10-auth**: Authentik identity services (SSO)
3) **20-apps**: Applications (added one-by-one)

## Source of truth model
- Repo: desired state (compose + reference configs + docs)
- Host: runtime state (secrets, certs, persistent data)

## Goals
- Reproducibility: a new operator can deploy from scratch by following docs + scripts.
- Safety: no secrets in git; deterministic deploy/rollback/backup.
- Clarity: minimal assumptions; explicit networks; single edge.
