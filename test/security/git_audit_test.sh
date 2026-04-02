#!/bin/bash
# Security Audit Script for Git History
# 
# This script verifies:
# - No .env files in git history
# - No config.js files committed
# - No secrets in tracked files
# - .gitignore coverage is complete
#
# Usage: ./test/security/git_audit_test.sh
# Exit codes:
#   0 - All checks passed
#   1 - Security violations found

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           Security Audit: Git History Check               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

cd "$PROJECT_ROOT"

# Test 1: Check for .env files in current working tree
echo "📋 Test 1: Checking for .env files in working tree..."
# Exclude .env.example and .env.*.example files (these are templates)
ENV_FILES=$(git ls-files --others --exclude-standard | grep -E "^\.env$|^\.env\." | grep -v "\.example$" || true)
if [ -n "$ENV_FILES" ]; then
    echo -e "${RED}❌ FAIL${NC}: Found .env files in working tree (not gitignored):"
    echo "$ENV_FILES"
    ((FAIL_COUNT++))
elif [ -f ".env" ]; then
    # Check if .env is properly gitignored
    if git check-ignore -q .env; then
        echo -e "${GREEN}✅ PASS${NC}: .env file exists but is properly gitignored"
        ((PASS_COUNT++))
    else
        echo -e "${RED}❌ FAIL${NC}: .env file exists and is NOT gitignored!"
        ((FAIL_COUNT++))
    fi
else
    echo -e "${GREEN}✅ PASS${NC}: No sensitive .env files in working tree"
    ((PASS_COUNT++))
fi
echo ""

# Test 2: Check for .env files in git history
echo "📋 Test 2: Checking for .env files in git history..."
ENV_HISTORY=$(git log --all --full-history --name-only --pretty=format: -- '*.env' '*.env.*' 2>/dev/null | grep -E "^\.env$|^\.env\." | head -20 || true)
if [ -n "$ENV_HISTORY" ]; then
    echo -e "${YELLOW}⚠️  WARNING${NC}: Found .env files in git history:"
    echo "$ENV_HISTORY" | sort -u
    echo ""
    echo "   This may indicate accidental commits. Consider:"
    echo "   - Running git filter-branch or BFG Repo-Cleaner"
    echo "   - Rotating any exposed credentials"
    ((WARN_COUNT++))
else
    echo -e "${GREEN}✅ PASS${NC}: No .env files in git history"
    ((PASS_COUNT++))
fi
echo ""

# Test 3: Check for config.js files in current working tree
echo "📋 Test 3: Checking for config.js in working tree..."
if [ -f "web/config.js" ]; then
    echo -e "${YELLOW}⚠️  WARNING${NC}: web/config.js exists (should be generated, not tracked)"
    if git ls-files web/config.js | grep -q "web/config.js"; then
        echo -e "${RED}❌ FAIL${NC}: web/config.js is tracked in git!"
        ((FAIL_COUNT++))
    else
        echo -e "${GREEN}✅ PASS${NC}: web/config.js is NOT tracked in git"
        ((PASS_COUNT++))
    fi
else
    echo -e "${GREEN}✅ PASS${NC}: web/config.js does not exist (will be generated at build/deploy)"
    ((PASS_COUNT++))
fi
echo ""

# Test 4: Check for config.js files in git history
echo "📋 Test 4: Checking for config.js in git history..."
CONFIGJS_HISTORY=$(git log --all --full-history --name-only --pretty=format: -- 'web/config.js' '*/config.js' 2>/dev/null | grep -E "config\.js$" | head -20 || true)
if [ -n "$CONFIGJS_HISTORY" ]; then
    echo -e "${YELLOW}⚠️  WARNING${NC}: Found config.js references in git history:"
    echo "$CONFIGJS_HISTORY" | sort -u
    echo ""
    echo "   If these contained secrets, consider:"
    echo "   - Running git filter-branch or BFG Repo-Cleaner"
    echo "   - Rotating any exposed credentials"
    ((WARN_COUNT++))
else
    echo -e "${GREEN}✅ PASS${NC}: No config.js files in git history"
    ((PASS_COUNT++))
fi
echo ""

# Test 5: Check .gitignore coverage for sensitive files
echo "📋 Test 5: Verifying .gitignore coverage..."
GITIGNORE_MISSING=0

# Check if .env is in .gitignore
if [ -f ".gitignore" ]; then
    if ! grep -q "^\.env$" .gitignore && ! grep -q "^\.env/" .gitignore; then
        echo -e "${RED}❌ FAIL${NC}: .env is not explicitly in .gitignore"
        GITIGNORE_MISSING=1
    fi
    
    # Check if web/config.js is in .gitignore
    if ! grep -q "web/config.js" .gitignore && ! grep -q "config.js" .gitignore; then
        echo -e "${RED}❌ FAIL${NC}: web/config.js is not explicitly in .gitignore"
        GITIGNORE_MISSING=1
    fi
    
    # Check if assets/env.json is in .gitignore
    if ! grep -q "assets/env.json" .gitignore && ! grep -q "env.json" .gitignore; then
        echo -e "${YELLOW}⚠️  WARNING${NC}: assets/env.json may not be in .gitignore"
        ((WARN_COUNT++))
    fi
    
    if [ $GITIGNORE_MISSING -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}: .gitignore has proper coverage for sensitive files"
        ((PASS_COUNT++))
    else
        ((FAIL_COUNT++))
    fi
else
    echo -e "${RED}❌ FAIL${NC}: .gitignore file not found!"
    ((FAIL_COUNT++))
fi
echo ""

# Test 6: Check for common secret patterns in tracked files
echo "📋 Test 6: Scanning for potential secrets in tracked files..."
SECRET_PATTERNS_FOUND=0

# Patterns to search (excluding test/example/template files and legitimate Firebase config)
PATTERNS=(
    "AIzaSy[A-Za-z0-9_-]{33}"  # Firebase API key pattern
    "sk-[A-Za-z0-9]{48}"       # Generic secret key pattern
    "ghp_[A-Za-z0-9]{36}"      # GitHub personal access token
)

for pattern in "${PATTERNS[@]}"; do
    # Search in tracked files, excluding:
    # - test/example/template files
    # - Firebase config files (google-services.json, GoogleService-Info.plist)
    # - docs build artifacts and compiled JS
    # - node_modules
    MATCHES=$(git grep -E "$pattern" -- \
        ':!*.example' \
        ':!*.template' \
        ':!test/**' \
        ':!*.md' \
        ':!**/google-services.json' \
        ':!**/GoogleService-Info.plist' \
        ':!**/main.dart.js' \
        ':!**/docs_build/**' \
        ':!**/docs/**' \
        ':!**/node_modules/**' \
        ':!**/build/**' \
        2>/dev/null || true)
    if [ -n "$MATCHES" ]; then
        echo -e "${YELLOW}⚠️  WARNING${NC}: Potential secret pattern found:"
        echo "$MATCHES" | head -5
        SECRET_PATTERNS_FOUND=1
    fi
done

if [ $SECRET_PATTERNS_FOUND -eq 0 ]; then
    echo -e "${GREEN}✅ PASS${NC}: No obvious secret patterns in tracked files"
    ((PASS_COUNT++))
else
    echo -e "${YELLOW}⚠️  WARNING${NC}: Review potential secrets above"
    ((WARN_COUNT++))
fi
echo ""

# Test 7: Verify .env.example exists (best practice)
echo "📋 Test 7: Checking for .env.example template..."
if [ -f ".env.example" ]; then
    echo -e "${GREEN}✅ PASS${NC}: .env.example template exists"
    ((PASS_COUNT++))
else
    echo -e "${YELLOW}⚠️  WARNING${NC}: .env.example not found (recommended for documentation)"
    ((WARN_COUNT++))
fi
echo ""

# Test 8: Verify config.js.template exists (best practice)
echo "📋 Test 8: Checking for web/config.js.template..."
if [ -f "web/config.js.template" ]; then
    echo -e "${GREEN}✅ PASS${NC}: web/config.js.template exists"
    ((PASS_COUNT++))
else
    echo -e "${YELLOW}⚠️  WARNING${NC}: web/config.js.template not found (recommended for documentation)"
    ((WARN_COUNT++))
fi
echo ""

# Summary
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                    Audit Summary                          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo -e "Passed:   ${GREEN}$PASS_COUNT${NC}"
echo -e "Failed:   ${RED}$FAIL_COUNT${NC}"
echo -e "Warnings: ${YELLOW}$WARN_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}❌ SECURITY AUDIT FAILED${NC}"
    echo ""
    echo "Critical issues must be resolved before deployment."
    echo "Review the failures above and ensure no secrets are exposed."
    exit 1
elif [ $WARN_COUNT -gt 0 ]; then
    echo -e "${YELLOW}⚠️  SECURITY AUDIT PASSED WITH WARNINGS${NC}"
    echo ""
    echo "No critical issues found, but warnings should be reviewed."
    exit 0
else
    echo -e "${GREEN}✅ SECURITY AUDIT PASSED${NC}"
    echo ""
    echo "All security checks passed. Repository is clean."
    exit 0
fi
