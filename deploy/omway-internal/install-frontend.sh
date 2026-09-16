#!/usr/bin/env bash
# Installs a built Flutter web bundle into /srv/ems/www/app with an atomic swap. Run as root.
#
#     install-frontend.sh <dir containing index.html>
#
# Called by ci-deploy.sh when a pipeline carries frontend/build/web, and by
# 5-deploy-frontend.sh (run on a developer machine) after it uploads a bundle built there.
# The previous bundle is kept at /srv/ems/www/app.prev for one deploy, so a bad build is a
# `mv` away from being undone.
set -euo pipefail
SRC=${1:?usage: install-frontend.sh <build-dir>}
WWW=/srv/ems/www
[[ -f $SRC/index.html && -f $SRC/main.dart.js ]] || { echo "install-frontend: $SRC is not a Flutter web build" >&2; exit 1; }
# Refuse a bundle built for the wrong origin: the API base URL is compiled into main.dart.js.
grep -q 'ems.omwaytechnologies.com' "$SRC/main.dart.js" || { echo "install-frontend: bundle does not reference ems.omwaytechnologies.com — built without --dart-define=API_BASE_URL?" >&2; exit 1; }

echo "== install Flutter bundle -> $WWW/app"
rm -rf "$WWW/app.next"
rsync -a --chown=omway:omway "$SRC/" "$WWW/app.next/"
rm -rf "$WWW/app.prev"
[[ -d $WWW/app ]] && mv "$WWW/app" "$WWW/app.prev"
mv "$WWW/app.next" "$WWW/app"
du -sh "$WWW/app" | cut -f1 | sed 's/^/   size: /'
