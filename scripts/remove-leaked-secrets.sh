#!/bin/bash
# Remove temp_secrets.yml from git history
# This file was accidentally committed with plaintext Njalla API token

set -euo pipefail

echo "🔒 Git History Secrets Removal Script"
echo "======================================"
echo ""
echo "⚠️  WARNING: This will rewrite git history!"
echo "   All commit hashes will change."
echo "   If you've pushed to a remote, you'll need to force push."
echo ""

# Check if repo is clean
if [[ -n $(git status --porcelain) ]]; then
    echo "❌ Error: You have uncommitted changes"
    echo "   Please commit or stash your changes first"
    git status --short
    exit 1
fi

# Show what we're about to remove
echo "📋 Files to remove from history:"
echo "   - temp_secrets.yml (contains plaintext Njalla API token)"
echo ""

# Show commits that touched this file
echo "📜 Commits that will be rewritten:"
git log --oneline --all -- "temp_secrets.yml" | head -10
echo ""

read -p "❓ Continue with history rewrite? (type 'yes' to confirm): " -r
if [[ "$REPLY" != "yes" ]]; then
    echo "⏭️  Aborted"
    exit 0
fi

echo ""
echo "🔄 Step 1: Creating backup..."
BACKUP_BRANCH="backup-before-secrets-removal-$(date +%Y%m%d-%H%M%S)"
git branch "$BACKUP_BRANCH"
echo "✅ Backup branch created: $BACKUP_BRANCH"

echo ""
echo "🔄 Step 2: Removing temp_secrets.yml from all history..."
echo "   This may take a minute..."

# Use git filter-repo (preferred) or filter-branch (fallback)
if command -v git-filter-repo &> /dev/null; then
    echo "   Using git-filter-repo (recommended method)"
    git filter-repo --path temp_secrets.yml --invert-paths --force
else
    echo "   Using git filter-branch (slower method)"
    git filter-branch --force --index-filter \
        "git rm --cached --ignore-unmatch temp_secrets.yml" \
        --prune-empty --tag-name-filter cat -- --all
fi

echo ""
echo "✅ temp_secrets.yml removed from all history!"

echo ""
echo "🔄 Step 3: Cleaning up..."
# Clean up backup refs
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo ""
echo "✅ Git history cleanup complete!"
echo ""

echo "📋 Next steps:"
echo ""
echo "1. ⚠️  VERIFY the token is gone:"
echo "   git log --all --full-history -p -- temp_secrets.yml"
echo "   (should show nothing)"
echo ""
echo "2. 🔐 REVOKE the exposed Njalla API token:"
echo "   - Login to https://njal.la/"
echo "   - Go to API settings"
echo "   - Delete token: da58004eb272f4ab236881b327d7b2ec33bdce9c"
echo "   - Generate NEW token"
echo ""
echo "3. 📝 UPDATE terraform_secrets.yml with new token:"
echo "   sops terraform_secrets.yml"
echo ""
echo "4. 🚀 FORCE PUSH to remote (if applicable):"
echo "   git push origin --force --all"
echo "   git push origin --force --tags"
echo ""
echo "5. 🗑️  DELETE backup branch (once verified):"
echo "   git branch -D $BACKUP_BRANCH"
echo ""
echo "⚠️  WARNING: Anyone who has cloned this repo should re-clone"
echo "   after you force push, as their history is now invalid."
