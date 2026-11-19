#!/usr/bin/env bash
# Installs a Flutter web build into /srv/ems/www/app (atomic swap, previous kept
# at app.prev). Run as root:  install-frontend.sh <dir containing index.html>
set -euo pipefail
SRC=${1:?usage: install-frontend.sh <build-dir>}
WWW=/srv/ems/www
[[ -f $SRC/index.html && -f $SRC/main.dart.js ]] || { echo "install-frontend: $SRC is not a Flutter web build" >&2; exit 1; }
grep -q 'ems.omwaytechnologies.com' "$SRC/main.dart.js" || { echo "install-frontend: bundle does not reference ems.omwaytechnologies.com — built without --dart-define=API_BASE_URL?" >&2; exit 1; }

echo "== install Flutter bundle -> $WWW/app"
rm -rf "$WWW/app.next"
rsync -a --chown=omway:omway "$SRC/" "$WWW/app.next/"
rm -rf "$WWW/app.prev"
[[ -d $WWW/app ]] && mv "$WWW/app" "$WWW/app.prev"
mv "$WWW/app.next" "$WWW/app"
du -sh "$WWW/app" | cut -f1 | sed 's/^/   size: /'
