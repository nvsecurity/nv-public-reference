#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------------------------------------------------
# NightVision GitLab "Easy Mode" demo (NV-4418)
#
# Creates a GitLab project, wires the NIGHTVISION_TOKEN CI variable, creates a NightVision
# app + target, records auth, and pushes the demo repo to trigger the CI/CD pipeline.
#
# Re-run behaviour: this script is intended to be safe to re-run. The create steps
# (GitLab repo, NightVision app/target) are guarded so a second run reuses existing
# resources with a logged warning instead of aborting, and the gitlab remote is
# reconciled to the current "$GROUP/$REPO" on each run. The NightVision token is
# the exception: each run creates a fresh one and overwrites the CI variable (the value
# cannot be read back, so it is rotated, not reused); older tokens stay in NightVision, so
# revoke them there if you re-run often. The script does NOT delete anything; see the
# cleanup notes at the bottom to tear a demo down.
# ---------------------------------------------------------------------------------------------------------------------

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "This script will create a repository on GitLab. Please provide the group/project and repository name that you want to create."
    echo "Usage: $0 group repo"
    exit 1
fi

# Assign positional arguments to variables
GROUP="$1"
REPO="$2"

echo "Creating a repository under: $GROUP/$REPO"

# Clone the GitHub repository that we will mirror to GitLab.
# Idempotent: reuse an existing checkout instead of failing on a second run.
if [ ! -d java-github-actions-demo ]; then
    git clone https://github.com/nvsecurity/java-github-actions-demo
fi
cd java-github-actions-demo

# ---------------------------------------------------------------------------------------------------------------------
# Set up the GitLab repository
# ---------------------------------------------------------------------------------------------------------------------
# Authenticate to GitLab and NightVision first, so the create steps below only run after
# both logins are confirmed - an aborted login then leaves nothing half-created.
if ! glab auth status 2>&1 | grep -q 'Logged in to gitlab.com'; then
    echo "GitLab CLI not authenticated. Running 'glab auth login'..."
    glab auth login
else
    echo "Logged in to gitlab already..."
fi
nightvision login

# Create a repository in the target namespace. If it already exists, keep going.
echo "NOTE: Select NO for 'Create a local project directory'"
glab repo create "$GROUP/$REPO" || echo "WARNING: 'glab repo create $GROUP/$REPO' failed (the project may already exist); continuing."

# Create a fresh NightVision token for the NIGHTVISION_TOKEN CI variable. tr strips any
# stray whitespace so the value GitLab masks is clean; the guard catches an empty result
# (an exit-0 token create with no output) before it becomes an invalid masked variable.
TOKEN="$(nightvision token create | tr -d '[:space:]')"
if [ -z "$TOKEN" ]; then
    echo "ERROR: 'nightvision token create' returned an empty token; aborting." >&2
    exit 1
fi

# Set the masked CI variable to the freshly created token (rotated every run, not reused,
# because a token's value cannot be read back). If it already exists (older glab errors
# instead of upserting), update it. This must succeed: failing both set and update aborts
# the script (set -e) rather than silently leaving CI a stale token.
glab variable set NIGHTVISION_TOKEN --masked --repo "$GROUP/$REPO" "$TOKEN" \
    || glab variable update NIGHTVISION_TOKEN --masked --repo "$GROUP/$REPO" "$TOKEN"

# ---------------------------------------------------------------------------------------------------------------------
# Note that GitLab has additional requirements vs other CI/CD providers.
# Instead of `localhost` you must use the `docker` hostname.
# First add the docker hostname reference to your `/etc/hosts` file on your laptop.
#
# This edits a system file with sudo. It is left in place after the demo so repeat runs work.
# To revert it afterwards run:
#   sudo sed -i.bak '/^127\.0\.0\.1 docker$/d' /etc/hosts
# ---------------------------------------------------------------------------------------------------------------------
if ! grep -q "127.0.0.1 docker" /etc/hosts; then
    echo "NOTICE: adding '127.0.0.1 docker' to /etc/hosts (sudo). See the revert command in this script's comments."
    echo "127.0.0.1 docker" | sudo tee -a /etc/hosts
fi

# ---------------------------------------------------------------------------------------------------------------------
# NightVision commands
# ---------------------------------------------------------------------------------------------------------------------
# Create app and target. Guarded so a re-run reuses the existing app/target.
URL="https://docker:9000"
APP="javaspringvulny-api-gitlab"
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
# sync it back with GitLab and trigger the CI/CD job.
# ---------------------------------------------------------------------------------------------------------------------
# Point the gitlab remote at the requested project. A reused checkout may carry the
# remote from a previous run with different arguments; reconciling it to the current
# "$GROUP/$REPO" keeps the push from silently targeting the previous run's project.
if git remote get-url gitlab >/dev/null 2>&1; then
    git remote set-url gitlab "git@gitlab.com:$GROUP/$REPO.git"
else
    git remote add gitlab "git@gitlab.com:$GROUP/$REPO.git"
fi
# Add an empty commit so each run pushes a fresh commit and triggers the
# pipeline. A re-run reuses the existing checkout, which has no new commits, so a
# bare push would be "Everything up-to-date" and fire nothing.
git commit --allow-empty -m "Trigger GitLab pipeline"
git push gitlab main

# Notes:
# To delete the project and local checkout (substitute the group and repo you ran this script with):
# glab repo delete <group>/<repo>
# rm -rf ./java-github-actions-demo
# The NightVision app and target are not deleted; they are reused on re-run
# (auth is re-recorded each run, and each run mints a fresh token that persists,
# as noted in the header). Remove the app, target, and stale tokens from the
# NightVision UI for a full teardown.
# To revert the /etc/hosts entry:
# sudo sed -i.bak '/^127\.0\.0\.1 docker$/d' /etc/hosts
