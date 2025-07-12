#!/bin/bash
# scripts/containerManagement/build-image.sh

set -euo pipefail

# Fixes bug where first separator line does not fill the terminal width
COLUMNS=$(tput cols 2>/dev/null || echo 80)

# Utility function for printing section separators
print_separator() {
  local char="${1:-=}"
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' "$char"
}

IMAGE_NAME="session-database"
TAG="${1:-latest}"

print_separator "="
echo "🔨 Building session-database Docker image..."
print_separator "-"

print_separator "="
echo "📦 Building image: $IMAGE_NAME:$TAG"
print_separator "-"

if docker build -t "$IMAGE_NAME:$TAG" .; then
  print_separator "="
  echo "✅ Image built successfully: $IMAGE_NAME:$TAG"
  print_separator "-"

  echo "📊 Image details:"
  docker images "$IMAGE_NAME:$TAG"
else
  print_separator "="
  echo "❌ Image build failed"
  print_separator "="
  exit 1
fi

print_separator "="
echo "✅ Build completed."
print_separator "="
