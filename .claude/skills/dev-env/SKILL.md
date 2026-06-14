---
name: dev-env
description: Boot, test, or run Rails commands for inbox-web through Docker. Use whenever you need to run rspec, rubocop, rails console/runner, db tasks, or the web server for this project — the native Ruby toolchain on this machine is broken, so everything must go through the dev container.
---

# inbox-web dev environment (Docker)

The native `bundle` install on this machine does not match `Gemfile.lock`, so `bin/rails`
and `bundle exec` fail directly on the host. Run everything through the dev container
defined by `Dockerfile.dev` + `compose.dev.yaml`. That file is intentionally NOT a default
Compose name (production's `docker-compose.yml` keeps that slot), so always pass `-f compose.dev.yaml`.

## First time / after Gemfile changes

```bash
docker compose -f compose.dev.yaml build web   # or: docker build -f Dockerfile.dev -t inbox-web-dev .
```

## Common commands

```bash
docker compose -f compose.dev.yaml up                                   # web server → http://localhost:3000
docker compose -f compose.dev.yaml run --rm web bundle exec rspec       # full suite
docker compose -f compose.dev.yaml run --rm web bundle exec rspec spec/lib/unified_storage_service_spec.rb
docker compose -f compose.dev.yaml run --rm web bin/rubocop
docker compose -f compose.dev.yaml run --rm web bin/rails console
docker compose -f compose.dev.yaml run --rm web bin/rails db:prepare
```

## One-off scripts / reproductions

To exercise app code (e.g. reproduce a storage bug) without compose, mount the script and run:

```bash
docker run --rm -v "$PWD":/rails -v /tmp/script.rb:/tmp/script.rb \
  -e RAILS_ENV=development \
  -e ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=devkeydevkeydevkeydevkeydevkey01 \
  -e ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=devkeydevkeydevkeydevkeydevkey02 \
  -e ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=devkeydevkeydevkeydevkeydevkey03 \
  inbox-web-dev bash -lc "bin/rails db:prepare >/dev/null 2>&1; bin/rails runner /tmp/script.rb"
```

## Notes

- The dev SQLite db lives at `storage/development.sqlite3` (a Docker volume, not the host
  tree) — an empty host `storage/` is normal, not a sign of lost data.
- `StorageSetting` uses an encrypted column, so `ACTIVE_RECORD_ENCRYPTION_*` keys must be
  set in the environment (compose.dev.yaml provides dev defaults).
- Test env uses the `:test` Disk ActiveStorage service; dev/prod use `:unified`. See
  `CLAUDE.md` → "File storage" before changing storage code.
