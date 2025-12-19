SHELL := /usr/bin/env bash

.PHONY: help bootstrap deploy-edge deploy-infra deploy-auth deploy-apps deploy-all validate snapshot rollback up down logs status

help:
	@echo "homelab-platform command & control"
	@echo
	@echo "Bootstrap & Setup:"
	@echo "  make bootstrap          - Create host directories and network"
	@echo
	@echo "Deployment:"
	@echo "  make deploy-edge        - Deploy nginx reverse proxy"
	@echo "  make deploy-infra       - Deploy shared infrastructure (postgres, redis)"
	@echo "  make deploy-auth        - Deploy authentication services (authentik)"
	@echo "  make deploy-apps        - Deploy all application stacks"
	@echo "  make deploy-all         - Deploy everything (infra + edge + auth + apps)"
	@echo
	@echo "Operations:"
	@echo "  make validate           - Validate deployment"
	@echo "  make status             - Show status of all services"
	@echo "  make snapshot           - Create backup snapshot"
	@echo "  make rollback REF=<ref> - Rollback to git reference"
	@echo
	@echo "Stack Management:"
	@echo "  make up STACK=<path>    - Start a specific stack"
	@echo "  make down STACK=<path>  - Stop a specific stack"
	@echo "  make logs STACK=<path>  - View logs for a specific stack"

bootstrap:
	./scripts/bootstrap_host.sh

deploy-edge:
	./scripts/deploy_edge_nginx.sh

deploy-infra:
	@echo "==> Deploying shared infrastructure..."
	@docker compose -f stacks/05-infra/postgres/docker-compose.yml up -d
	@docker compose -f stacks/05-infra/redis/docker-compose.yml up -d
	@echo "✅ Infrastructure deployed (postgres, redis)"

deploy-auth:
	@echo "==> Deploying authentication services..."
	@docker compose -f stacks/10-auth/authentik/docker-compose.yml up -d
	@echo "✅ Authentication services deployed (authentik)"

deploy-apps:
	@echo "==> Deploying application stacks..."
	@docker compose -f stacks/15-network/pihole/docker-compose.yml up -d
	@docker compose -f stacks/20-apps/bookstack/docker-compose.yml up -d
	@docker compose -f stacks/30-admin/cockpit/docker-compose.yml up -d
	@echo "✅ Applications deployed (pihole, bookstack, cockpit)"

deploy-all: deploy-infra deploy-edge deploy-auth deploy-apps
	@echo "✅ Full platform deployment complete"

validate:
	./scripts/validate.sh

status:
	@echo "==> Platform service status:"
	@docker ps --filter "name=geek-" --filter "name=authentik-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

snapshot:
	./scripts/snapshot.sh

rollback:
	@if [ -z "$(REF)" ]; then echo "Usage: make rollback REF=<git-ref>"; exit 1; fi
	./scripts/rollback.sh "$(REF)"

up:
	@if [ -z "$(STACK)" ]; then echo "Usage: make up STACK=<stack-path>"; exit 1; fi
	docker compose -f "$(STACK)/docker-compose.yml" up -d

down:
	@if [ -z "$(STACK)" ]; then echo "Usage: make down STACK=<stack-path>"; exit 1; fi
	docker compose -f "$(STACK)/docker-compose.yml" down

logs:
	@if [ -z "$(STACK)" ]; then echo "Usage: make logs STACK=<stack-path>"; exit 1; fi
	docker compose -f "$(STACK)/docker-compose.yml" logs -f --tail=200



