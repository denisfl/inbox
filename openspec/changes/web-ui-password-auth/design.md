## Context

Currently, `https://inbox.fedosov.me` returns 403 for all routes except the Telegram webhook. The nginx configuration was intentionally restrictive during initial deployment. The Rails application has a working web UI (DocumentsController, views) but no authentication layer.

The system has a single user. Authentication is needed only to prevent unauthorized access in case the URL is discovered. The threat model is casual exposure, not targeted attacks.

## Goals / Non-Goals

**Goals:**

- Enable web UI access at `https://inbox.fedosov.me` with password protection
- Single factor: password only (no username, no OTP)
- Works across all standard browsers on any device
- Telegram webhook remains accessible without auth
- Minimal code changes, no new dependencies

**Non-Goals:**

- Multi-user support
- Session management / logout
- OAuth or social login
- Rate limiting on auth attempts (Basic Auth handled by browser)
- Remember-me / persistent sessions (browsers handle this)

## Decisions

### Decision: HTTP Basic Auth at Rails level (not nginx)

**Chosen:** `http_basic_authenticate_with` in `ApplicationController`

**Rationale:**

- Rails built-in — zero new dependencies
- Password stored as ENV var (`WEB_PASSWORD`), loaded via Docker secret or `.env.production`
- Easier to exclude specific routes (API controllers use `skip_before_action`)
- No htpasswd file management on DO server
- Password change = ENV var update + container restart

**Alternatives considered:**

- nginx `auth_basic` with htpasswd — requires managing a file on DO server, harder to rotate
- Devise/other gems — overkill for single-user, no login form needed

### Decision: Fixed dummy username "admin"

**Rationale:** `http_basic_authenticate_with` requires a name parameter. Using `name: "admin"` with only `password:` checked is invisible to the user (browser shows password field only after prompting, but most UIs show both). Documenting that username is irrelevant is enough.

Actually `http_basic_authenticate_with name: nil` is not valid in Rails. We use `name: "_"` (any value works — browser fills it, user ignores it).

### Decision: `WEB_PASSWORD` in environment

Password set via ENV var. In production: added to `docker-compose.production.yml` environment section and `.env.production` on RPi. Loaded by entrypoint into container.

### Decision: nginx opens `location /` to proxy to Rails

nginx on DO needs `location /` changed from `return 403` to `proxy_pass http://10.8.0.5:3000` so the web UI is reachable.

## Risks / Trade-offs

- **Risk:** Basic Auth credentials sent in plaintext in HTTP header → **Mitigation:** HTTPS is enforced (Dokku letsencrypt), so all traffic is encrypted.
- **Risk:** Password visible in `.env.production` file on RPi → **Mitigation:** File is gitignored; RPi is on private WireGuard network.
- **Risk:** Browser caches credentials — logout is not possible without clearing browser cache → **Trade-off:** Acceptable for single-user personal tool.
- **Risk:** `WEB_PASSWORD` visible in `docker compose ps` environment dump → **Mitigation:** Future improvement: use Docker secret. Current risk is low (RPi is local network).

## Migration Plan

1. Update nginx on DO (`/home/dokku/inbox/nginx.conf`) — add `location /` proxy block
2. Add `http_basic_authenticate_with` in `ApplicationController`
3. Add `skip_before_action :http_basic_authenticate` in `Api::TelegramController` (or move to `ApplicationController` with exception)
4. Add `WEB_PASSWORD` to `docker-compose.production.yml` environment
5. Add `WEB_PASSWORD=<value>` to `~/inbox/.env.production` on RPi
6. Rebuild and restart `web` and `worker` containers
7. Reload nginx on DO

**Rollback:** Revert nginx `location /` to `return 403`, remove auth from ApplicationController.
