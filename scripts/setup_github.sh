#!/bin/bash
# Script to set up and push to GitHub

if [ $# -lt 2 ]; then
    echo "Usage: $0 <github_username> <repository_name>"
    echo ""
    echo "Example: $0 johndoe LunaReading"
    echo ""
    echo "This script will:"
    echo "  1. Initialize git (if not already done)"
    echo "  2. Add all files"
    echo "  3. Make initial commit"
    echo "  4. Connect to GitHub"
    echo "  5. Push to GitHub"
    exit 1
fi

GITHUB_USERNAME=$1
REPO_NAME=$2

echo "🚀 Setting up GitHub repository"
echo "================================="
echo ""
echo "GitHub Username: $GITHUB_USERNAME"
echo "Repository Name: $REPO_NAME"
echo ""

# Check if git is initialized
if [ ! -d .git ]; then
    echo "📦 Initializing git repository..."
    git init
    echo "✅ Git initialized"
else
    echo "✅ Git repository already initialized"
fi

# Check if .env is in .gitignore
if grep -q "^\.env$" .gitignore 2>/dev/null; then
    echo "✅ .env is in .gitignore (safe to commit)"
else
    echo "⚠️  WARNING: .env is not in .gitignore!"
    echo "   Adding .env to .gitignore..."
    echo ".env" >> .gitignore
    echo "✅ Added .env to .gitignore"
fi

# Check what will be committed
echo ""
echo "📋 Files to be committed:"
git status --short | head -20
if [ $(git status --short | wc -l) -gt 20 ]; then
    echo "... and more"
fi

echo ""
read -p "Continue with commit? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Add all files
echo ""
echo "📦 Adding files to git..."
git add .

# Check if .env would be committed (safety check)
if git ls-files | grep -q "^\.env$"; then
    echo "❌ ERROR: .env file is about to be committed!"
    echo "   This contains sensitive API keys. Aborting."
    echo ""
    echo "To fix:"
    echo "  1. Make sure .env is in .gitignore"
    echo "  2. Run: git rm --cached .env"
    echo "  3. Try again"
    exit 1
fi

# Make initial commit
echo ""
echo "💾 Making initial commit..."
if git commit -m "Initial commit: LunaReading - Reading comprehension practice platform"; then
    echo "✅ Initial commit created"
else
    echo "⚠️  No changes to commit (or commit failed)"
fi

# Check if remote already exists
if git remote get-url origin &>/dev/null; then
    echo ""
    echo "⚠️  Remote 'origin' already exists:"
    git remote get-url origin
    read -p "Replace it? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git remote remove origin
    else
        echo "Keeping existing remote. You can push with: git push -u origin main"
        exit 0
    fi
fi

# Add remote
echo ""
echo "🔗 Connecting to GitHub..."
git remote add origin https://github.com/$GITHUB_USERNAME/$REPO_NAME.git
echo "✅ Remote added: https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"

# Set branch to main
git branch -M main

# Push
echo ""
echo "📤 Pushing to GitHub..."
echo ""
echo "⚠️  Make sure you've created the repository on GitHub first!"
echo "   Go to: https://github.com/new"
echo "   Repository name: $REPO_NAME"
echo "   DO NOT initialize with README, .gitignore, or license"
echo ""
read -p "Have you created the repository? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "📝 Next steps:"
    echo "  1. Create repository at: https://github.com/new"
    echo "  2. Name it: $REPO_NAME"
    echo "  3. Run: git push -u origin main"
    exit 0
fi

# Push to GitHub
if git push -u origin main; then
    echo ""
    echo "✅ Successfully pushed to GitHub!"
    echo ""
    echo "🌐 View your repository at:"
    echo "   https://github.com/$GITHUB_USERNAME/$REPO_NAME"
else
    echo ""
    echo "❌ Push failed. Common issues:"
    echo "  1. Repository doesn't exist on GitHub"
    echo "  2. Authentication required (use GitHub CLI or SSH keys)"
    echo "  3. Network issues"
    echo ""
    echo "Try manually:"
    echo "  git push -u origin main"
fi

