#!/usr/bin/env bash

set -u

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_CONFIG="$HOME/.ssh/config"

# =========================
# COLORS
# =========================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# =========================
# Provider Selection
# =========================
echo "======================================"
echo "Select Git Provider:"
echo "1) GitHub"
echo "2) GitLab"
read -p "Enter choice (1 or 2): " PROVIDER_CHOICE

if [[ "$PROVIDER_CHOICE" == "1" ]]; then
    PROVIDER="github"
elif [[ "$PROVIDER_CHOICE" == "2" ]]; then
    PROVIDER="gitlab"
else
    echo "Invalid choice. Exiting."
    exit 1
fi

# =========================
# Mode Selection
# =========================
echo "======================================"
echo "Select Mode:"
echo "1) Pull all repos"
echo "2) Status summary (MAIN branch only)"
read -p "Enter choice (1-2): " MODE

# =========================
# SSH Identity Selection
# =========================
echo "Searching for $PROVIDER identities..."

mapfile -t HOSTS < <(grep -i "^Host " "$SSH_CONFIG" | grep -i "$PROVIDER" | awk '{print $2}')

if [ ${#HOSTS[@]} -gt 0 ]; then
    echo "Available $PROVIDER Identities:"
    for i in "${!HOSTS[@]}"; do
        echo "$((i+1))) ${HOSTS[$i]}"
    done

    read -p "Select identity (1-${#HOSTS[@]}) or Enter for default: " CHOICE

    if [[ -n "$CHOICE" ]] && [[ "$CHOICE" -ge 1 ]] && [[ "$CHOICE" -le ${#HOSTS[@]} ]]; then
        SELECTED_HOST="${HOSTS[$((CHOICE-1))]}"

        IDENTITY_FILE=$(sed -n "/Host ${SELECTED_HOST}/,/Host /p" "$SSH_CONFIG" \
            | grep -i "IdentityFile" | head -n 1 | awk '{print $2}')

        IDENTITY_FILE="${IDENTITY_FILE/#\~/$HOME}"

        if [ -f "$IDENTITY_FILE" ]; then
            echo -e "${GREEN}✔ Using Identity: $SELECTED_HOST${NC}"
            export GIT_SSH_COMMAND="ssh -i $IDENTITY_FILE -o IdentitiesOnly=yes"
        fi
    fi
fi

# =========================
# PARALLEL SETTINGS
# =========================
MAX_JOBS=5
CURRENT_JOBS=0

# =========================
# TEMP FILES
# =========================
rm -f /tmp/git_status_counts
touch /tmp/git_status_counts

TMP_FILES=()

# =========================
# FUNCTION
# =========================
process_repo() {
    local dir="$1"
    local REPO_NAME="${dir%/}"

    # Safe filename
    local SAFE_NAME
    SAFE_NAME=$(echo "$REPO_NAME" | tr -cd '[:alnum:]')

    local TMP_FILE="/tmp/git_${SAFE_NAME}.out"

    cd "$BASE_DIR/$dir" || return

    if [ ! -d ".git" ]; then
        return
    fi

    MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    [ -z "$MAIN_BRANCH" ] && MAIN_BRANCH="main"

    {
        echo -e "${BLUE}Repo:${NC} $REPO_NAME"

        if [ "$MODE" == "1" ]; then
            if git fetch origin >/dev/null 2>&1 && git pull origin "$MAIN_BRANCH" >/dev/null 2>&1; then
                echo -e "${GREEN}✔ Pulled ($MAIN_BRANCH)${NC}"
            else
                echo -e "${RED}❌ Pull failed${NC}"
            fi
        else
            git fetch origin >/dev/null 2>&1

            LOCAL=$(git rev-parse "$MAIN_BRANCH" 2>/dev/null)
            REMOTE=$(git rev-parse "origin/$MAIN_BRANCH" 2>/dev/null)

            if [ "$LOCAL" = "$REMOTE" ]; then
                echo -e "${GREEN}✔ Up-to-date${NC}"
                echo "UP" >> /tmp/git_status_counts
            else
                echo -e "${YELLOW}⚠ Behind/Diverged${NC}"
                echo "BEHIND" >> /tmp/git_status_counts
            fi

            status=$(git status --short)
            if [ -n "$status" ]; then
                echo -e "${YELLOW}⚠ Uncommitted changes${NC}"
                echo "CHANGED" >> /tmp/git_status_counts
            fi
        fi

        echo "--------------------------------------"
    } > "$TMP_FILE"

    TMP_FILES+=("$TMP_FILE")
}

# =========================
# MAIN LOOP (PARALLEL)
# =========================
cd "$BASE_DIR" || exit 1

echo "======================================"

for dir in */; do
    [ -d "$dir" ] || continue

    process_repo "$dir" &

    ((CURRENT_JOBS++))

    if (( CURRENT_JOBS >= MAX_JOBS )); then
        wait
        CURRENT_JOBS=0
    fi
done

wait

# =========================
# PRINT ORDERED OUTPUT
# =========================
echo "======================================"

for file in /tmp/git_*.out; do
    [ -f "$file" ] && cat "$file"
done

# =========================
# SUMMARY
# =========================
echo "======================================"
echo -e "${BLUE}SUMMARY${NC}"

if [ "$MODE" == "2" ]; then
    UP_TO_DATE=$(grep -c "UP" /tmp/git_status_counts 2>/dev/null)
    BEHIND=$(grep -c "BEHIND" /tmp/git_status_counts 2>/dev/null)
    CHANGED=$(grep -c "CHANGED" /tmp/git_status_counts 2>/dev/null)

    echo -e "${GREEN}Up-to-date: $UP_TO_DATE${NC}"
    echo -e "${YELLOW}Behind/Diverged: $BEHIND${NC}"
    echo -e "${YELLOW}With Changes: $CHANGED${NC}"
fi

echo -e "${BLUE}Done.${NC}"
