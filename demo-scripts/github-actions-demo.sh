#!/bin/bash
set -e

# Clone the repository locally from your terminal
git clone https://github.com/$(git config user.name)/java-github-actions-demo.git
cd java-github-actions-demo

# add the nightvision token as the github action secret NIGHTVISION_TOKEN
nightvision login
nightvision token create > token

# Check if GitHub CLI is authenticated
if ! gh auth status 2>&1 | grep -q 'Logged in to github.com'; then
    echo "GitHub CLI not authenticated. Running 'gh auth login'..."
    gh auth login
else
    echo "Logged in to github already..."
fi

# Use GitHub CLI to set NIGHTVISION_TOKEN
gh secret set NIGHTVISION_TOKEN < token
rm token

# Create app and target
# Username: user
# Password: password
URL="https://localhost:9000"
APP="javaspringvulny-api"
nightvision app create $APP
nightvision target create $APP $URL --type API
# Start the application
docker compose up -d; sleep 10
# Record authentication - click on Form Auth
echo "Click on Form Auth and use these credentials: "
echo "\tUsername: user"
echo "\tPassword: password"
nightvision auth playwright create $APP $URL

# Add a commit and trigger the CI/CD
echo "foobar" >> README.md
git commit -am 'trigger a github action'
git push
