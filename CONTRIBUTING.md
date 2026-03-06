# Contributing to Inbox

Thank you for your interest in contributing! This guide will help you get started.

## Prerequisites

- **Ruby** 3.3+ (via [asdf](https://asdf-vm.com/), rbenv, or rvm)
- **Node.js** 22+ (via asdf or nvm)
- **pnpm** (package manager)
- **SQLite3** 3.43+
- **Git**

## Development Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/inbox.git
cd inbox

# Install Ruby dependencies
bundle install

# Install Node.js dependencies
pnpm install

# Setup database
bin/rails db:create db:migrate db:seed

# Build CSS and JS assets
pnpm run build
pnpm run build:css

# Start the development server
bin/dev
```

The app will be available at `http://localhost:3000`.

## Running Tests

```bash
# Run the full test suite
bundle exec rspec

# Run a specific test file
bundle exec rspec spec/models/document_spec.rb

# Run with coverage report
COVERAGE=true bundle exec rspec
```

## Code Style

We use **RuboCop** for Ruby code style enforcement:

```bash
# Check code style
bin/rubocop

# Auto-fix safe corrections
bin/rubocop -a

# Check with GitHub-style output (used in CI)
bin/rubocop -f github
```

## Security

We use **Brakeman** for security scanning:

```bash
bin/brakeman --no-pager
```

## Project Structure

```
app/
├── controllers/     # Rails controllers (web + API)
├── helpers/         # View helpers
├── javascript/      # Stimulus controllers
├── jobs/            # Background jobs (Sidekiq/SolidQueue)
├── models/          # ActiveRecord models
├── services/        # Service objects
└── views/           # ERB templates

config/              # Rails configuration
db/                  # Migrations and schema
spec/                # RSpec tests
whisper_service/     # Python Parakeet v3 transcription service
openspec/            # Feature specifications
```

## Making Changes

1. Create a new branch from `master`:

   ```bash
   git checkout -b feat/your-feature-name
   ```

2. Make your changes

3. Ensure tests pass:

   ```bash
   bundle exec rspec
   bin/rubocop
   bin/brakeman --no-pager
   ```

4. Commit using [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

   ```
   feat: add tag filtering to documents page
   fix: correct pagination offset for empty results
   refactor: extract calendar sync into service object
   ```

5. Push and open a Pull Request

## Pull Request Guidelines

- Keep PRs focused — one feature or fix per PR
- Include tests for new features
- Update documentation if needed
- Ensure CI passes (RuboCop, Brakeman, RSpec)
- Write a clear PR description explaining _what_ and _why_

## Docker Development

If you prefer Docker:

```bash
docker compose up -d
```

This starts: web server, Redis, and transcription service (Parakeet v3).

## Questions?

Open an issue if you have questions or need help getting started.
