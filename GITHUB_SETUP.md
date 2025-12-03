# How to Push to GitHub

## Step 1: Initialize Git Repository

If you haven't initialized git yet, run:

```bash
cd /Users/xiaoweili/LunaReading
git init
```

## Step 2: Add All Files

Add all files to git (`.env` and other sensitive files are already in `.gitignore`):

```bash
git add .
```

## Step 3: Make Initial Commit

```bash
git commit -m "Initial commit: LunaReading - Reading comprehension practice platform"
```

## Step 4: Create GitHub Repository

1. Go to [GitHub](https://github.com) and sign in
2. Click the **+** icon in the top right → **New repository**
3. Name it (e.g., `LunaReading`)
4. Choose **Public** or **Private**
5. **DO NOT** initialize with README, .gitignore, or license (we already have these)
6. Click **Create repository**

## Step 5: Connect Local Repository to GitHub

After creating the repository, GitHub will show you commands. Use these:

```bash
# Add the remote repository (replace YOUR_USERNAME and REPO_NAME)
git remote add origin https://github.com/YOUR_USERNAME/REPO_NAME.git

# Or if you prefer SSH:
# git remote add origin git@github.com:YOUR_USERNAME/REPO_NAME.git
```

## Step 6: Push to GitHub

```bash
# Push to main branch
git branch -M main
git push -u origin main
```

## Quick Setup Script

You can also use the provided script:

```bash
./setup_github.sh YOUR_USERNAME REPO_NAME
```

## Important Notes

### ✅ Files Already Ignored (won't be pushed):
- `.env` - Contains your API keys (sensitive!)
- `*.db` - Database files
- `node_modules/` - Node dependencies
- `.venv/` - Python virtual environment
- `__pycache__/` - Python cache files

### ⚠️ Before Pushing:

1. **Check what will be committed:**
   ```bash
   git status
   ```

2. **Verify .env is ignored:**
   ```bash
   git check-ignore .env
   ```
   Should output: `.env`

3. **Review sensitive files:**
   ```bash
   git status --ignored
   ```

### 🔒 Security Checklist:

- [ ] `.env` is in `.gitignore` ✅
- [ ] No API keys in code files
- [ ] No database files committed
- [ ] No passwords in code

## Common Commands

```bash
# Check status
git status

# See what files are staged
git diff --cached

# Add specific file
git add filename

# Commit changes
git commit -m "Description of changes"

# Push to GitHub
git push

# Pull latest changes
git pull

# View commit history
git log --oneline
```

## Troubleshooting

### If you get "remote origin already exists":
```bash
git remote remove origin
git remote add origin https://github.com/YOUR_USERNAME/REPO_NAME.git
```

### If you need to update .gitignore after committing:
```bash
# Remove files from git cache (but keep them locally)
git rm -r --cached .
git add .
git commit -m "Update .gitignore"
```

### If you accidentally committed .env:
```bash
# Remove from git history (be careful!)
git rm --cached .env
git commit -m "Remove .env from repository"
git push
```

