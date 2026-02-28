## Why

The web UI at `https://your-domain.com` is currently inaccessible (nginx returns 403 for all non-webhook routes). As a single user, I need password-protected access to browse, search, and manage my notes from any device (browser on desktop/mobile).

## What Changes

- nginx on DO: open `location /` to proxy all non-webhook routes to Rails app on RPi
- Rails `ApplicationController`: add `http_basic_authenticate_with` (password-only, single user)
- Rails `Api::TelegramController`: skip Basic Auth (already uses Telegram secret token)
- `.env.production` + `docker-compose.production.yml`: add `WEB_PASSWORD` environment variable
- No login page — browser native Basic Auth dialog handles credential entry

## Capabilities

### New Capabilities

- `web-ui-auth`: Password-only HTTP Basic Auth protecting all web UI routes. Single user — no username required. Telegram API routes are excluded from auth. Credentials are browser-native (no login form).

### Modified Capabilities

- none

## Impact

- **Code**: `ApplicationController`, `Api::TelegramController` (skip_before_action), `config/routes.rb` (if namespace separation needed)
- **nginx**: `/home/dokku/inbox/nginx.conf` on DO server — add `location /` block with proxy to `10.8.0.5:3000`
- **Docker**: `docker-compose.production.yml` — add `WEB_PASSWORD` env var
- **Deploy**: `.env.production` on RPi — add `WEB_PASSWORD`
- **Security**: HTTP Basic Auth over HTTPS is secure; password stored as ENV var (not hardcoded)
- **No new dependencies**
