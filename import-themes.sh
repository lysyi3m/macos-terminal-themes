#!/usr/bin/env bash

# macOS Terminal Theme Importer
# Imports terminal themes directly to Terminal.app preferences without opening windows
# Automatically skips already imported themes

set -e

THEMES_DIR="themes"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMPORTER="$SCRIPT_DIR/lib/theme-importer.py"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script only works on macOS${NC}"
    exit 1
fi

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is required but not found${NC}"
    echo "Python 3 should be pre-installed on macOS 10.15+ (Catalina and newer)"
    exit 1
fi

# Check if themes directory exists
if [[ ! -d "$SCRIPT_DIR/$THEMES_DIR" ]]; then
    echo -e "${RED}Error: themes/ directory not found${NC}"
    exit 1
fi

# Check if Python importer exists
if [[ ! -f "$IMPORTER" ]]; then
    echo -e "${RED}Error: Python importer not found at $IMPORTER${NC}"
    exit 1
fi

echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}  macOS Terminal Theme Importer${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}This will import all themes to Terminal.app${NC}"
echo -e "${BLUE}Already imported themes will be skipped${NC}"
echo ""

# Count total themes
THEME_COUNT=$(find "$SCRIPT_DIR/$THEMES_DIR" -name "*.terminal" | wc -l | tr -d ' ')

if [[ $THEME_COUNT -eq 0 ]]; then
    echo -e "${RED}Error: No .terminal files found in themes/ directory${NC}"
    exit 1
fi

echo "Found $THEME_COUNT themes"
echo ""

# Ask for confirmation
read -p "Do you want to proceed with importing? (y/n) " -n 1 -r
echo
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Import cancelled"
    exit 0
fi

# Remove quarantine attributes
echo -e "${YELLOW}Removing quarantine attributes...${NC}"
if xattr -cr "$SCRIPT_DIR/$THEMES_DIR" 2>/dev/null; then
    echo -e "${GREEN}✓ Quarantine attributes removed${NC}"
else
    echo -e "${YELLOW}⚠ Could not remove quarantine attributes (this is okay)${NC}"
fi
echo ""

# Import themes
echo -e "${YELLOW}Importing themes (this may take a moment)...${NC}"
echo ""

IMPORTED=0
SKIPPED=0
FAILED=0

# Collect all theme files
THEME_FILES=()
while IFS= read -r theme; do
    THEME_FILES+=("$theme")
done < <(find "$SCRIPT_DIR/$THEMES_DIR" -name "*.terminal" | sort)

# Process themes in batches for better performance
BATCH_SIZE=10
TOTAL=${#THEME_FILES[@]}
PROCESSED=0

for ((i=0; i<$TOTAL; i+=$BATCH_SIZE)); do
    # Get batch of themes
    BATCH=("${THEME_FILES[@]:$i:$BATCH_SIZE}")

    # Call Python importer with batch
    OUTPUT=$(python3 "$IMPORTER" "${BATCH[@]}" 2>&1)

    # Parse output
    while IFS= read -r line; do
        if [[ $line =~ ^✓ ]]; then
            echo -e "${GREEN}$line${NC}"
            ((IMPORTED++))
        elif [[ $line =~ ^⊘ ]]; then
            echo -e "${YELLOW}$line${NC}"
            ((SKIPPED++))
        elif [[ $line =~ ^✗ ]]; then
            echo -e "${RED}$line${NC}"
            ((FAILED++))
        fi
    done <<< "$OUTPUT"

    ((PROCESSED+=$BATCH_SIZE))
    if [[ $PROCESSED -lt $TOTAL ]]; then
        REMAINING=$((TOTAL - PROCESSED))
        if [[ $REMAINING -lt $BATCH_SIZE ]]; then
            REMAINING=$REMAINING
        fi
    fi
done

echo ""
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}Import Summary${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Successfully imported: $IMPORTED themes${NC}"
echo -e "${YELLOW}⊘ Already installed:     $SKIPPED themes${NC}"
if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}✗ Failed:                $FAILED themes${NC}"
fi
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""

if [[ $IMPORTED -gt 0 ]]; then
    echo -e "${BLUE}To use imported themes:${NC}"
    echo "1. Open Terminal Preferences (⌘,)"
    echo "2. Go to Profiles tab"
    echo "3. Select any imported theme"
    echo "4. Click 'Default' button to set it as default"
    echo ""
    echo -e "${YELLOW}Note: You may need to restart Terminal.app to see all themes${NC}"
    echo ""
fi

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
