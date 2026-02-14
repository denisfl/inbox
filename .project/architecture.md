# Technical Specifications

## Project Summary

- **Project**: Inbox
- **Template**: Block-Based Personal Note-Taking System
- **Frontend**: Yes (Stimulus JS recommended, or Vanilla JS)
- **Backend**: Yes (Rails 8 API)
- **Database**: Yes (SQLite3)
- **Authentication**: Minimal (Optional token or session)
- **AI/ML**: Yes (Ollama for classification, Whisper for transcription)
- **Container**: Yes (Docker for development and deployment)

---

## Version Policy

> ⚠️ **STRICT RULE**: Downgrading package versions is **FORBIDDEN**. Upgrading is allowed only after testing.

**Locked Versions:**

```
Ruby: 3.3.1 (do not downgrade)
Rails: 8.0.x (do not downgrade)
SQLite: 3.43+ (do not downgrade)
Redis: 7.x (do not downgrade)
Node.js: 22+ (do not downgrade)
Ollama: latest (pinned in docker-compose)
Whisper: latest pip install (pinned in Dockerfile)
```

---

## Technology Stack

### Backend

| Component          | Technology    | Version  | Purpose                        |
| ------------------ | ------------- | -------- | ------------------------------ |
| **Framework**      | Rails         | 8.0.x    | Web framework & API            |
| **Language**       | Ruby          | 3.3.1    | Backend language               |
| **Web Server**     | Puma          | 6.x      | HTTP server                    |
| **Database**       | SQLite        | 3.43+    | Primary data store             |
| **Queue**          | Sidekiq       | 7.x      | Background jobs                |
| **Cache**          | Redis         | 7.x      | Cache & job queue              |
| **Authentication** | Devise        | 4.x      | User authentication (optional) |
| **Authorization**  | Pundit        | 2.x      | Role-based access              |
| **File Storage**   | ActiveStorage | Built-in | File management                |

### Frontend

| Component           | Technology   | Version  | Purpose                 |
| ------------------- | ------------ | -------- | ----------------------- |
| **Framework**       | Stimulus JS  | 3.x      | Interactivity           |
| **CSS Framework**   | Tailwind CSS | 4.x      | Styling                 |
| **Template Engine** | ERB          | Built-in | HTML rendering          |
| **Build Tool**      | importmap    | Rails 8  | No build process needed |
| **Package Manager** | npm          | 9+       | Node package management |

### AI & ML

| Component               | Technology                 | Version | Purpose               |
| ----------------------- | -------------------------- | ------- | --------------------- |
| **Audio Transcription** | OpenAI Whisper             | Latest  | Voice-to-text         |
| **Note Classification** | Ollama                     | Latest  | Local LLM inference   |
| **Models**              | mistral/neural-chat/llama2 | Latest  | Classification models |

### DevOps & Containerization

| Component             | Technology               | Version  | Purpose                      |
| --------------------- | ------------------------ | -------- | ---------------------------- |
| **Container Runtime** | Docker                   | 20.10+   | Application containerization |
| **Orchestration**     | Docker Compose           | 2.x      | Multi-container management   |
| **OS (RPi)**          | Raspberry Pi OS / Ubuntu | Latest   | Target deployment OS         |
| **Service Manager**   | systemd                  | Built-in | Service lifecycle management |
| **Task Scheduler**    | cron                     | Built-in | Scheduled tasks              |

### Development Tools

| Component          | Technology   | Version | Purpose           |
| ------------------ | ------------ | ------- | ----------------- |
| **Test Framework** | RSpec        | 6.x     | Testing           |
| **Linter**         | Rubocop      | 1.x     | Ruby linting      |
| **Formatter**      | Prettier\*\* | 3.x     | Code formatting   |
| **Git Hooks**      | pre-commit   | 3.x     | Commit validation |

---

## Runtime & Tooling

### Ruby Environment

```bash
# Ruby version management
Tool: rbenv
Ruby: 3.3.1
Bundler: 2.4.x

# Installation
rbenv install 3.3.1
rbenv global 3.3.1
gem install bundler
```

### Node.js Environment

```bash
# Node version management
Tool: nvm
Node.js: 22+
npm: 9+
```

### Docker Environment

```bash
# Docker installation
Docker: 20.10+
Docker Compose: 2.x

# Installation
# macOS: brew install docker docker-compose
# Linux: apt-get install docker.io docker-compose
# Windows: Docker Desktop

# Verify
docker --version
docker-compose --version
```

### Package Managers

```ruby
# Gemfile (Ruby dependencies)
source 'https://rubygems.org'
ruby '3.3.1'

gem 'rails', '~> 8.0'
gem 'sqlite3'
gem 'puma', '~> 6.0'
gem 'sidekiq', '~> 7.0'
gem 'redis', '~> 5.0'
gem 'devise'
gem 'pundit'
gem 'telegram-bot-ruby'
gem 'image_processing'
gem 'rails_admin'

group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
end

group :development do
  gem 'rubocop'
  gem 'rubocop-rails'
end
```

```json
// package.json (Node dependencies)
{
  "name": "inbox",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "build": "esbuild app/javascript/application.js --bundle --sourcemap --outdir=app/assets/builds",
    "dev": "esbuild app/javascript/application.js --bundle --sourcemap --outdir=app/assets/builds --watch",
    "lint": "prettier --check ."
  },
  "dependencies": {
    "@hotwired/stimulus": "^3.2.0",
    "@hotwired/turbo": "^7.3.0"
  },
  "devDependencies": {
    "esbuild": "^0.17.0",
    "prettier": "^3.0.0"
  }
}
```

---

## Environment & Configuration

### Required Environment Variables

```bash
# Rails Core
RAILS_ENV=production
SECRET_KEY_BASE=<generated via `rails secret`>
RAILS_LOG_TO_STDOUT=true

# Database
DATABASE_URL=sqlite:///db/production.sqlite3
DATABASE_TIMEOUT=5000

# Redis
REDIS_URL=redis://redis:6379/0

# Telegram
TELEGRAM_BOT_TOKEN=<from @BotFather>
TELEGRAM_WEBHOOK_URL=https://your-domain.com/api/telegram/webhook

# Authentication
API_TOKEN=<random secure token for API access>
API_TOKEN_ROTATION_DAYS=90

# Ollama AI (FINALIZED: mistral 4.1GB for accuracy)
OLLAMA_BASE_URL=http://ollama:11434
OLLAMA_MODEL=mistral
OLLAMA_MAX_MEMORY=4GB
OLLAMA_TIMEOUT=30  # seconds for classification

# Whisper Audio (FINALIZED: base 1.5GB for Russian accuracy)
WHISPER_MODEL_SIZE=base
WHISPER_LANGUAGE=ru
WHISPER_TIMEOUT=300  # seconds for transcription (5 min max)

# Sidekiq
SIDEKIQ_CONCURRENCY=2
SIDEKIQ_TIMEOUT=600

# Backup
BACKUP_ENABLED=true
BACKUP_RETENTION_DAYS=7
BACKUP_ENCRYPTION_KEY=<gpg-key-id>
CLOUD_BACKUP_ENABLED=false  # User opt-in
CLOUD_BACKUP_PROVIDER=gdrive

# Logging
LOG_LEVEL=info
```

### Secrets Management

```bash
# Development (.env.local - git ignored)
TELEGRAM_BOT_TOKEN=test_token_here
API_TOKEN=dev_token

# Production (.env.production - git ignored)
# Use secure password manager:
# - 1Password
# - LastPass
# - Vault
# - AWS Secrets Manager

# Docker secrets (for production)
# Mount .env.production inside container
# Or use Docker secrets feature
```

### Local Development Setup

```bash
# 1. Clone repository
git clone <repo> inbox
cd inbox

# 2. Create .env.local
cp .env.example .env.local
# Edit with your test tokens

# 3. Setup Docker
docker-compose up -d

# 4. Setup database
docker-compose exec web rails db:create
docker-compose exec web rails db:migrate

# 5. Verify services
docker-compose ps
redis-cli ping
curl http://localhost:11434/api/tags

# 6. Start development
docker-compose up
# Visit http://localhost:3000
```

---

## API & Contracts

### REST API Endpoints

```
BASE_URL: /api

# Documents
GET    /documents              # List all documents (paginated)
POST   /documents              # Create new document
GET    /documents/:id          # Get document with blocks
PATCH  /documents/:id          # Update document metadata
DELETE /documents/:id          # Delete document

# Blocks
POST   /documents/:id/blocks                    # Add block to document
PATCH  /documents/:id/blocks/:block_id          # Update block content
DELETE /documents/:id/blocks/:block_id          # Delete block
POST   /documents/:id/blocks/reorder            # Reorder blocks

# Search
GET    /documents/search?q=<query>              # Full-text search
GET    /documents/search?tag=<tag>              # Filter by tag
GET    /documents/search?category=<category>    # Filter by category

# Classification (Ollama)
POST   /documents/:id/classify                  # Auto-classify document
POST   /documents/:id/extract-tags              # Extract tags with AI
GET    /documents/:id/summary                   # Generate AI summary

# Telegram
POST   /telegram/webhook                        # Receive Telegram messages
```

### Request/Response Schema

**Create Document:**

```json
// Request
POST /api/documents
{
  "document": {
    "title": "My Note",
    "blocks": [
      {
        "type": "TextBlock",
        "data": { "text": "Some content" },
        "position": 0
      }
    ],
    "tags": ["work", "important"]
  }
}

// Response (201 Created)
{
  "id": "uuid",
  "slug": "abc123",
  "title": "My Note",
  "source": "web",
  "blocks": [...],
  "tags": ["work", "important"],
  "category": "Work",  // From Ollama classification
  "priority": "High",  // From Ollama classification
  "created_at": "2024-01-01T12:00:00Z"
}
```

**Error Response:**

```json
{
  "error": "Validation Error",
  "message": "Title cannot be blank",
  "status": 422,
  "errors": {
    "title": ["can't be blank"]
  }
}
```

### HTTP Status Codes

| Code    | Meaning       | Usage                        |
| ------- | ------------- | ---------------------------- |
| **200** | OK            | Successful GET, PATCH        |
| **201** | Created       | Successful POST              |
| **204** | No Content    | Successful DELETE            |
| **400** | Bad Request   | Invalid parameters           |
| **401** | Unauthorized  | Missing API token            |
| **404** | Not Found     | Document/block not found     |
| **422** | Unprocessable | Validation failed            |
| **500** | Server Error  | Rails error                  |
| **503** | Unavailable   | Service (Redis, Ollama) down |

### Pagination Convention

```
GET /api/documents?page=1&per_page=20

Response:
{
  "data": [...],
  "pagination": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 150,
    "total_pages": 8
  }
}
```

---

## Observability

### Logging Strategy

**Log Levels:**

- **DEBUG**: Detailed info for debugging (development only)
- **INFO**: General information about application flow
- **WARN**: Warning messages, potential issues
- **ERROR**: Error messages, failures
- **FATAL**: Critical errors

**Implementation:**

```ruby
# app/controllers/api/documents_controller.rb
Rails.logger.info("Document created: #{@document.id}")
Rails.logger.warn("Slow query detected: #{duration}ms")
Rails.logger.error("Transcription failed: #{error.message}")
```

**Log Output:**

```
/var/log/notesvault/
├── production.log          # Main Rails logs
├── sidekiq.log             # Background job logs
├── ollama.log              # AI service logs
└── access.log              # HTTP request logs (optional)
```

**Log Retention:**

- Keep 7 days of active logs
- Compress logs older than 7 days
- Delete logs older than 30 days

### Metrics Collection

**Application Metrics:**

```ruby
# app/metrics/collector.rb
class MetricsCollector
  # API response time
  measure :api_response_time, "time taken to respond to API request"

  # Database query time
  measure :db_query_time, "time taken to execute database query"

  # Job processing time
  measure :job_processing_time, "time taken to process background job"

  # Ollama inference time
  measure :ollama_inference_time, "time taken for AI classification"

  # Queue depth
  gauge :sidekiq_queue_depth, "number of pending background jobs"

  # Error rate
  counter :api_errors, "number of API errors"
end
```

**System Metrics (Docker):**

```bash
# CPU usage
docker stats inbox-web --no-stream | awk '{print $3}'

# Memory usage
docker stats inbox-web --no-stream | awk '{print $4}'

# Disk usage
df -h /var/lib/inbox

# Network I/O
docker stats inbox-web --no-stream | awk '{print $7, $8}'
```

**Monitoring Dashboard:**

```
Create simple monitoring with:
- Prometheus (metrics collection)
- Grafana (visualization)
- AlertManager (alerting)

OR use Docker monitoring:
- docker stats
- cAdvisor (container metrics)
- Custom healthcheck endpoints
```

### Health Checks

```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :authenticate_user!

  def check
    status = {
      web: "ok",
      database: check_database,
      redis: check_redis,
      ollama: check_ollama,
      whisper: check_whisper
    }

    all_ok = status.values.all? { |v| v == "ok" }

    render json: status, status: all_ok ? 200 : 503
  end

  private

  def check_database
    Document.count
    "ok"
  rescue
    "down"
  end

  def check_redis
    redis = Redis.new(url: ENV['REDIS_URL'])
    redis.ping
    "ok"
  rescue
    "down"
  end

  def check_ollama
    # Check if Ollama is responding
    "ok"
  rescue
    "down"
  end

  def check_whisper
    # Check if Whisper model is loaded
    "ok"
  rescue
    "down"
  end
end
```

---

## Security Requirements

### Dependency Vulnerability Scanning

```bash
# Ruby gems security check
bundler audit

# Node.js dependencies security check
npm audit

# Docker image scanning
docker scan inbox:latest

# Automated CI checks
# (In GitHub Actions or similar)
- dependabot
- security-audit workflows
```

### Secrets Management

**Development:**

- Use `.env.local` (git-ignored)
- Store sensitive values locally

**Production:**

- Use environment variables
- Or Docker Secrets
- Or external secret manager (Vault, AWS Secrets Manager)

**Rotation Policy:**

- TELEGRAM_BOT_TOKEN: Rotate if leaked
- SECRET_KEY_BASE: Rotate on major updates
- API_TOKEN: Rotate every 90 days
- Database passwords: Rotate every 6 months

### Data Encryption

**In Transit:**

- Optional HTTPS via Nginx proxy
- Local network assumed trusted

**At Rest:**

- SQLite: Plaintext (local network only)
- Can enable SQLite encryption if needed: `PRAGMA key='password'`

**Backup Encryption:**

- Optional: Encrypt backups with GPG before upload
- `gpg --encrypt --output backup.tar.gz.gpg backup.tar.gz`

### Input Validation

**All API endpoints must validate:**

```ruby
# Example validation in BlocksController
def create
  # Validate document exists
  @document = Document.find(params[:document_id])

  # Validate block type
  unless Block::BLOCK_TYPES.include?(params[:block][:type])
    render json: { error: 'Invalid type' }, status: 400 and return
  end

  # Validate data presence
  if params[:block][:data].blank?
    render json: { error: 'Data required' }, status: 400 and return
  end

  # Validate data size (prevent DoS)
  if params[:block][:data].to_s.length > 1_000_000
    render json: { error: 'Data too large (max 1MB)' }, status: 400 and return
  end

  # Sanitize input
  @block = @document.blocks.build(block_params)
  @block.save!

  render json: @block, status: 201
end
```

### Audit Logging

```ruby
# app/models/audit_log.rb
class AuditLog < ApplicationRecord
  # Log important actions
  def self.log(action, user_id, resource_type, resource_id, details = {})
    create(
      action: action,
      user_id: user_id,
      resource_type: resource_type,
      resource_id: resource_id,
      details: details,
      ip_address: ip,
      timestamp: Time.current
    )
  end
end

# Usage
AuditLog.log('document_created', current_user.id, 'Document', @document.id)
AuditLog.log('document_deleted', current_user.id, 'Document', deleted_doc_id)
```

---

## Quality Standards

### Linting & Formatting

```bash
# Ruby linting (Rubocop)
rubocop

# Ruby formatting
rubocop -a

# JavaScript formatting (Prettier)
prettier --write .

# Auto-fix on commit (pre-commit hook)
pre-commit install
```

### Testing Strategy

**Unit Tests (RSpec):**

```ruby
# spec/models/document_spec.rb
describe Document do
  it "creates document with initial block" do
    doc = Document.create_with_initial_block(title: "Test")
    expect(doc.blocks.count).to eq(1)
  end
end
```

**Integration Tests:**

```ruby
# spec/requests/documents_spec.rb
describe "Documents API" do
  it "creates document via API" do
    post '/api/documents', params: { document: { title: 'Test' } }
    expect(response).to have_http_status(:created)
  end
end
```

**Coverage Targets:**

- **Minimum:** 80% code coverage
- **Target:** 85%+ code coverage
- **Critical:** 100% for payment/security code

### CI Quality Gates

```yaml
# .github/workflows/quality.yml
- name: Run tests
  run: bundle exec rspec

- name: Check coverage
  run: bundle exec rspec --coverage
  env:
    COVERAGE_MINIMUM: 80

- name: Lint code
  run: rubocop

- name: Security audit
  run: bundler audit

- name: Container scan
  run: docker scan inbox:latest
```

---

## Deployment & Operations

### Environments

**Development (Local Docker):**

- Rails in development mode
- SQLite with eager logs
- Ollama lightweight models
- Auto-reload on file changes

**Production (Raspberry Pi Docker):**

- Rails in production mode
- SQLite with backups
- Full Ollama models
- Systemd service management

### Deployment Process

```bash
# 1. Local testing
docker-compose up
# Run tests
docker-compose exec web rspec

# 2. Build production image
docker build -t inbox:latest .

# 3. Deploy to RPi
# Manual: scp image + docker-compose.prod.yml
# Or: CI/CD pipeline

# 4. Start services
docker-compose -f docker-compose.prod.yml up -d

# 5. Run migrations
docker-compose exec web rails db:migrate

# 6. Verify
curl http://raspberrypi.local:3000/health
```

### Rollback Strategy

```bash
# If deploy breaks:
1. Stop services
   docker-compose down

2. Restore previous image
   docker tag inbox:previous inbox:latest

3. Restore database backup
   cp /backup/db-previous.sqlite3 /db/production.sqlite3

4. Start services
   docker-compose up -d

5. Verify health
   curl http://localhost:3000/health
```

### Monitoring & Alerting

**Health Check Endpoint:**

```bash
GET /health
Response:
{
  "web": "ok",
  "database": "ok",
  "redis": "ok",
  "ollama": "ok",
  "whisper": "ok"
}
```

**Alerting Thresholds:**

- **Memory:** Alert if >80%
- **CPU:** Alert if >70% for >5 minutes
- **Disk:** Alert if <10GB free
- **Job Queue:** Alert if >100 pending
- **API Response:** Alert if p95 >500ms

---

## Performance & Scalability

### Performance Budgets

| Metric                | Target              | Alert   |
| --------------------- | ------------------- | ------- |
| API Response          | <100ms p95          | >200ms  |
| Page Load             | <500ms              | >1000ms |
| DB Query              | <50ms p95           | >100ms  |
| Ollama Inference      | <10s p95            | >30s    |
| Whisper Transcription | <1min per min audio | >5min   |

### Scaling Targets

**For Single User:**

- Peak: ~20 API req/min
- Background: ~5 jobs/min
- Expected: Much lower (async)

**Infrastructure:**

```
RPS Target: 50 (plenty for single user)
Concurrency: 5 (Puma threads)
Sidekiq Workers: 2-3
Redis Memory: 100MB typical
SQLite Size: 500MB typical
Storage: 50GB (configurable)
```

### Caching Strategy

**Browser Cache:**

```
JS/CSS: 1 year (immutable)
HTML: no-cache (always fresh)
API: no-cache (real-time)
```

**Application Cache (Redis):**

```ruby
# Cache frequently accessed data
Rails.cache.write("user:documents", documents, expires_in: 5.minutes)
Rails.cache.fetch("user:documents") { Documents.all }
```

**Database Optimization:**

```sql
-- Essential indexes
CREATE INDEX idx_documents_created_at ON documents(created_at);
CREATE INDEX idx_blocks_document_position ON blocks(document_id, position);
CREATE INDEX idx_document_metadata_text ON document_metadata(full_text_index);
```

---

## Finalized Technical Decisions

### 1. AI Model Configuration

**Ollama Model: mistral (4.1GB)**

- Chosen for accuracy over speed
- Raspberry Pi 5 8GB sufficient (4.1GB model + 2GB system + 1-2GB Rails/Redis)
- Async classification allows 5-15s inference time
- Memory peak: ~4.5GB

**Whisper Model: base (1.5GB, Russian)**

- Better accuracy for Russian language transcription
- Async processing via Sidekiq (1-2 min per audio minute)
- Expected accuracy: 90%+ for clear audio
- Memory during transcription: ~2GB

### 2. Data Persistence

**SQLite with WAL Mode** (locked for MVP)

- Zero configuration, perfect for single user
- WAL mode for concurrent reads
- PostgreSQL migration path exists if multi-user needed

### 3. Authentication

**Minimal Token-Based** (MVP)

- Simple API token for Telegram webhook
- Local network assumption (low risk)
- Rotate token every 90 days
- Devise upgrade path if internet exposure needed

### 4. Backup Strategy

**Local + Optional Encrypted Cloud**

- Daily automated local backups (7 daily, 4 weekly, 3 monthly)
- Optional encrypted cloud upload (GPG + rclone)
- User opt-in for cloud (privacy preserved)

---

## Summary

✅ **Stack:** Rails 8 + Stimulus JS + SQLite + Docker  
✅ **AI:** Ollama (mistral 4.1GB) + Whisper (base 1.5GB)  
✅ **Deployment:** Docker Compose on Raspberry Pi 5 (8GB)  
✅ **Quality:** 80%+ test coverage, RSpec + Rubocop  
✅ **Observability:** Logging, metrics, health checks  
✅ **Security:** Input validation, token auth, encrypted backups  
✅ **Performance:** <100ms API, <500ms page load target  
✅ **All technical decisions finalized for MVP**
