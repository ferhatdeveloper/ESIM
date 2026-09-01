.PHONY: up down logs reset test

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f postgrest

reset:
	docker compose down -v
	docker compose up -d

test:
	docker compose exec -T db psql -U postgres -d esim -v ON_ERROR_STOP=1 < tests/test_business_rules.sql
