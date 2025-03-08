#!/bin/bash

# This script copies the hdc tools directory into the built app's Resources directory
# To be used as a Run Script build phase in Xcode

# Exit on any error
set -e

# Print commands as they are executed
set -x

# Get the source hdc directory
SRC_HDC_DIR="${PROJECT_DIR}/ResourcesTools/hdc"

# Get the destination directory in the built app bundle
DEST_RESOURCES_DIR="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}/Contents/Resources"
DEST_HDC_DIR="${DEST_RESOURCES_DIR}/hdc"

# Check if source directory exists
if [ ! -d "$SRC_HDC_DIR" ]; then
  echo "ERROR: Source hdc directory does not exist: $SRC_HDC_DIR"
  exit 1
fi

# Create destination resources directory if it doesn't exist
mkdir -p "$DEST_RESOURCES_DIR"

# Remove old hdc directory if it exists
if [ -d "$DEST_HDC_DIR" ]; then
  rm -rf "$DEST_HDC_DIR"
fi

# Copy the entire hdc directory recursively
echo "Copying hdc tools from $SRC_HDC_DIR to $DEST_HDC_DIR"
cp -R "$SRC_HDC_DIR" "$DEST_HDC_DIR"

# Set executable permissions for key binaries
chmod +x "$DEST_HDC_DIR/hdc"
chmod +x "$DEST_HDC_DIR/diff"
chmod +x "$DEST_HDC_DIR/idl"
chmod +x "$DEST_HDC_DIR/restool"
chmod +x "$DEST_HDC_DIR/rawheap_translator"
chmod +x "$DEST_HDC_DIR/ark_disasm"
chmod +x "$DEST_HDC_DIR/syscap_tool"
chmod +x "$DEST_HDC_DIR/hnpcli"

echo "hdc tools directory successfully copied to app bundle" 