#!/bin/sh -l

set -e  # if a command fails it stops the execution
set -u  # script fails if trying to access to an undefined variable

echo "Starts"
SOURCE_DIRECTORY="$1"
DESTINATION_GITHUB_USERNAME="$2"
DESTINATION_REPOSITORY_NAME="$3"
USER_EMAIL="$4"
DESTINATION_REPOSITORY_USERNAME="$5"
TARGET_BRANCH="$6"
COMMIT_MESSAGE="$7"
COMMIT_TAG="$8"

if [ -z "$DESTINATION_REPOSITORY_USERNAME" ]
then
  DESTINATION_REPOSITORY_USERNAME="$DESTINATION_GITHUB_USERNAME"
fi

CLONE_DIR=$(mktemp -d)

# Set SSH key
echo "Setting SSH deploymeny key"
touch git.key
echo "$SSH_DEPLOYMENT_KEY" > git.key
chmod 600 git.key

echo "Cloning destination git repository"
# Setup git
git config --global core.sshCommand "ssh -i git.key"
git config --global user.email "$USER_EMAIL"
git config --global user.name "$DESTINATION_GITHUB_USERNAME"
git clone --single-branch --branch "$TARGET_BRANCH" "git@github.com:$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git" "$CLONE_DIR"
ls -la "$CLONE_DIR"

TARGET_DIR=$(mktemp -d)
mv "$CLONE_DIR/.git" "$TARGET_DIR"
# move .github related data if it exists
if [ -d "$CLONE_DIR/.github" ]; then
  mv "$CLONE_DIR/.github" "$TARGET_DIR"
fi

echo "Copying contents to git repo"
cp -ra "$SOURCE_DIRECTORY"/. "$TARGET_DIR"
cd "$TARGET_DIR"

echo "Files that will be pushed"
ls -la

echo "Adding git commit"

ORIGIN_COMMIT="https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
COMMIT_MESSAGE="${COMMIT_MESSAGE/ORIGIN_COMMIT/$ORIGIN_COMMIT}"

git add .
git status

# git diff-index : to avoid doing the git commit failing if there are no changes to be commit
git diff-index --quiet HEAD || git commit --message "$COMMIT_MESSAGE"

echo "Pushing git commit"
# --set-upstream: sets the branch when pushing to a branch that does not exist
git push origin --set-upstream "$TARGET_BRANCH"

# tag the commit
if [ ! -z "$COMMIT_TAG" ]
then
  echo "Tagging the commit"
  git tag "$COMMIT_TAG"
  git push origin --tags
fi
