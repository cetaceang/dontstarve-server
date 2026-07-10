SHELL := /bin/bash
COMPOSE := docker compose

.PHONY: init build up down stop restart logs status update backup restore config

init:
	@test -f .env || cp .env.example .env
	@test -f secrets/cluster_token.txt || cp secrets/cluster_token.txt.example secrets/cluster_token.txt
	@mkdir -p backups
	@echo "Initialization complete. Edit .env and secrets/cluster_token.txt before starting."

build:
	$(COMPOSE) build

up:
	@test -f .env || (echo "Missing .env; run 'make init' first" >&2; exit 1)
	@test -f secrets/cluster_token.txt || (echo "Missing cluster token; run 'make init' first" >&2; exit 1)
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop master caves

restart: update

logs:
	$(COMPOSE) logs -f --tail=200 master caves

status:
	$(COMPOSE) ps

update:
	$(COMPOSE) stop master caves
	$(COMPOSE) run --rm prepare
	$(COMPOSE) up -d --no-deps master
	@echo "Waiting for the Master shard to become healthy..."
	@for i in $$(seq 1 60); do \
		container="$$(docker compose ps -q master)"; \
		status="$$(test -n "$$container" && docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}starting{{end}}' "$$container" 2>/dev/null || true)"; \
		[ "$$status" = healthy ] && exit 0; \
		[ "$$status" = unhealthy ] && echo "Master is unhealthy" >&2 && exit 1; \
		sleep 2; \
	done; echo "Timed out waiting for Master" >&2; exit 1
	$(COMPOSE) up -d --no-deps caves

backup:
	./scripts/backup.sh

restore:
	@test -n "$(BACKUP)" || (echo "Usage: make restore BACKUP=backups/<file>.tar.gz" >&2; exit 1)
	./scripts/restore.sh "$(BACKUP)"

config:
	$(COMPOSE) config
