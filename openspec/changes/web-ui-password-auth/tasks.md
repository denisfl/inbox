## 1. Rails: HTTP Basic Auth

- [ ] 1.1 Add `http_basic_authenticate_with name: "_", password: -> { ENV.fetch("WEB_PASSWORD") }` to `ApplicationController`
- [ ] 1.2 Add `skip_before_action :http_basic_authenticate` (or equivalent) to `Api::TelegramController` to exclude webhook from Basic Auth
- [ ] 1.3 Add fail-fast guard in `ApplicationController` (or initializer) that raises if `WEB_PASSWORD` is blank in production

## 2. Environment Configuration

- [ ] 2.1 Add `WEB_PASSWORD` to `docker-compose.production.yml` environment section for `web` and `worker` services
- [ ] 2.2 Add `WEB_PASSWORD=<chosen-password>` to `~/inbox/.env.production` on RPi

## 3. nginx on DO

- [ ] 3.1 Update `/home/dokku/inbox/nginx.conf` on DO: change `location /` from `return 403` to `proxy_pass http://10.8.0.5:3000` with proxy headers
- [ ] 3.2 Verify `sudo nginx -t` passes and reload nginx: `sudo nginx -s reload`

## 4. Deploy

- [ ] 4.1 Commit and push Rails changes locally (`ApplicationController`, `Api::TelegramController`)
- [ ] 4.2 On RPi: `git pull origin main`
- [ ] 4.3 Rebuild web container: `docker compose -f docker-compose.yml -f docker-compose.production.yml --env-file .env.production build web`
- [ ] 4.4 Restart web container: `docker compose ... up -d --force-recreate web`

## 5. Verification

- [ ] 5.1 Open `https://inbox.fedosov.me/` in browser → should see Basic Auth password prompt
- [ ] 5.2 Enter wrong password → should be re-prompted (401)
- [ ] 5.3 Enter correct `WEB_PASSWORD` → should see documents index
- [ ] 5.4 Confirm Telegram bot still works (send a test message)
- [ ] 5.5 Confirm `curl -s https://inbox.fedosov.me/api/telegram/webhook` does NOT return 401 (returns 403 from Telegram secret validation or 405)
