#!/usr/bin/env bash
#
# Build script to package the MENOTA TEI Publisher extension as a .xar file
# for installation in eXist-db.

# Extract the package abbreviation and version from expath-pkg.xml
PKG_ABBREV=$(sed -n 's/.*<package.*abbrev="\([^"]*\)".*/\1/p' expath-pkg.xml | head -n 1)
PKG_VERSION=$(sed -n 's/.*<package.*version="\([^"]*\)".*/\1/p' expath-pkg.xml | head -n 1)

if [ -z "$PKG_ABBREV" ] || [ -z "$PKG_VERSION" ]; then
    # Try alternate regex in case attributes are on different lines
    PKG_ABBREV=$(grep -o 'abbrev="[^"]*"' expath-pkg.xml | head -n 1 | cut -d'"' -f2)
    PKG_VERSION=$(grep -E '^\s*version="[^"]*"' expath-pkg.xml | head -n 1 | cut -d'"' -f2)
fi

if [ -z "$PKG_ABBREV" ] || [ -z "$PKG_VERSION" ]; then
    echo "Error: Could not extract package abbreviation or version from expath-pkg.xml."
    exit 1
fi

XAR_NAME="${PKG_ABBREV}-${PKG_VERSION}.xar"

echo "Building package: ${XAR_NAME} ..."

# Remove any existing .xar file with the same name
if [ -f "$XAR_NAME" ]; then
    rm "$XAR_NAME"
fi

# Zip all contents of the directory into the .xar file, excluding unnecessary files
zip -r "${XAR_NAME}" . \
    -x ".*" \
    -x "*/.*" \
    -x "*.DS_Store" \
    -x "build.sh" \
    -x "*.xar" \
    -x "node_modules/*" \
    -x "package-lock.json"

echo ""
if [ -f "$XAR_NAME" ]; then
    echo "Success! Package built: ${XAR_NAME}"
    echo "You can now upload this .xar file via the eXist-db Package Manager."
else
    echo "Error: Package build failed."
    exit 1
fi
