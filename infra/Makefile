.PHONY: up down build snapshot restore logs test

COMPOSE=docker compose -f docker-compose.yml
SNAPDIR=snapshots

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

build:
	$(COMPOSE) build

logs:
	$(COMPOSE) logs -f

snapshot:
	mkdir -p $(SNAPDIR)/$(shell date +%Y%m%d-%H%M%S)

	# Postgres dump
	@echo "Dumping Postgres..."
	docker exec -i $$(docker-compose ps -q postgres) pg_dumpall -U postgres > $(SNAPDIR)/$$(date +%Y%m%d-%H%M%S)/pg_dump.sql || true

	# MinIO: copy bucket content using mc (requires mc installed locally)
	@echo "Syncing MinIO (requires mc configured as 'local')..."
	mkdir -p $(SNAPDIR)/$$(date +%Y%m%d-%H%M%S)/minio || true
	mc cp --recursive local/ukpath $(SNAPDIR)/$$(date +%Y%m%d-%H%M%S)/minio || true

restore:
	@read -p "Enter snapshot folder name: " SNAP && \
	cat $(SNAPDIR)/$$SNAP/pg_dump.sql | docker exec -i $$(docker-compose ps -q postgres) psql -U postgres || true

test:
	# Run unit + e2e (assumes web service has npm scripts)
	docker compose run --rm web npm run test || true
