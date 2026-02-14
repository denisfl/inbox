# Story 1: Project Setup & Baseline

**Priority:** P0 (Critical)  
**Complexity:** Medium  
**Estimated Effort:** 2-3 days  
**Dependencies:** None  
**Status:** Ready to start

---

## User Story

As a developer, I want the project baseline fully configured so that the team can start building features confidently.

---

## Acceptance Criteria

### ✅ Environment Setup

- [ ] Ruby 3.3.1 installed via rbenv
- [ ] Rails 8.0.x installed
- [ ] Node.js 22+ installed via nvm
- [ ] Docker 20.10+ installed
- [ ] Docker Compose 2.x installed

### ✅ Project Initialization

- [ ] Rails new project created
- [ ] Gemfile configured with dependencies:
  - rails (8.0.x)
  - sqlite3
  - puma (~6.0)
  - sidekiq (~7.0)
  - redis (~5.0)
  - telegram-bot-ruby
  - rspec-rails (dev/test)
  - rubocop (dev)
- [ ] package.json configured with:
  - @hotwired/stimulus (^3.2.0)
  - @hotwired/turbo (^7.3.0)
  - esbuild (^0.17.0)
  - prettier (^3.0.0)
- [ ] Bundler lockfile committed
- [ ] npm lockfile committed

### ✅ Configuration Files

- [ ] `.env.example` created with all required variables
- [ ] `.editorconfig` for consistent formatting
- [ ] `.rubocop.yml` for Ruby linting
- [ ] `.prettierrc` for JS formatting
- [ ] `.gitignore` configured (node_modules, .env, etc.)

### ✅ Docker Setup

- [ ] `Dockerfile` for Rails app
- [ ] `docker-compose.yml` with services:
  - web (Rails + Puma)
  - worker (Sidekiq)
  - redis
  - ollama
- [ ] `docker-compose.dev.yml` for development
- [ ] Health check endpoint implemented: `GET /health`

### ✅ Scripts & Automation

- [ ] `bin/setup` - Initial setup script
- [ ] `bin/dev` - Start development server
- [ ] `bin/test` - Run test suite
- [ ] `bin/lint` - Run linters
- [ ] `bin/format` - Format code
- [ ] Makefile with common tasks

### ✅ Testing Infrastructure

- [ ] RSpec configured with:
  - spec_helper.rb
  - rails_helper.rb
  - Factory Bot setup
  - Database cleaner
  - SimpleCov for coverage
- [ ] First passing test (sanity check)

### ✅ CI Pipeline (Optional for MVP)

- [ ] GitHub Actions workflow (or skip for now)
- [ ] Quality gates defined

### ✅ Documentation

- [ ] README.md with:
  - Project description
  - Local setup instructions
  - Docker setup instructions
  - Available scripts
  - Environment variables
- [ ] CONTRIBUTING.md (optional)

---

## Technical Tasks

1. **Initialize Rails Project**

   ```bash
   rails new inbox --database=sqlite3 --css=tailwind --javascript=esbuild
   cd inbox
   ```

2. **Configure Gemfile**

   ```ruby
   source 'https://rubygems.org'
   ruby '3.3.1'

   gem 'rails', '~> 8.0'
   gem 'sqlite3'
   gem 'puma', '~> 6.0'
   gem 'sidekiq', '~> 7.0'
   gem 'redis', '~> 5.0'
   gem 'telegram-bot-ruby'

   group :development, :test do
     gem 'rspec-rails'
     gem 'factory_bot_rails'
     gem 'faker'
   end

   group :development do
     gem 'rubocop'
     gem 'rubocop-rails'
   end

   group :test do
     gem 'simplecov', require: false
     gem 'database_cleaner-active_record'
   end
   ```

3. **Install Dependencies**

   ```bash
   bundle install
   npm install
   ```

4. **Configure RSpec**

   ```bash
   rails generate rspec:install
   ```

5. **Create Docker Files**
   - Dockerfile
   - docker-compose.yml
   - docker-compose.dev.yml

6. **Create Scripts**
   - bin/setup
   - bin/dev
   - bin/test
   - bin/lint

7. **Write Documentation**
   - README.md
   - Update .env.example

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Code committed to git
- [ ] Tests passing (green CI)
- [ ] Documentation complete
- [ ] Reviewed by at least one developer
- [ ] Successfully deployed in local Docker

---

## Notes

- This is the foundation story - all other stories depend on it
- Keep it simple - focus on MVP configuration
- Defer complex CI/CD to later if needed
- Ensure Docker setup works on macOS and Linux
