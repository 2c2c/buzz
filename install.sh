#!/bin/sh
# Installs Buzz from the latest GitHub release.
#
#   curl -fsSL https://raw.githubusercontent.com/2c2c/buzz/main/install.sh | sh
#
# Set BUZZ_DIR to install somewhere other than /Applications.
set -eu

REPO="2c2c/buzz"
ASSET="buzz-macos.tar.gz"
APP="Buzz.app"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Buzz only runs on macOS." >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Downloading Buzz..."
url="https://github.com/$REPO/releases/latest/download/$ASSET"
if curl -fsSL "$url" -o "$tmp/$ASSET" 2>/dev/null; then
  :
elif command -v gh >/dev/null 2>&1 && gh release download --repo "$REPO" --pattern "$ASSET" --dir "$tmp" 2>/dev/null; then
  # The repository is private: fall back to the signed-in GitHub CLI.
  :
else
  echo "Could not download $ASSET from $REPO." >&2
  echo "If the repository is private, sign in with the GitHub CLI (gh auth login) and try again." >&2
  exit 1
fi

tar -xzf "$tmp/$ASSET" -C "$tmp"

dest="${BUZZ_DIR:-/Applications}"
if [ -z "${BUZZ_DIR:-}" ] && [ ! -w "$dest" ]; then
  dest="$HOME/Applications"
fi
mkdir -p "$dest"
rm -rf "$dest/$APP"
mv "$tmp/$APP" "$dest/$APP"

bin="$dest/$APP/Contents/MacOS/buzz"
echo "Installed $dest/$APP"

if "$bin" --play "b40/10@6" >/dev/null 2>&1; then
  echo "Sent a test buzz. Rest a finger on the trackpad and run this to feel it again:"
  echo "  \"$bin\" --play \"b40/10@6\""
else
  echo "No haptic trackpad was found, so the test buzz was skipped."
fi

echo
echo "Next: give your coding agent the setup prompt. Either"
echo "  open \"$dest/$APP\"        (shows the prompt with a Copy button)"
echo "  \"$bin\" --prompt   (prints it)"
