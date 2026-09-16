#!/usr/bin/env bash
# Builds the Flutter web client on THIS machine and installs it on omway-internal.
#
#     deploy/omway-internal/5-deploy-frontend.sh
#
# The frontend is not built by the GitLab pipeline: the only runner is the production box
# itself (1.8 GB RAM, shared with the Node apps), and `flutter build web` needs more than that.
# Until a runner with room to build exists, this script is the frontend deploy.
#
# Requires the pinned SDK (~/fvm/versions/3.47.1; the global Flutter cannot build this
# project) and the `omway-internal` ssh alias with root access.
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
