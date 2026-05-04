#!/usr/bin/env bash
# TinyQuestion one-shot installer.
#
# Run via:
#   curl -fsSL https://raw.githubusercontent.com/PhillipMogensen/TinyQuestion/main/scripts/install.sh | bash
#
# What it does (idempotent — safe to re-run):
#   1. Verifies macOS 14 (Sonoma) or later
#   2. Installs Homebrew if missing
#   3. Installs Ollama via Homebrew if missing, starts the service
#   4. Pulls the default model (phi4-mini) if not already pulled
#   5. Downloads the latest TinyQuestion DMG and copies the .app to /Applications
#   6. Strips the Gatekeeper quarantine flag and launches the app

set -euo pipefail

REPO="PhillipMogensen/TinyQuestion"
DEFAULT_MODEL="phi4-mini"
MIN_MACOS_MAJOR=14

if [[ -t 1 ]]; then
  GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
  BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  GREEN=""; YELLOW=""; RED=""; BOLD=""; RESET=""
fi
step() { echo "${BOLD}${GREEN}==>${RESET} ${BOLD}$*${RESET}"; }
warn() { echo "${BOLD}${YELLOW}!!${RESET}  $*" >&2; }
die()  { echo "${BOLD}${RED}error:${RESET} $*" >&2; exit 1; }

# 1. Sanity ---------------------------------------------------------------
[[ "$(uname)" == "Darwin" ]] || die "TinyQuestion is macOS-only."
MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_MAJOR="${MACOS_VERSION%%.*}"
if (( MACOS_MAJOR < MIN_MACOS_MAJOR )); then
  die "macOS $MIN_MACOS_MAJOR (Sonoma) or later required (you have $MACOS_VERSION)."
fi
[[ -w /Applications ]] || die "/Applications is not writable by $(id -un). Re-run as an admin user."

step "TinyQuestion installer"
echo "    macOS: $MACOS_VERSION  ($(uname -m))"

# 2. Homebrew -------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  step "Homebrew not found — installing"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Brew on Apple Silicon installs to /opt/homebrew, on Intel to /usr/local.
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# 3. Ollama ---------------------------------------------------------------
if ! command -v ollama >/dev/null 2>&1; then
  step "Installing Ollama"
  brew install ollama
else
  echo "    ollama already installed"
fi

# 4. Service --------------------------------------------------------------
ollama_up() { curl -fsS --max-time 2 http://localhost:11434/api/tags >/dev/null 2>&1; }
if ! ollama_up; then
  step "Starting Ollama service"
  if ! brew services start ollama >/dev/null 2>&1; then
    # Fallback for users who installed Ollama outside Homebrew.
    nohup ollama serve >/dev/null 2>&1 &
    disown "$!" 2>/dev/null || true
  fi
  for _ in $(seq 1 30); do
    ollama_up && break
    sleep 1
  done
  ollama_up || die "Ollama is installed but didn't respond on localhost:11434 within 30s."
fi

# 5. Default model --------------------------------------------------------
if curl -fsS http://localhost:11434/api/tags | grep -q "\"name\":\"$DEFAULT_MODEL"; then
  echo "    model $DEFAULT_MODEL already pulled"
else
  step "Pulling default model: $DEFAULT_MODEL  (this may take a few minutes)"
  ollama pull "$DEFAULT_MODEL"
fi

# 6. App download ---------------------------------------------------------
step "Fetching latest TinyQuestion release"
DMG_URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -oE '"browser_download_url"[^"]*"[^"]*\.dmg"' \
  | sed -E 's/.*"(https[^"]+)"/\1/' \
  | head -1)"
[[ -n "$DMG_URL" ]] || die "no .dmg asset found in latest release of $REPO"
VERSION="$(printf '%s\n' "$DMG_URL" | sed -E 's/.*-([0-9]+\.[0-9]+\.[0-9]+)\.dmg.*/\1/')"
echo "    version $VERSION"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
TMP_DMG="$TMP_DIR/TinyQuestion.dmg"
curl -fL --progress-bar -o "$TMP_DMG" "$DMG_URL"

# 7. Mount, copy, unmount -------------------------------------------------
step "Installing to /Applications"
ATTACH_OUT="$(hdiutil attach -nobrowse "$TMP_DMG")"
MOUNT_POINT="$(printf '%s\n' "$ATTACH_OUT" \
  | awk -F'\t' '/Apple_HFS|Apple_APFS/ { for (i=NF;i>=1;i--) if ($i ~ /^\/Volumes/) { print $i; exit } }')"
[[ -d "$MOUNT_POINT" ]] || die "couldn't determine DMG mount point"

if [[ -e /Applications/TinyQuestion.app ]]; then
  # Stop a running copy so cp -R doesn't trip on a busy file.
  pkill -f /Applications/TinyQuestion.app 2>/dev/null || true
  rm -rf /Applications/TinyQuestion.app
fi
cp -R "$MOUNT_POINT/TinyQuestion.app" /Applications/
hdiutil detach -quiet "$MOUNT_POINT" >/dev/null 2>&1 || true
xattr -dr com.apple.quarantine /Applications/TinyQuestion.app 2>/dev/null || true

# 8. Done -----------------------------------------------------------------
step "Installed TinyQuestion $VERSION"
echo ""
echo "    Default hotkey: ⌥⌘J  (configure via ⌘, while the overlay is open)"
echo "    Launching now…"
open /Applications/TinyQuestion.app
