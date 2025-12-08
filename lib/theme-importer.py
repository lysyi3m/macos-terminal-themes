#!/usr/bin/env python3
"""
macOS Terminal Theme Importer
Imports .terminal files directly to ~/Library/Preferences/com.apple.Terminal.plist
without opening new Terminal windows.
"""

import plistlib
import sys
import os
from pathlib import Path


def get_terminal_plist_path():
    """Get the path to Terminal.app preferences plist"""
    home = Path.home()
    return home / "Library" / "Preferences" / "com.apple.Terminal.plist"


def get_installed_themes():
    """Get list of already installed theme names"""
    plist_path = get_terminal_plist_path()

    if not plist_path.exists():
        return set()

    try:
        with open(plist_path, 'rb') as f:
            prefs = plistlib.load(f)

        window_settings = prefs.get('Window Settings', {})
        return set(window_settings.keys())
    except Exception as e:
        print(f"Warning: Could not read Terminal preferences: {e}", file=sys.stderr)
        return set()


def import_theme(theme_path):
    """
    Import a single .terminal file into Terminal.app preferences

    Args:
        theme_path: Path to .terminal file

    Returns:
        tuple: (success: bool, theme_name: str, message: str)
    """
    theme_path = Path(theme_path)

    if not theme_path.exists():
        return False, None, f"Theme file not found: {theme_path}"

    try:
        # Read the .terminal file
        with open(theme_path, 'rb') as f:
            theme_data = plistlib.load(f)

        # Get theme name
        theme_name = theme_data.get('name')
        if not theme_name:
            return False, None, "Theme file has no 'name' field"

        # Read Terminal preferences
        plist_path = get_terminal_plist_path()

        if plist_path.exists():
            with open(plist_path, 'rb') as f:
                terminal_prefs = plistlib.load(f)
        else:
            # Create new preferences if they don't exist
            terminal_prefs = {}

        # Ensure Window Settings exists
        if 'Window Settings' not in terminal_prefs:
            terminal_prefs['Window Settings'] = {}

        # Check if theme already exists
        if theme_name in terminal_prefs['Window Settings']:
            return False, theme_name, "Already installed"

        # Add theme to Window Settings
        terminal_prefs['Window Settings'][theme_name] = theme_data

        # Write back to plist
        with open(plist_path, 'wb') as f:
            plistlib.dump(terminal_prefs, f)

        return True, theme_name, "Successfully imported"

    except Exception as e:
        return False, None, f"Error: {str(e)}"


def main():
    if len(sys.argv) < 2:
        print("Usage: theme-importer.py <theme_file.terminal> [theme_file2.terminal ...]", file=sys.stderr)
        sys.exit(1)

    theme_files = sys.argv[1:]

    imported = 0
    skipped = 0
    failed = 0

    for theme_file in theme_files:
        success, theme_name, message = import_theme(theme_file)

        if success:
            imported += 1
            print(f"✓ {theme_name}")
        elif "Already installed" in message:
            skipped += 1
            print(f"⊘ {theme_name} (already installed)")
        else:
            failed += 1
            print(f"✗ {theme_file}: {message}", file=sys.stderr)

    # Exit with appropriate status code
    if failed > 0:
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
