SHELL := /usr/bin/env bash

.PHONY: help bootstrap deploy-edge validate snapshot rollback up down logs

help:
	@echo "homelab-platform command & control"
	@echo
	@echo "  make bootstrap"
	@echo "  make deploy-edge"
	@echo "  make validate"
	@echo "  make snapshot"
	@echo "  make rollback REF=<git-ref>"
	@echo "  make up STACK=stacks/10-auth/authentik"
	@echo "  make down STACK=stacks/10-auth/authentik"
	@echo "  make logs STACK=stacks/10-auth/authentik"

bootstrap:
	./scripts/bootstrap_host.sh

deploy-edge:
	./scripts/deploy_edge_nginx.sh

validate:
	./scripts/validate.sh

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
