#!/usr/bin/env bash
set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
GHCR_IMAGE="ghcr.io/nextlevelbuilder/goclaw-web"
UPSTREAM_REPO="https://github.com/nextlevelbuilder/goclaw.git"
COMPOSE_FILES=(
  "docker-compose.yml"
  "docker-compose-dokploy.yml"
)

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Helpers ─────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}ℹ ${NC}$*"; }
warn()    { echo -e "${YELLOW}⚠ ${NC}$*"; }
error()   { echo -e "${RED}✗ ${NC}$*" >&2; }
success() { echo -e "${GREEN}✓ ${NC}$*"; }

# ── Get latest version from upstream ────────────────────────────────────────
get_latest_version() {
  local version
  version=$(git ls-remote --tags "$UPSTREAM_REPO" 2>/dev/null | \
    grep -v '\^{}' | \
    awk '{print $2}' | \
    sed 's|refs/tags/||' | \
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | \
    sort -V | \
    tail -1)

  if [[ -z "$version" ]]; then
    error "Failed to fetch latest version from upstream" >&2
    exit 1
  fi

  echo "$version"
}

# ── Verify version exists in GHCR ───────────────────────────────────────────
verify_ghcr_version() {
  local version=$1

  info "Verifying ${version} exists in GHCR..."

  # Try docker manifest first, fallback to skopeo if available
  if docker manifest inspect "${GHCR_IMAGE}:${version}" >/dev/null 2>&1; then
    success "${version} found in GHCR"
    return 0
  elif command -v skopeo >/dev/null 2>&1; then
    if skopeo inspect "docker://${GHCR_IMAGE}:${version}" >/dev/null 2>&1; then
      success "${version} found in GHCR (via skopeo)"
      return 0
    fi
  fi

  warn "Could not verify ${version} in GHCR (proceeding anyway)"
  warn "If version doesn't exist, docker compose pull will fail"
  return 0
}

# ── Get current version from compose files ──────────────────────────────────
get_current_version() {
  local file="${COMPOSE_FILES[0]}"

  if [[ ! -f "$file" ]]; then
    error "Compose file not found: $file"
    exit 1
  fi

  local version
  version=$(grep "image: ${GHCR_IMAGE}:" "$file" | \
    sed "s|.*${GHCR_IMAGE}:||" | \
    tr -d '[:space:]')

  echo "$version"
}

# ── Update compose files with new version ───────────────────────────────────
update_compose_files() {
  local new_version=$1
  local updated=0

  for file in "${COMPOSE_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
      warn "$file not found, skipping"
      continue
    fi

    # macOS compatible sed
    if [[ "$OSTYPE" == darwin* ]]; then
      sed -i '' "s|image: ${GHCR_IMAGE}:.*|image: ${GHCR_IMAGE}:${new_version}|" "$file"
    else
      sed -i "s|image: ${GHCR_IMAGE}:.*|image: ${GHCR_IMAGE}:${new_version}|" "$file"
    fi

    success "Updated $file → ${new_version}"
    ((updated++))
  done

  if [[ $updated -eq 0 ]]; then
    error "No compose files were updated"
    exit 1
  fi

  success "Updated ${updated} compose file(s)"
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
  local target_version=""

  # Parse arguments
  if [[ $# -eq 0 ]]; then
    # No arguments: auto-detect latest version
    target_version=$(get_latest_version)
    info "Latest version detected: ${CYAN}${target_version}${NC}"
  else
    # Version tag provided
    target_version="$1"

    # Add 'v' prefix if missing
    if [[ ! "$target_version" =~ ^v ]]; then
      target_version="v${target_version}"
    fi

    info "Target version: ${CYAN}${target_version}${NC}"
  fi

  # Verify version exists in GHCR
  if ! verify_ghcr_version "$target_version"; then
    exit 1
  fi

  # Get current version
  local current_version
  current_version=$(get_current_version)
  info "Current version: ${CYAN}${current_version}${NC}"

  # Check if already up to date
  if [[ "$current_version" == "$target_version" ]]; then
    success "Already running ${target_version}"
    exit 0
  fi

  # Update compose files
  echo ""
  info "Upgrading: ${current_version} → ${target_version}"
  update_compose_files "$target_version"

  # Show diff
  echo ""
  info "Changes:"
  git diff --color=auto "${COMPOSE_FILES[@]}" || true

  echo ""
  success "Upgrade complete: ${target_version}"
  info "Next steps:"
  echo "  1. Review changes above"
  echo "  2. Pull new image: docker compose pull"
  echo "  3. Restart services: docker compose up -d"
  echo "  4. Commit changes: git add . && git commit -m 'chore: upgrade to ${target_version}'"
}

# ── Usage ───────────────────────────────────────────────────────────────────
usage() {
  echo "Usage: ./upgrade.sh [VERSION]"
  echo ""
  echo "Upgrade GoClaw to a specific version or auto-detect latest."
  echo ""
  echo "Examples:"
  echo "  ./upgrade.sh          # Auto-detect and upgrade to latest version"
  echo "  ./upgrade.sh v2.9.1   # Upgrade to specific version"
  echo "  ./upgrade.sh 2.9.1    # Same (v prefix optional)"
  echo ""
}

# ── Entry point ─────────────────────────────────────────────────────────────
case "${1:-}" in
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    main "$@"
    ;;
esac
