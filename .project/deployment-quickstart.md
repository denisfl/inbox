# Production Deployment Quickstart

**Goal:** Deploy Inbox to Raspberry Pi 5 with secure access via existing WireGuard VPN + nginx reverse proxy on Digital Ocean.

**Result:**

- Private web UI: `https://your-domain.com` (requires password)
- Telegram webhook: `https://your-domain.com/api/telegram/webhook` (public, rate-limited)

---

## Prerequisites

- ✅ Raspberry Pi 5 (8GB RAM, Raspberry Pi OS)
- ✅ Digital Ocean VPS with WireGuard already running
- ✅ nginx installed on DO server
- ✅ Domain: example.com (can add subdomain)

---

## Step 1: Connect RPi to WireGuard (15 min)

### On Raspberry Pi:

```bash
# Install WireGuard
sudo apt update && sudo apt install wireguard

# Generate a key pair for the RPi
wg genkey | sudo tee /etc/wireguard/rpi_private.key | wg pubkey | sudo tee /etc/wireguard/rpi_public.key
sudo chmod 600 /etc/wireguard/rpi_private.key

# Show the RPi public key — you'll need it when adding the peer on the DO server
sudo cat /etc/wireguard/rpi_public.key

# Create WireGuard config (replace RPI_PRIVATE_KEY with the generated key above)
sudo nano /etc/wireguard/wg0.conf

# Paste this config:
[Interface]
PrivateKey = <RPI_PRIVATE_KEY>   # output of: sudo cat /etc/wireguard/rpi_private.key
Address = 10.8.0.5/24

[Peer]
PublicKey = ug2/hhHssk55S4H2BkMaWjHLtPKmXUaCbQhvoXPpdg8=
Endpoint = 178.128.198.105:51820
AllowedIPs = 10.8.0.0/24
PersistentKeepalive = 25

# Start WireGuard
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0

# Verify connection
ping 10.8.0.1  # Should reach DO server
```

### On Digital Ocean VPS:

```bash
# Add RPi peer to the WireGuard server config
sudo nano /etc/wireguard/wg0.conf

# Add this [Peer] block (use the RPi public key from the step above):
[Peer]
# Description = Raspberry Pi 5
PublicKey = <RPI_PUBLIC_KEY>   # sudo cat /etc/wireguard/rpi_public.key
AllowedIPs = 10.8.0.5/32

# Reload WireGuard without dropping existing connections (preferred)
sudo wg syncconf wg0 <(sudo wg-quick strip wg0)

# Or full restart if syncconf is unavailable:
# sudo wg-quick down wg0 && sudo wg-quick up wg0

# Test from DO server
ping 10.8.0.5  # Should reach RPi after Docker starts
```

---

## Step 2: Deploy Inbox on RPi (20 min)

```bash
# On Raspberry Pi
cd ~
git clone https://github.com/yourusername/inbox.git
cd inbox

# Create production env file
cp .env.example .env.production
nano .env.production

# Set:
RAILS_ENV=production
SECRET_KEY_BASE=$(openssl rand -hex 64)
TELEGRAM_BOT_TOKEN=<YOUR_BOT_TOKEN>
TELEGRAM_WEBHOOK_URL=https://your-domain.com/api/telegram/webhook
WHISPER_BASE_URL=http://whisper:5000

# Build images
docker compose build --pull

# Initialize database
docker compose run --rm web bin/rails db:create db:migrate

# Start services
docker compose up -d

# Verify all healthy
docker compose ps
# Expected: web, worker, whisper, redis, ollama all "healthy"

# Test local access
curl http://localhost:3000/up
# Expected: "ok"
```

---

## Step 3: Configure nginx on DO (15 min)

### 1. Create Basic Auth password:

```bash
# On DO server
sudo apt install apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd denis
# Enter password (suggestion: use strong password, save in password manager)
```

### 2. Create nginx site config:

```bash
sudo nano /etc/nginx/sites-available/inbox
```

Paste this config:

```nginx
# Rate limiting (add to /etc/nginx/nginx.conf in http {} block FIRST)
# limit_req_zone $binary_remote_addr zone=telegram:10m rate=30r/m;

server {
    listen 80;
    server_name your-domain.com;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL certificates (will be created by certbot)
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";
    add_header X-Content-Type-Options "nosniff";
    add_header X-Frame-Options "DENY";
    add_header Referrer-Policy "no-referrer-when-downgrade";

    # Telegram webhook - NO AUTH (bot needs access)
    location /api/telegram/ {
        proxy_pass http://10.8.0.5:3000;  # RPi WireGuard IP
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Rate limiting
        limit_req zone=telegram burst=10 nodelay;
    }

    # All other routes - REQUIRE AUTH (private)
    location / {
        auth_basic "Private Access";
        auth_basic_user_file /etc/nginx/.htpasswd;

        proxy_pass http://10.8.0.5:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### 3. Add rate limiting to nginx.conf:

```bash
sudo nano /etc/nginx/nginx.conf

# Find the http {} block and add:
http {
    # ... existing config ...

    # Rate limiting for Telegram webhook
    limit_req_zone $binary_remote_addr zone=telegram:10m rate=30r/m;

    # ... rest of config ...
}
```

### 4. Enable site and get SSL:

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/inbox /etc/nginx/sites-enabled/

# Add DNS record FIRST (your-domain.com -> DO_SERVER_IP)
# Then get SSL certificate:
sudo certbot --nginx -d your-domain.com

# Test nginx config
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

---

## Step 4: Register Telegram Webhook (2 min)

```bash
# From the repo root on the Raspberry Pi (~/inbox after cloning):
# Create a `secrets/` directory (this is referenced by `docker-compose.yml`)
mkdir -p ./secrets

# Put your Telegram bot token (from BotFather) into a file
printf "%s" "<YOUR_BOT_TOKEN>" > ./secrets/telegram_bot_token
chmod 600 ./secrets/telegram_bot_token

# Generate a strong webhook secret token (example: 32 bytes hex)
SECRET_TOKEN=$(openssl rand -hex 32)
printf "%s" "$SECRET_TOKEN" > ./secrets/telegram_webhook_secret_token
chmod 600 ./secrets/telegram_webhook_secret_token

# Start containers (they will load secrets into ENV via entrypoint)
docker compose build --pull
docker compose up -d

# Register webhook with Telegram including the `secret_token` so Telegram
# sends `X-Telegram-Bot-Api-Secret-Token` header with each request.
BOT_TOKEN=$(cat ./secrets/telegram_bot_token)
SECRET_TOKEN=$(cat ./secrets/telegram_webhook_secret_token)

curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
    -H "Content-Type: application/json" \
    -d "{\"url\": \"https://your-domain.com/api/telegram/webhook\", \"secret_token\": \"${SECRET_TOKEN}\"}"

# Expected response:
# {"ok":true,"result":true,"description":"Webhook was set"}

# Verify:
curl "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo"
```

---

## Step 5: Test Everything (5 min)

### Test 1: Web UI (requires password)

```bash
# Open in browser:
https://your-domain.com/

# Should prompt for username/password (denis / YOUR_PASSWORD)
# After login: should see empty documents list or existing documents
```

### Test 2: Telegram Bot

```bash
# Open Telegram: @your_bot_name
# Send test message: "Hello from production!"
# Expected:
# - Bot replies: "✅ Saved"
# - Web UI shows new document
```

### Test 3: Voice Transcription

```bash
# In Telegram:
# - Record voice message
# - Send to @your_bot_name
# Expected:
# - Bot replies: "🎤 Transcribing your voice note..."
# - After 5-20s: "✅ Transcription complete: <text>"
# - Web UI shows document with transcription

# Monitor on RPi:
docker compose logs worker --tail=50 --follow
```

---

## Monitoring Commands

```bash
# On Raspberry Pi

# Check all services
docker compose ps

# View logs
docker compose logs web --tail=50 --follow
docker compose logs worker --tail=50 --follow
docker compose logs whisper --tail=20

# Check Sidekiq jobs
docker compose exec web bin/rails console
> Sidekiq::Queue.new.size  # Pending jobs
> Sidekiq::DeadSet.new.size  # Failed jobs

# System resources
htop  # CPU, RAM
df -h  # Disk space
```

---

## Backup Strategy

### Daily Database Backup (cron):

```bash
# On Raspberry Pi
crontab -e

# Add:
0 2 * * * docker compose exec -T web sqlite3 /app/storage/production.sqlite3 ".backup '/app/storage/backups/backup-$(date +\%Y\%m\%d).db'"

# Create backup directory
mkdir -p ~/inbox/storage/backups
```

### Weekly Full Backup:

```bash
# If using external SSD
0 3 * * 0 tar -czf /mnt/ssd/backups/inbox-$(date +\%Y\%m\%d).tar.gz ~/inbox/storage
```

---

## Troubleshooting

### Issue: RPi can't reach DO server via WireGuard

```bash
# On RPi
sudo wg show  # Check WireGuard status
ping 10.8.0.1  # Test connectivity to DO server

# On DO
sudo wg show  # Should see RPi peer (10.8.0.5)
```

### Issue: nginx 502 Bad Gateway

```bash
# Check if RPi is reachable from DO
ssh do-server
ping 10.8.0.5  # Should work

# Check if Inbox web container is running
ssh rpi
docker compose ps  # web should be "healthy"
curl http://localhost:3000/up  # Should return "ok"
```

### Issue: Telegram webhook not working

```bash
# Check webhook status
curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"

# Check nginx logs on DO
sudo tail -f /var/log/nginx/access.log | grep telegram

# Check Rails logs on RPi
docker compose logs web --tail=100 | grep telegram
```

### Issue: Transcription not working

```bash
# Check Whisper service
docker compose exec whisper curl http://localhost:5000/health

# Check worker logs
docker compose logs worker --tail=50

# Check Sidekiq dead queue
docker compose exec web bin/rails console
> Sidekiq::DeadSet.new.size
> Sidekiq::DeadSet.new.first.error_message
```

---

## Security Checklist

- ✅ Web UI protected by HTTP Basic Auth
- ✅ Telegram webhook rate-limited (30 req/min)
- ✅ Telegram webhook validated via `X-Telegram-Bot-Api-Secret-Token` header
- ✅ All traffic encrypted (HTTPS + WireGuard)
- ✅ Only authorized Telegram user ID (check in controller)
- ✅ SSL certificate auto-renewed by certbot
- ✅ UFW firewall on DO (ports 22, 80, 443, 51820)
- ✅ SSH keys only (no password login)
- ✅ fail2ban for SSH brute-force protection
- ✅ Secrets stored in `./secrets/` (excluded from git via .gitignore)
- ⚠️ Rotate WireGuard private keys if they have been shared outside the device

---

## Estimated Timeline

| Step                | Time        | Notes                    |
| ------------------- | ----------- | ------------------------ |
| WireGuard setup     | 15 min      | If config already exists |
| Deploy Inbox on RPi | 20 min      | First build takes longer |
| nginx configuration | 15 min      | Includes SSL setup       |
| Telegram webhook    | 2 min       | Just one curl command    |
| Testing             | 5 min       | End-to-end verification  |
| **Total**           | **~1 hour** | Assuming no issues       |

---

## Next Steps After Deployment

1. **Story 13:** Implement UI improvements (dark mode, filters, PWA)
2. **Monitoring:** Setup health check alerts
3. **Backup verification:** Test restore from backup
4. **Performance tuning:** Monitor RAM usage, adjust if needed
5. **Documentation:** Update README with production URLs

---

## Questions?

If you encounter issues or have questions during deployment:

1. Check [Story 12](.project/stories/story-12-production-deployment.md) for detailed explanations
2. Review error logs (nginx, Rails, Sidekiq, Whisper)
3. Ask for help with specific error messages

---

**Last updated:** 2026-02-25  
**Tested on:** Raspberry Pi 5 (8GB), Raspberry Pi OS 64-bit, Docker 26.0.0
