# Unified dev commands (Spec §1.1 / 01-开发建议 §0)

.PHONY: setup server-setup app-setup test server-test app-test lint server-lint app-lint ci server-coverage app-coverage db-up db-down

setup: server-setup app-setup

server-setup:
	cd server && npm ci

app-setup:
	cd app && flutter pub get

test: server-test app-test

server-test:
	cd server && npm test

server-coverage:
	cd server && npm run test:coverage

app-test:
	cd app && flutter test

lint: server-lint app-lint

server-lint:
	cd server && npx tsc --noEmit

app-lint:
	cd app && flutter analyze

ci: lint server-test app-test

db-up:
	docker run -d --name bookkeep-pg \
		-e POSTGRES_PASSWORD=bookkeep_dev \
		-e POSTGRES_USER=bookkeep \
		-e POSTGRES_DB=bookkeep \
		-p 5432:5432 postgres:16

db-down:
	docker rm -f bookkeep-pg
