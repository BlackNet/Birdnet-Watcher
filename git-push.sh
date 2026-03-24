#!/bin/bash

# ============================================================
# Git Push Helper for BirdNET-Watcher
# ------------------------------------------------------------
# Automates staging, committing, and pushing changes to GitHub.
# This script will NOT include:
#   • .env
#   • state/ directory
#   • any other .gitignore entries
# ============================================================

cd /root/birdnet-watcher || exit 1

# Default commit message with timestamp
COMMIT_MSG="Update on $(date '+%Y-%m-%d %H:%M:%S')"

# Allow custom commit message
if [ $# -gt 0 ]; then
    COMMIT_MSG="$*"
fi

echo "Staging changes..."
git add .

echo "Creating commit..."
git commit -m "$COMMIT_MSG"

echo "Pushing to GitHub..."
git push

echo "Done."
git status
