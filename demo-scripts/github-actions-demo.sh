#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------------------------------------------------
# NightVision GitHub Actions demo
#
# Clones your fork of java-github-actions-demo, wires the NIGHTVISION_TOKEN Actions secret,
# creates a NightVision app + target, records auth, and pushes a commit to trigger the
# workflow.
#
# Re-run behaviour: this script is intended to be safe to re-run. The create steps
# (NightVision app/target) are guarded so a second run reuses existing resources with a
# logged warning instead of aborting. The NightVision token is the exception: each run
# creates a fresh one and overwrites the Actions secret (the value cannot be read back, so
# it is rotated, not reused); older tokens stay in NightVision, so revoke them there if you
# re-run often. The script does NOT delete anything; see the cleanup notes at the bottom.
# ---------------------------------------------------------------------------------------------------------------------

# Authenticate to GitHub and NightVision first, so the steps below only run after both
# logins are confirmed - an aborted login then leaves nothing half-created.
if ! gh auth status 2>&1 | grep -q 'Logged in to github.com'; then
    echo "GitHub CLI not authenticated. Running 'gh auth login'..."
    gh auth login
else
    echo "Logged in to github already..."
fi
nightvision login

# Clone your fork of the demo repository. The owner comes from the authenticated GitHub
# login: 'git config user.name' is a display name, not a valid URL segment for most users.
# Idempotent: reuse an existing checkout instead of failing on a second run, but only
# after confirming it points at the expected fork - a stale checkout of another repo
# would otherwise receive the push at the end of the script.
OWNER="$(gh api user --jq .login)"
if [ ! -d java-github-actions-demo ]; then
    git clone "https://github.com/$OWNER/java-github-actions-demo.git"
elif ! git -C java-github-actions-demo remote get-url origin | grep -qiE "github\.com[:/]$OWNER/java-github-actions-demo(\.git)?$"; then
    echo "ERROR: existing ./java-github-actions-demo does not point at $OWNER/java-github-actions-demo; move it aside and re-run." >&2
    exit 1
fi
cd java-github-actions-demo

# Create a fresh NightVision token for the NIGHTVISION_TOKEN Actions secret, without
# writing it to disk. tr strips any stray whitespace; the guard catches an empty result
# (an exit-0 token create with no output) before it becomes an empty secret.
TOKEN="$(nightvision token create | tr -d '[:space:]')"
if [ -z "$TOKEN" ]; then
    echo "ERROR: 'nightvision token create' returned an empty token; aborting." >&2
    exit 1
fi

# Set the Actions secret to the freshly created token (rotated every run, not reused,
# because a token's value cannot be read back). 'gh secret set' upserts, so no
# already-exists guard is needed; a real failure aborts the script (set -e). The explicit
# --repo pins the secret to your fork rather than inferring it from the checkout's remote.
gh secret set NIGHTVISION_TOKEN --body "$TOKEN" --repo "$OWNER/java-github-actions-demo"

# ---------------------------------------------------------------------------------------------------------------------
# NightVision commands
# ---------------------------------------------------------------------------------------------------------------------
# Create app and target. Guarded so a re-run reuses the existing app/target.
URL="https://localhost:9000"
APP="javaspringvulny-api"
nightvision app create "$APP" || echo "WARNING: 'nightvision app create $APP' failed (it may already exist); continuing."
nightvision target create "$APP" "$URL" --type API || echo "WARNING: 'nightvision target create $APP' failed (it may already exist); continuing."

# Start the application
docker compose up -d; sleep 10
# Record authentication - click on Form Auth.
# These are the demo application's default credentials (the javaspringvulny sample app),
# not real secrets.
echo "Click on Form Auth and use the javaspringvulny demo defaults:"
echo "  Username: user"
echo "  Password: password"
nightvision auth playwright create "$APP" "$URL"

# ---------------------------------------------------------------------------------------------------------------------
# Add an empty commit and push to trigger the GitHub Actions workflow. An empty
# commit always provides a fresh commit to push (including on a re-run against an
# existing checkout) without modifying tracked files.
# ---------------------------------------------------------------------------------------------------------------------
git commit --allow-empty -m "Trigger GitHub Actions workflow"
git push

# Notes:
# To clean up (substitute your GitHub login):
# gh secret delete NIGHTVISION_TOKEN --repo <your-github-login>/java-github-actions-demo
# rm -rf ./java-github-actions-demo
