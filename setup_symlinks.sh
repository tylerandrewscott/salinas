#!/usr/bin/env bash
#
# setup_symlinks.sh
#
# Creates a symlink from this repo to the Box-synced salinasbox folder.
# Run once after cloning (or whenever the symlink needs to be recreated).
#
# Usage:
#   bash setup_symlinks.sh
#   bash setup_symlinks.sh /path/to/box/salinasbox   # override auto-detection
#

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Detect or accept the Box salinasbox root --------------------------------

if [[ -n "${1:-}" ]]; then
    BOX_SALINAS="$1"
else
    # Try common Box mount names on macOS
    BOX_BASE="$HOME/Library/CloudStorage"
    if [[ -d "$BOX_BASE/Box-Box/salinasbox" ]]; then
        BOX_SALINAS="$BOX_BASE/Box-Box/salinasbox"
    elif [[ -d "$BOX_BASE/Box/salinasbox" ]]; then
        BOX_SALINAS="$BOX_BASE/Box/salinasbox"
    elif [[ -d "$HOME/Box/salinasbox" ]]; then
        BOX_SALINAS="$HOME/Box/salinasbox"
    else
        echo "ERROR: Could not find salinasbox in Box."
        echo "Searched:"
        echo "  $BOX_BASE/Box-Box/salinasbox"
        echo "  $BOX_BASE/Box/salinasbox"
        echo "  $HOME/Box/salinasbox"
        echo ""
        echo "Re-run with an explicit path:"
        echo "  bash setup_symlinks.sh /path/to/box/salinasbox"
        exit 1
    fi
fi

echo "Using Box salinasbox at: $BOX_SALINAS"

# --- Create symlink -----------------------------------------------------------

LINK_PATH="$REPO_DIR/salinasbox"

# Remove existing symlink or warn if something else is in the way
if [[ -L "$LINK_PATH" ]]; then
    rm "$LINK_PATH"
elif [[ -e "$LINK_PATH" ]]; then
    echo "WARNING: $LINK_PATH exists and is not a symlink — skipping."
    exit 1
fi

if [[ -d "$BOX_SALINAS" ]]; then
    ln -s "$BOX_SALINAS" "$LINK_PATH"
    echo "  OK  $LINK_PATH -> $BOX_SALINAS"
else
    echo "  MISSING  $BOX_SALINAS  (symlink not created)"
    exit 1
fi

echo ""
echo "Done. Symlink created."
