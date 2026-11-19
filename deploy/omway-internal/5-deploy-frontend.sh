#!/usr/bin/env bash
# Builds the Flutter web client on this machine and installs it on omway-internal.
# Needs the pinned SDK (~/fvm/versions/3.47.1) and the omway-internal ssh alias.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
FLUTTER=${FLUTTER:-$HOME/fvm/versions/3.47.1/bin/flutter}
[[ -x $FLUTTER ]] || { echo "flutter not found at $FLUTTER (set FLUTTER=...)" >&2; exit 1; }

cd "$ROOT/frontend"
echo "== flutter build web ($("$FLUTTER" --version 2>/dev/null | head -1))"
"$FLUTTER" build web --release --base-href /app/ --no-tree-shake-icons \
    --dart-define=API_BASE_URL=https://ems.omwaytechnologies.com

TGZ=$(mktemp -t ems-web.XXXXXX.tgz)
trap 'rm -f "$TGZ"' EXIT
tar -C build/web -czf "$TGZ" .
echo "== upload $(du -h "$TGZ" | cut -f1) and install"
ssh omway-internal 'set -e; D=$(mktemp -d /tmp/ems-web.XXXXXX); tar xzf - -C "$D"; bash /srv/ems/deploy/install-frontend.sh "$D"; rm -rf "$D"' < "$TGZ"

echo "== public check"
curl -sS --fail -o /dev/null -w 'https://ems.omwaytechnologies.com/app/ -> HTTP %{http_code}\n' https://ems.omwaytechnologies.com/app/
