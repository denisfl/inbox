# Multi-stage Dockerfile for Inbox using Alpine Linux
# Minimal, lightweight, perfect for Raspberry Pi
# Ruby 3.3.1 on Alpine

ARG RUBY_VERSION=3.3.1
FROM ruby:${RUBY_VERSION}-alpine AS base

# Set environment variables
ENV LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PNPM_HOME="/pnpm" \
    PATH="$PNPM_HOME:$PATH"

# Install build dependencies (minimal)
RUN apk add --no-cache --virtual .build-deps \
    build-base \
    python3 \
    pkgconfig \
    git

# Install runtime dependencies only
RUN apk add --no-cache \
    curl \
    sqlite-libs \
    sqlite-dev \
    vips \
    vips-dev \
    imagemagick \
    ffmpeg \
    python3 \
    py3-pip \
    ca-certificates \
    tzdata

# Install Node.js from Alpine edge repo (more reliable)
RUN apk add --no-cache \
    nodejs \
    npm

# Install pnpm
RUN npm install -g pnpm@latest --no-audit

# Install bundler
RUN gem install bundler

WORKDIR /app

# ==================== PRODUCTION BASE ====================
FROM base AS production_base

ENV RAILS_ENV=production \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test"

# Copy dependency files
COPY Gemfile Gemfile.lock ./

# Install production gems only
RUN bundle config set without "development test" && \
    bundle install --jobs 4 && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# ==================== DEVELOPMENT STAGE ====================
FROM base AS development

# Override for development - install ALL gems
ENV RAILS_ENV=development \
    BUNDLE_PATH=/usr/local/bundle

# Install development tools only when needed
RUN apk add --no-cache \
    vim \
    less \
    postgresql-client

# Copy dependency files
COPY Gemfile Gemfile.lock ./
COPY package.json ./
COPY pnpm-lock.yaml* ./

# Install ALL gems (including dev/test) - NO bundle config restrictions
RUN bundle install --jobs 4

# Install Node modules
RUN pnpm install

# Copy application
COPY . .

# Create necessary directories
RUN mkdir -p /app/log /app/tmp /app/db

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]

# ==================== BUILD STAGE ====================
FROM production_base AS builder

# Only install what's needed for build
RUN apk add --no-cache \
    python3 \
    py3-pip

# Copy application code first (needed for pnpm install with build script)
COPY . .

# Install Node.js packages (include devDependencies for build)
RUN pnpm install

# Temporarily install ALL gems (including dev/test) for asset precompilation
# This is needed because Rails loads the Gemfile during asset compilation
RUN bundle config unset without && \
    bundle install --jobs 4 && \
    RAILS_ENV=production SECRET_KEY_BASE=dummy bundle exec rails assets:precompile && \
    bundle config set without "development test" && \
    bundle clean --force


# ==================== PRODUCTION STAGE ====================
FROM production_base AS production

# Set production bundle config BEFORE any gem operations
ENV BUNDLE_DEPLOYMENT=true \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_FROZEN=true

# Create non-root user
RUN addgroup -g 1000 -S rails && \
    adduser -u 1000 -S rails -G rails && \
    mkdir -p /app && \
    chown -R rails:rails /app

WORKDIR /app

# Copy from builder (minimal)
COPY --from=builder --chown=rails:rails "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=builder --chown=rails:rails /app/node_modules ./node_modules
COPY --from=builder --chown=rails:rails /app/public/assets ./public/assets
COPY --chown=rails:rails . .

# Ensure bundle config persists for runtime
RUN bundle config set deployment true && \
    bundle config set without "development test" && \
    bundle config set frozen true

# Create dirs
RUN mkdir -p /app/log /app/tmp /app/db && \
    chown -R rails:rails /app

USER rails

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
