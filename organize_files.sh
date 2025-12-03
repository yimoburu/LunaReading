#!/bin/bash
# Organize debugging scripts and documentation files

echo "📁 Organizing project files..."
echo ""

# Move documentation files (except README.md which stays in root)
echo "Moving documentation files to docs/..."
DOCS=(
    "CHECK_LOGS.md"
    "DEBUG_FRONTEND.md"
    "DEPLOYMENT.md"
    "DEPLOY_WITHOUT_DOCKER.md"
    "DIAGNOSE_502.md"
    "ENABLE_BILLING.md"
    "FINAL_FIX_502.md"
    "FIX_502_COMPLETE.md"
    "FIX_502_ERROR.md"
    "GITHUB_SETUP.md"
    "INSTALL_DOCKER.md"
    "QUICK_FIX_API_KEY.md"
    "QUICK_START_DEPLOY.md"
    "REBUILD_INSTRUCTIONS.md"
    "TEST_BACKEND.md"
    "TROUBLESHOOT_DEPLOYMENT.md"
)

for doc in "${DOCS[@]}"; do
    if [ -f "$doc" ]; then
        mv "$doc" docs/
        echo "  ✅ Moved $doc"
    fi
done

# Move debugging/testing scripts
echo ""
echo "Moving debugging and testing scripts to scripts/..."

# Test scripts
TEST_SCRIPTS=(
    "test_*.py"
    "test_*.sh"
    "check_*.py"
    "check_*.sh"
    "debug_*.sh"
    "verify_*.sh"
)

for pattern in "${TEST_SCRIPTS[@]}"; do
    for file in $pattern; do
        if [ -f "$file" ] && [ "$file" != "setup.sh" ]; then
            mv "$file" scripts/
            echo "  ✅ Moved $file"
        fi
    done
done

# Fix scripts (debugging/fixing)
echo ""
echo "Moving fix scripts to scripts/..."
FIX_SCRIPTS=(
    "fix_*.sh"
    "quick_fix_502.sh"
    "comprehensive_fix_502.sh"
)

for pattern in "${FIX_SCRIPTS[@]}"; do
    for file in $pattern; do
        if [ -f "$file" ]; then
            mv "$file" scripts/
            echo "  ✅ Moved $file"
        fi
    done
done

# Utility scripts (debugging/admin)
echo ""
echo "Moving utility scripts to scripts/..."
UTILITY_SCRIPTS=(
    "migrate_database.py"
    "check_api_key.py"
    "check_users.py"
    "reset_password.py"
    "test_admin_endpoint.py"
)

for script in "${UTILITY_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        mv "$script" scripts/
        echo "  ✅ Moved $script"
    fi
done

# Rebuild scripts (some are debugging-related)
echo ""
echo "Moving rebuild scripts to scripts/..."
REBUILD_SCRIPTS=(
    "rebuild_and_fix.sh"
)

for script in "${REBUILD_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        mv "$script" scripts/
        echo "  ✅ Moved $script"
    fi
done

echo ""
echo "✅ Organization complete!"
echo ""
echo "📁 Structure:"
echo "  docs/     - Documentation files"
echo "  scripts/  - Debugging, testing, and utility scripts"
echo ""
echo "📝 Files kept in root (deployment/setup):"
echo "  - setup.sh"
echo "  - deploy.sh, deploy-no-docker.sh"
echo "  - rebuild_all.sh, rebuild_frontend_only.sh, rebuild-frontend.sh"
echo "  - set_api_key.sh, setup_api_key.sh, setup_github.sh"
echo "  - restart_backend.sh, get_urls.sh"
echo "  - docker-entrypoint.sh"
echo "  - README.md"

