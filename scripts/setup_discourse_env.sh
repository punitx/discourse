#!/bin/bash
# Setup script for Claude Code Web - Discourse development environment
# Only runs in remote (cloud) environments

if [ "$CLAUDE_CODE_REMOTE" != "true" ]; then
  exit 0
fi

set -e
cd "$CLAUDE_PROJECT_DIR"

# ── Prevent concurrent runs (UI Setup + SessionStart hook) ──
LOCKFILE="/tmp/discourse_setup.lock"
if [ -f "$LOCKFILE" ]; then
  LOCK_PID=$(cat "$LOCKFILE" 2>/dev/null)
  if kill -0 "$LOCK_PID" 2>/dev/null; then
    echo "Setup already running (PID $LOCK_PID), skipping."
    exit 0
  fi
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

# ── Skip if already completed ──
DONE_MARKER="/tmp/discourse_setup_done"
if [ -f "$DONE_MARKER" ]; then
  echo "Setup already completed, skipping."
  exit 0
fi

echo "=== Starting Discourse environment setup ==="

# ── Start pre-installed services ──
echo "[1/7] Starting PostgreSQL..."
sudo service postgresql start
sudo -u postgres createuser --superuser "$(whoami)" 2>/dev/null || true

echo "[2/7] Starting Redis..."
sudo service redis-server start 2>/dev/null || redis-server --daemonize yes 2>/dev/null || true

# ── Ruby 3.4 via rbenv ──
echo "[3/7] Installing Ruby 3.4..."
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:/opt/rbenv/bin:/opt/rbenv/shims:$PATH"
eval "$(rbenv init - 2>/dev/null)" || true

# Update ruby-build plugin (timeout to prevent hang)
if [ -d "$(rbenv root)/plugins/ruby-build" ]; then
  timeout 30 git -C "$(rbenv root)/plugins/ruby-build" pull --quiet 2>/dev/null || true
else
  timeout 60 git clone --quiet https://github.com/rbenv/ruby-build.git "$(rbenv root)/plugins/ruby-build" 2>/dev/null || true
fi

# Install Ruby 3.4 (disable YJIT to avoid needing Rust)
RUBY_CONFIGURE_OPTS="--disable-yjit" rbenv install --skip-existing 3.4.2
rbenv global 3.4.2
rbenv rehash
eval "$(rbenv init -)"

echo "  Ruby version: $(ruby --version)"

# ── Persist environment for subsequent bash commands ──
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo "PATH=$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH" >> "$CLAUDE_ENV_FILE"
  echo "RBENV_VERSION=3.4.2" >> "$CLAUDE_ENV_FILE"
fi

# ── Install correct bundler version and gems ──
echo "[4/7] Installing bundler 2.6.4..."
gem install bundler -v 2.6.4 --no-document

echo "[5/7] Installing gems (this takes several minutes)..."
bundle _2.6.4_ config set --local silence_root_warning true
bundle _2.6.4_ install --jobs "$(nproc)" --retry 3

# ── Install frontend dependencies ──
echo "[6/7] Installing frontend dependencies..."
pnpm install

# ── Setup test database ──
echo "[7/7] Setting up test database..."
RAILS_ENV=test bundle _2.6.4_ exec rake db:create db:migrate 2>/dev/null || \
  RAILS_ENV=test bundle _2.6.4_ exec rake db:migrate

# ── Mark complete ──
touch "$DONE_MARKER"

echo ""
echo "=== Setup complete ==="
echo "Ruby: $(ruby --version)"
echo "Bundler: $(bundle _2.6.4_ --version)"
echo "Node: $(node --version)"
echo "PostgreSQL: $(pg_isready 2>&1)"
echo "Redis: $(redis-cli ping 2>&1)"
exit 0
