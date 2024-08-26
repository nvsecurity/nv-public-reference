#!/usr/bin/env bash
set -e

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "This script will create a repository on GitLab. Please provide the group/project and repository name that you want to create."
    echo "Usage: $0 group repo"
    exit 1
fi

# Assign positional arguments to variables
GROUP=$1
REPO=$2

echo "Creating a repository under: $GROUP/$REPO"

# Clone the GitHub repository that we will mirror to GitLab
git clone https://github.com/nvsecurity/java-github-actions-demo
cd java-github-actions-demo

# ---------------------------------------------------------------------------------------------------------------------
# Set up the GitLab repository
# ---------------------------------------------------------------------------------------------------------------------
# Create a repository
echo "NOTE: Select NO for 'Create a local project directory'"
glab repo create $REPO

# add the nightvision token as the GitLab secret NIGHTVISION_TOKEN
nightvision login
TOKEN=$(nightvision token create)

# Check if GitLab CLI is authenticated
if ! glab auth status 2>&1 | grep -q 'Logged in to gitlab.com'; then
    echo "GitLab CLI not authenticated. Running 'glab auth login'..."
    glab auth login
else
    echo "Logged in to gitlab already..."
fi

glab variable set NIGHTVISION_TOKEN --masked --repo $GROUP/$REPO $TOKEN < token

# ---------------------------------------------------------------------------------------------------------------------
# Note that GitLab has additional requirements vs other CI/CD providers.
# Instead of `localhost` you must use the `docker` hostname.
# First add the docker hostname reference to your `/etc/hosts` file on your laptop
# ---------------------------------------------------------------------------------------------------------------------
if ! grep -q "127.0.0.1 docker" /etc/hosts; then \
    echo "127.0.0.1 docker" | sudo tee -a /etc/hosts; \
fi
# ---------------------------------------------------------------------------------------------------------------------
# NightVision commands
# ---------------------------------------------------------------------------------------------------------------------
# Create app and target
# Username: user
# Password: password
URL="https://docker:9000"
APP="javaspringvulny-api-gitlab"
nightvision app create $APP
nightvision target create $APP https://docker:9000 --type api

# Start the application
docker compose up -d; sleep 10
# Record authentication - click on Form Auth
echo "Click on Form Auth and use these credentials: "
echo "\tUsername: user"
echo "\tPassword: password"
nightvision auth playwright create $APP $URL

# ---------------------------------------------------------------------------------------------------------------------
# sync it back with GitLab and trigger the CI/CD job.
# ---------------------------------------------------------------------------------------------------------------------
git remote add gitlab git@gitlab.com:$GROUP/$REPO.git
git push gitlab main

# Notes:
# To delete the project:
# glab repo delete $GROUP/$REPO
# rm -rf ./java-github-actions-demo
