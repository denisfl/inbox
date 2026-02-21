# Story 12: Production Deployment on Raspberry Pi

**Priority:** P0 (Critical)  
**Complexity:** Very High  
**Estimated Effort:** 3-4 days  
**Dependencies:** Story 11 (Whisper Transcription)  
**Status:** Not Started

---

## User Story

As an administrator, I want to deploy the application to Raspberry Pi 5 with reliable external access so that users can interact with the Telegram bot from anywhere.

---

## Context & Constraints

### Hardware
- **Device**: Raspberry Pi 5 (ARM64, 8GB RAM)
- **Storage**: SD card or SSD via USB 3.0
- **Network**: Home internet with dynamic IP (no static IP)
- **Power**: 24/7 uptime required

### Current Issues
- **ngrok limitations**: 
  - Free tier has 2-hour session timeout
  - Requires constant restarts
  - No custom domain
  - Limited connections per minute

---

## Acceptance Criteria

### ✅ Network Access Solutions (Choose One)

#### **Option A: Tailscale VPN + Funnel (RECOMMENDED)**

**Pros:**
- ✅ Secure peer-to-peer VPN (WireGuard-based)
- ✅ HTTPS public endpoints via Tailscale Funnel
- ✅ No port forwarding needed
- ✅ Free for personal use (3 users, 100 devices)
- ✅ Custom domain via MagicDNS (e.g., `inbox.tail-scale.ts.net`)
- ✅ Stable connections (no timeout)
- ✅ Works behind CGNAT/strict firewalls

**Cons:**
- ❌ Requires Tailscale account
- ❌ Funnel endpoints are public (rate limiting needed)

**Implementation:**
```bash
# Install Tailscale on RPi
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Enable Funnel for public HTTPS access
tailscale funnel --bg --https=443 http://localhost:3000

# Get public URL
tailscale funnel status
# Example: https://inbox-pi.tail-xxxxx.ts.net
```

**docker-compose.yml:**
```yaml
services:
  web:
    # ...
    environment:
      - TELEGRAM_WEBHOOK_URL=https://inbox-pi.tail-xxxxx.ts.net/api/telegram/webhook
      - RAILS_FORCE_SSL=false  # Tailscale handles HTTPS
```

---

#### **Option B: Cloudflare Tunnel (Zero Trust)**

**Pros:**
- ✅ Free tier available
- ✅ HTTPS automatic (Cloudflare SSL)
- ✅ DDoS protection
- ✅ Custom domain support (`inbox.yourdomin.com`)
- ✅ No port forwarding
- ✅ Rate limiting via Cloudflare WAF

**Cons:**
- ❌ Requires Cloudflare account + domain
- ❌ More complex setup
- ❌ Cloudflare can inspect traffic (privacy concern)

**Implementation:**
```bash
# Install cloudflared
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/

# Login and create tunnel
cloudflared tunnel login
cloudflared tunnel create inbox-pi
cloudflared tunnel route dns inbox-pi inbox.yourdomain.com

# Run tunnel
cloudflared tunnel --url http://localhost:3000 run inbox-pi
```

---

#### **Option C: Self-Hosted Reverse Proxy (Advanced)**

**Requirements:**
- VPS with static IP (e.g., DigitalOcean $6/mo, Oracle Cloud free tier)
- WireGuard tunnel: RPi ↔ VPS
- Nginx/Caddy on VPS as reverse proxy

**Pros:**
- ✅ Full control
- ✅ Custom domain
- ✅ No third-party dependencies

**Cons:**
- ❌ Requires VPS ($6-15/mo or Oracle Cloud free tier)
- ❌ Complex setup (WireGuard + Nginx config)
- ❌ Need to manage VPS security/updates

---

#### **Option D: Dynamic DNS + Port Forwarding (NOT RECOMMENDED)**

**Why Avoid:**
- ❌ Requires router access (port 80/443 forwarding)
- ❌ Security risk (exposed to internet)
- ❌ ISP may block ports 80/443
- ❌ Dynamic IP changes (need DynDNS service)
- ❌ No HTTPS without Let's Encrypt setup
- ❌ CGNAT blocks many ISPs

---

### ✅ Docker Production Configuration

**docker-compose.production.yml:**
```yaml
services:
  web:
    restart: unless-stopped
    environment:
      - RAILS_ENV=production
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - TELEGRAM_WEBHOOK_URL=${TELEGRAM_WEBHOOK_URL}
      - RAILS_LOG_TO_STDOUT=true
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/up"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 60s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  whisper:
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 2G  # Prevent OOM on Pi
    environment:
      - WHISPER_MODEL_SIZE=base  # Or "tiny" for lower memory
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  worker:
    restart: unless-stopped
    environment:
      - RAILS_ENV=production
    deploy:
      resources:
        limits:
          memory: 1G

  redis:
    restart: unless-stopped
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru

  ollama:
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 4G  # Ollama can use significant RAM
```

---

### ✅ Environment Configuration

**Production .env:**
```bash
# Rails
RAILS_ENV=production
SECRET_KEY_BASE=$(openssl rand -hex 64)

# Database (SQLite on SSD recommended)
DATABASE_URL=sqlite3:/app/storage/production.sqlite3

# Telegram
TELEGRAM_BOT_TOKEN=8048540749:AAHAYUj-bLzNcS9aUe7o-Kq111q1LoVMdmw
TELEGRAM_ALLOWED_USER_ID=80646805
TELEGRAM_WEBHOOK_URL=https://inbox-pi.tail-xxxxx.ts.net/api/telegram/webhook

# Whisper
WHISPER_BASE_URL=http://whisper:5000
WHISPER_MODEL_SIZE=base  # or "tiny" for lower memory

# Redis
REDIS_URL=redis://redis:6379/0

# Ollama
OLLAMA_BASE_URL=http://ollama:11434
```

---

### ✅ System Configuration

**Raspberry Pi Setup:**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose-plugin

# Enable Docker on boot
sudo systemctl enable docker

# Increase swap (for Whisper/Ollama)
sudo dphys-swapfile swapoff
sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
sudo dphys-swapfile setup
sudo dphys-swapfile swapon

# Mount external SSD (optional but recommended)
sudo mkdir -p /mnt/ssd
sudo mount /dev/sda1 /mnt/ssd
# Add to /etc/fstab for auto-mount
```

**systemd service** (auto-restart on reboot):
```ini
# /etc/systemd/system/inbox.service
[Unit]
Description=Inbox Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/pi/inbox
ExecStart=/usr/bin/docker compose -f docker-compose.production.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.production.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

Enable service:
```bash
sudo systemctl enable inbox.service
sudo systemctl start inbox.service
```

---

### ✅ Deployment Steps

**1. Prepare Production Environment:**
```bash
# Clone repo on RPi
git clone https://github.com/yourusername/inbox.git
cd inbox

# Copy production config
cp .env.example .env.production
nano .env.production  # Fill in production values

# Generate SECRET_KEY_BASE
openssl rand -hex 64 >> .env.production
```

**2. Build Images:**
```bash
docker compose -f docker-compose.production.yml build --pull
```

**3. Initialize Database:**
```bash
docker compose -f docker-compose.production.yml run --rm web bin/rails db:create db:migrate
```

**4. Precompile Assets:**
```bash
docker compose -f docker-compose.production.yml run --rm web bin/rails assets:precompile
```

**5. Start Services:**
```bash
docker compose -f docker-compose.production.yml up -d
```

**6. Register Telegram Webhook:**
```bash
curl -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://inbox-pi.tail-xxxxx.ts.net/api/telegram/webhook"}'
```

**7. Verify Health:**
```bash
docker compose -f docker-compose.production.yml ps
curl https://inbox-pi.tail-xxxxx.ts.net/up
```

---

### ✅ Monitoring & Maintenance

**Health Checks:**
```bash
# Service status
docker compose -f docker-compose.production.yml ps

# Logs
docker compose logs -f --tail=100

# Disk usage
df -h
docker system df

# Memory usage
free -h
docker stats --no-stream
```

**Backup Strategy:**
```bash
# Backup database (daily cron)
0 2 * * * docker compose -f /home/pi/inbox/docker-compose.production.yml exec -T web sqlite3 /app/storage/production.sqlite3 ".backup '/app/storage/backups/backup-$(date +\%Y\%m\%d).db'"

# Backup files (weekly)
0 3 * * 0 tar -czf /mnt/ssd/backups/inbox-$(date +\%Y\%m\%d).tar.gz /home/pi/inbox/storage
```

**Updates:**
```bash
# Pull latest code
cd /home/pi/inbox
git pull origin main

# Rebuild and restart
docker compose -f docker-compose.production.yml build --pull
docker compose -f docker-compose.production.yml up -d

# Run migrations
docker compose -f docker-compose.production.yml exec web bin/rails db:migrate
```

---

### ✅ Security Checklist

- [ ] Change default passwords
- [ ] Enable UFW firewall (`ufw allow 22,80,443/tcp`)
- [ ] Disable SSH password login (keys only)
- [ ] Setup fail2ban for SSH
- [ ] Enable Telegram bot authorization (TELEGRAM_ALLOWED_USER_ID)
- [ ] Rate limit Telegram webhook (Rack::Attack)
- [ ] HTTPS only (via Tailscale/Cloudflare)
- [ ] Regular security updates (`unattended-upgrades`)
- [ ] Backup encryption (gpg or rclone + encrypted remote)

---

### ✅ Performance Tuning

**For 8GB RAM Pi 5:**
- Whisper: `base` model (~1.5GB memory)
- Ollama: `mistral:7b` or smaller model (~4GB)
- Redis: 256MB maxmemory with LRU eviction
- Swap: 2GB for occasional spikes
- SSD recommended for database (faster than SD card)

**Low-Memory Mode** (for 4GB Pi or heavy load):
- Whisper: `tiny` model (~400MB, faster but less accurate)
- Ollama: `phi3:mini` (~2GB) or disable classification
- Redis: 128MB maxmemory
- Worker: 1 Sidekiq thread only

---

## Testing Checklist

- [ ] All services start on boot
- [ ] Telegram webhook receives messages
- [ ] Voice transcription works
- [ ] Database persists across restarts
- [ ] External URL accessible from phone (4G/5G)
- [ ] Logs don't fill disk (rotation working)
- [ ] Backup cron job runs successfully
- [ ] Health checks pass
- [ ] Memory usage stable (<80% after 24h)

---

## Documentation Deliverables

- [ ] Production deployment guide (`docs/deployment.md`)
- [ ] Network access comparison table
- [ ] Troubleshooting guide
- [ ] Backup/restore procedures
- [ ] Monitoring dashboard setup (optional: Grafana + Prometheus)

---

## Recommended Solution

**Tailscale + Funnel** (Option A)

**Reasoning:**
1. ✅ Zero configuration (no port forwarding, no VPS, no DNS)
2. ✅ Free for personal use
3. ✅ Stable HTTPS endpoints (no ngrok timeouts)
4. ✅ Works behind CGNAT
5. ✅ Easy to set up (5 minutes)
6. ✅ Secure by default (WireGuard encryption)
7. ✅ MagicDNS for easy access

**Setup Time:** ~10 minutes  
**Cost:** $0  
**Reliability:** High (99.99% uptime)

---

## Alternative for Custom Domain

If custom domain is required: **Cloudflare Tunnel** (Option B)

- Register domain on Cloudflare ($10/year)
- Setup tunnel (15 minutes)
- Get `https://inbox.yourdomain.com`
- Free DDoS protection + CDN

---

## Notes

- Test network solution on local machine first before RPi deployment
- Document chosen network solution in README.md
- Consider setting up Uptime Kuma for monitoring: https://github.com/louislam/uptime-kuma
- For high traffic, consider load balancing with multiple Pi units

---

## Success Criteria

✅ Application accessible from anywhere via stable HTTPS URL  
✅ Telegram bot responds to messages 24/7  
✅ No manual intervention needed for 30+ days  
✅ Database backed up daily  
✅ Service auto-restarts on failures  
✅ Monitoring alerts on issues
