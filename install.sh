#!/usr/bin/env bash

# macOS Terminal Theme Auto-Installer
# This script automatically imports all terminal themes to macOS Terminal.app

set -e

THEMES_DIR="themes"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script only works on macOS${NC}"
    exit 1
fi

# Check if themes directory exists
if [[ ! -d "$SCRIPT_DIR/$THEMES_DIR" ]]; then
    echo -e "${RED}Error: themes/ directory not found${NC}"
    exit 1
fi

echo -e "${GREEN}macOS Terminal Theme Auto-Installer${NC}"
echo -e "${YELLOW}This will import all themes to Terminal.app${NC}"
echo ""

# Count total themes
THEME_COUNT=$(find "$SCRIPT_DIR/$THEMES_DIR" -name "*.terminal" | wc -l | tr -d ' ')

if [[ $THEME_COUNT -eq 0 ]]; then
    echo -e "${RED}Error: No .terminal files found in themes/ directory${NC}"
    exit 1
fi

echo "Found $THEME_COUNT themes to import"
echo ""

# Ask for confirmation
read -p "Do you want to proceed with importing all themes? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled"
    exit 0
fi

echo ""
echo "Removing quarantine attributes from theme files..."
if xattr -cr "$SCRIPT_DIR/$THEMES_DIR" 2>/dev/null; then
    echo -e "${GREEN}✓ Quarantine attributes removed${NC}"
else
    echo -e "${YELLOW}⚠ Could not remove quarantine attributes (this is okay)${NC}"
fi

echo ""
echo "Importing themes..."
echo ""

# Import each theme
IMPORTED=0
FAILED=0

while IFS= read -r theme; do
    THEME_NAME=$(basename "$theme" .terminal)
    echo -n "Importing: $THEME_NAME... "

    if open "$theme" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((IMPORTED++))
        # Small delay to prevent overwhelming Terminal.app
        sleep 0.3
    else
        echo -e "${RED}✗${NC}"
        ((FAILED++))
    fi
done < <(find "$SCRIPT_DIR/$THEMES_DIR" -name "*.terminal" | sort)

echo ""
echo "─────────────────────────────────────"
echo -e "${GREEN}Successfully imported: $IMPORTED themes${NC}"
if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}Failed to import: $FAILED themes${NC}"
fi
echo "─────────────────────────────────────"
echo ""
echo "You can now:"
echo "1. Open Terminal Preferences (⌘,)"
echo "2. Go to Profiles tab"
echo "3. Select any imported theme"
echo "4. Click 'Default' button to set it as default"
echo ""
