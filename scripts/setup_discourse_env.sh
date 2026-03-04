#!/bin/bash
# Setup script for Claude Code Web - Discourse development environment
# Only runs in remote (cloud) environments

if [ "$CLAUDE_CODE_REMOTE" != "true" ]; then
  exit 0
fi

set -e
cd "$CLAUDE_PROJECT_DIR"

echo "=== Starting Discourse environment setup ==="

# ── Start pre-installed services ──
echo "Starting PostgreSQL..."
sudo service postgresql start
sudo -u postgres createuser --superuser "$USER" 2>/dev/null || true

echo "Starting Redis..."
sudo service redis-server start 2>/dev/null || redis-server --daemonize yes 2>/dev/null || true

# ── Ruby 3.4 via rbenv ──
echo "Installing Ruby 3.4..."
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:/opt/rbenv/bin:/opt/rbenv/shims:$PATH"
eval "$(rbenv init - 2>/dev/null)" || true

# Update ruby-build plugin for latest Ruby versions
if [ -d "$(rbenv root)/plugins/ruby-build" ]; then
  git -C "$(rbenv root)/plugins/ruby-build" pull --quiet 2>/dev/null || true
else
  git clone --quiet https://github.com/rbenv/ruby-build.git "$(rbenv root)/plugins/ruby-build" 2>/dev/null || true
fi

# Install Ruby 3.4 (disable YJIT to avoid needing Rust)
RUBY_CONFIGURE_OPTS="--disable-yjit" rbenv install --skip-existing 3.4.2
rbenv global 3.4.2
rbenv rehash
eval "$(rbenv init -)"

echo "Ruby version: $(ruby --version)"

# ── Persist environment for subsequent bash commands ──
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo "PATH=$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH" >> "$CLAUDE_ENV_FILE"
  echo "RBENV_VERSION=3.4.2" >> "$CLAUDE_ENV_FILE"
fi

# ── Install gem dependencies ──
echo "Installing bundler and gems..."
gem install bundler --no-document
bundle install --jobs "$(nproc)" --retry 3

# ── Install frontend dependencies ──
echo "Installing frontend dependencies..."
pnpm install

# ── Setup test database ──
echo "Setting up test database..."
RAILS_ENV=test bundle exec rake db:create db:migrate 2>/dev/null || \
  RAILS_ENV=test bundle exec rake db:migrate

echo ""
echo "=== Setup complete ==="
echo "Ruby: $(ruby --version)"
echo "Bundler: $(bundle --version)"
echo "Node: $(node --version)"
echo "PostgreSQL: $(pg_isready 2>&1)"
echo "Redis: $(redis-cli ping 2>&1)"
exit 0
