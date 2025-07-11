# Daily Useful Git Commands

Below are some commonly used Git commands with comments explaining their purpose:

```sh
# Clone a repository
 git clone <repository_url>

# Check the status of your working directory
 git status

# Add all changes to the staging area
 git add .

# Add a specific file to the staging area
 git add <file_name>

# Commit staged changes with a message
 git commit -m "Your commit message"

# View commit history
 git log

# Push local commits to the remote repository
 git push

# Pull the latest changes from the remote repository
 git pull

# Create a new branch
 git branch <branch_name>

# Switch to a branch
 git checkout <branch_name>

# Create and switch to a new branch
 git checkout -b <branch_name>

# Merge a branch into the current branch
 git merge <branch_name>

# Delete a branch locally
 git branch -d <branch_name>

# Show changes between commits, branches, etc.
 git diff

# Stash uncommitted changes
 git stash

# Apply stashed changes
 git stash apply

# Remove a file from the staging area (unstage)
 git reset <file_name>

# Discard changes in a file (restore to last commit)
 git checkout -- <file_name>
``` 