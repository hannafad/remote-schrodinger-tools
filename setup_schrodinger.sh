#!/bin/bash

# Schrodinger environment setup script
# Sets up environment variables and displays current job status
#
# IMPORTANT: This script must be SOURCED, not executed!
# Run with: source setup_schrodinger.sh
# OR:       . setup_schrodinger.sh
# 
# Do NOT run with: ./setup_schrodinger.sh (this won't set environment variables)

# =============================================================================
# CONFIGURATION LOADING
# =============================================================================

CONFIG_FILE="$HOME/config.json"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ ERROR: Configuration file not found: $CONFIG_FILE"
    echo ""
    echo "Please create a configuration file by copying the example:"
    echo "  cp config.json.example ~/config.json"
    echo ""
    echo "Then edit ~/config.json with your server's settings."
    echo "See README.md for detailed setup instructions."
    return 1
fi

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
    echo "❌ ERROR: jq is required to parse the JSON config file"
    echo "Please install jq: sudo yum install jq  # or sudo apt install jq"
    return 1
fi

echo "Setting up Schrodinger environment..."
echo "Using config file: $CONFIG_FILE"

# Load configuration from JSON
SCHRODINGER_PATH=$(jq -r '.schrodinger.installation_path' "$CONFIG_FILE")
SCHRODINGER_LICENSE_PATH=$(jq -r '.schrodinger.license_path' "$CONFIG_FILE")
SCHRODINGER_LICENSE_FILE=$(jq -r '.schrodinger.license_file' "$CONFIG_FILE")

# Validate required configuration variables
if [ -z "$SCHRODINGER_PATH" ] || [ "$SCHRODINGER_PATH" = "null" ] || \
   [ -z "$SCHRODINGER_LICENSE_PATH" ] || [ "$SCHRODINGER_LICENSE_PATH" = "null" ] || \
   [ -z "$SCHRODINGER_LICENSE_FILE" ] || [ "$SCHRODINGER_LICENSE_FILE" = "null" ]; then
    echo "❌ ERROR: Missing required configuration in $CONFIG_FILE"
    echo "Required fields: schrodinger.installation_path, schrodinger.license_path, schrodinger.license_file"
    return 1
fi

# =============================================================================
# ENVIRONMENT SETUP
# =============================================================================

# Build full license file path
SCHRODINGER_LICENSE_FILE_PATH="$SCHRODINGER_LICENSE_PATH/$SCHRODINGER_LICENSE_FILE"

# Export the SCHRODINGER environment variable
export SCHRODINGER="$SCHRODINGER_PATH"
echo "Set SCHRODINGER environment variable to: $SCHRODINGER"

# Export the SCHRODINGER_LICENSE_FILE environment variable
export SCHRODINGER_LICENSE_FILE="$SCHRODINGER_LICENSE_FILE_PATH"
echo "Set SCHRODINGER_LICENSE_FILE to: $SCHRODINGER_LICENSE_FILE"

# =============================================================================
# VALIDATION
# =============================================================================

# Check if Schrodinger installation exists
if [ ! -d "$SCHRODINGER" ]; then
    echo "❌ ERROR: Schrodinger installation not found at $SCHRODINGER"
    echo "Please check SCHRODINGER_PATH in your config file."
    echo ""
    echo "To find Schrodinger installation, try:"
    echo "  find /opt /usr/local -name 'glide' 2>/dev/null"
    return 1
fi

# Check if license directory exists
if [ ! -d "$SCHRODINGER_LICENSE_PATH" ]; then
    echo "❌ ERROR: Schrodinger license directory not found at $SCHRODINGER_LICENSE_PATH"
    echo "Please check SCHRODINGER_LICENSE_PATH in your config file."
    echo ""
    echo "To find license files, try:"
    echo "  find /opt -name '*.lic' 2>/dev/null"
    return 1
fi

# Check if the specific license file exists
if [ ! -f "$SCHRODINGER_LICENSE_FILE_PATH" ]; then
    echo "❌ ERROR: License file not found at $SCHRODINGER_LICENSE_FILE_PATH"
    echo "Please check SCHRODINGER_LICENSE_FILE in your config file."
    echo ""
    echo "Available license files:"
    ls "$SCHRODINGER_LICENSE_PATH"*.lic 2>/dev/null || echo "No license files found"
    return 1
else
    echo "✓ Found license file: $SCHRODINGER_LICENSE_FILE_PATH"
fi

# Add Schrodinger binaries to PATH
export PATH=$SCHRODINGER:$PATH
echo "Added Schrodinger to PATH"

# Check if key executables are available
if [ -x "$SCHRODINGER/glide" ] && [ -x "$SCHRODINGER/prime" ]; then
    echo "Schrodinger executables found (glide, prime)"
else
    echo "⚠ Warning: Some Schrodinger executables are missing"
    echo "Available executables:"
    ls "$SCHRODINGER"/{glide,prime,jobcontrol} 2>/dev/null || echo "Key executables not found"
fi

# =============================================================================
# LICENSE TESTING
# =============================================================================

# Check license availability
echo "Testing license connectivity..."
# Test with a simple glide help command to verify license
if $SCHRODINGER/glide -h >/dev/null 2>&1; then
    echo "✓ Schrodinger license is available and accessible"
else
    echo "⚠ Warning: License test failed. This could mean:"
    echo "  - License server is down"
    echo "  - Wrong license file specified"
    echo "  - Network connectivity issues"
    echo ""
    echo "License file contents (first few lines):"
    head -n 5 "$SCHRODINGER_LICENSE_FILE_PATH" 2>/dev/null || echo "Cannot read license file"
fi

# =============================================================================
# STATUS DISPLAY
# =============================================================================

# Display current job status
echo ""
echo "Current Schrodinger job status:"
echo "================================"
if command -v jobcontrol >/dev/null 2>&1; then
    $SCHRODINGER/jobcontrol -list
else
    echo "jobcontrol command not available"
fi

echo ""
echo "Schrodinger environment setup complete!"
echo "You can now run Schrodinger commands like: glide, prime, jobcontrol"

# Test that environment variables are properly set
echo ""
echo "Environment verification:"
echo "========================="
echo "SCHRODINGER=$SCHRODINGER"
echo "SCHRODINGER_LICENSE_FILE=$SCHRODINGER_LICENSE_FILE"
if [ -n "$SCHRODINGER" ] && [ -n "$SCHRODINGER_LICENSE_FILE" ]; then
    echo "✓ Environment variables successfully set in current shell"
else
    echo "❌ Environment variables not set - did you source this script?"
fi