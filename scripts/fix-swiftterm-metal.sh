#!/bin/bash
# Workaround for tuist/tuist#9111: Tuist adds .metal files to both Sources and Resources
# build phases, causing "Unexpected duplicate tasks" (MetalLink runs twice).
# Fix: remove the Resources entry, keep Sources (metal files need compilation).

PBXPROJ="Tuist/.build/tuist-derived/SwiftTerm/SwiftTerm.xcodeproj/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
  echo "SwiftTerm project not found, skipping"
  exit 0
fi

if grep -q "Shaders.metal in Resources" "$PBXPROJ"; then
  # Extract the build file ID from the PBXBuildFile line only (first match)
  RESOURCE_ID=$(grep "Shaders.metal in Resources" "$PBXPROJ" | head -1 | awk '{print $1}')
  if [ -n "$RESOURCE_ID" ]; then
    sed -i '' "/${RESOURCE_ID}/d" "$PBXPROJ"
    echo "Fixed: removed duplicate Shaders.metal from Resources (ID: ${RESOURCE_ID})"
  fi
  SOURCE_ID=$(grep "Shaders.metal in Sources" "$PBXPROJ" | head -1 | awk '{print $1}')
  if [ -n "$SOURCE_ID" ]; then
    sed -i '' "/${SOURCE_ID}/d" "$PBXPROJ"
    echo "Fixed: removed duplicate Shaders.metal from Sources (ID: ${SOURCE_ID})"
  fi
else
  echo "No duplicate Metal entry found, skipping"
fi
