#!/usr/bin/env bash
# Deploys one commit to this host. Called by the GitLab deploy job as
#   sudo /srv/ems/deploy/ci-deploy.sh "$CI_PROJECT_DIR" "$CI_COMMIT_SHA"
# (allowed by /etc/sudoers.d/gitlab-runner-ems). Steps: validate args, pg_dump,
# rsync backend/ and deploy/, 2-install.sh, optional Flutter bundle, 4-smoke.py.
# Transcript: /srv/ems/logs/deploy-<timestamp>.log
set -euo pipefail

SRC=${1:?usage: ci-deploy.sh <checkout-dir> <commit-sha>}
SHA=${2:?usage: ci-deploy.sh <checkout-dir> <commit-sha>}
EMS=/srv/ems
BUILDS=/home/gitlab-runner/builds
KEEP_DUMPS=14

die() { echo "ci-deploy: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "must run as root (via sudo)"
case "$SHA" in *[!0-9a-f]*|"") die "commit sha is not hex: $SHA" ;; esac
[[ ${#SHA} -eq 40 ]] || die "commit sha must be 40 characters"
SRC=$(realpath -e -- "$SRC") || die "checkout dir does not exist"
[[ $SRC == "$BUILDS"/* ]] || die "checkout must live under $BUILDS, got $SRC"
[[ -f $SRC/backend/manage.py ]] || die "no backend/manage.py in $SRC"
[[ -f $SRC/deploy/omway-internal/2-install.sh ]] || die "no deploy/omway-internal in $SRC"
HEAD=$(git -C "$SRC" rev-parse HEAD) || die "not a git checkout"
[[ $HEAD == "$SHA" ]] || die "checkout is at $HEAD, pipeline is for $SHA"
git -C "$SRC" diff --quiet HEAD -- backend deploy || die "tracked files in the checkout are modified"

TS=$(date +%Y-%m-%d-%H%M%S)
mkdir -p "$EMS/logs"
exec > >(tee -a "$EMS/logs/deploy-$TS.log") 2>&1
echo "== deploy $SHA at $TS from $SRC"
git -C "$SRC" --no-pager log --oneline -1

echo "== pg_dump before migrate"
# DATABASE_URL from .env -> libpq env vars, so the password never appears in argv.
eval "$(runuser -u omway -- env -C "$EMS/app" "$EMS/venv/bin/python" - <<'PY'
import shlex
import dj_database_url
from decouple import config
u = dj_database_url.parse(config("DATABASE_URL"))
for env, key in (("PGHOST", "HOST"), ("PGPORT", "PORT"), ("PGUSER", "USER"),
                 ("PGPASSWORD", "PASSWORD"), ("PGDATABASE", "NAME")):
    if u.get(key):
        print(f"export {env}={shlex.quote(str(u[key]))}")
PY
)"
DUMP="$EMS/backups/pre-deploy-$TS-${SHA:0:7}.dump"
runuser -u omway --preserve-environment -- pg_dump --format=custom --no-owner --file="$DUMP"
unset PGPASSWORD
ls -la "$DUMP"
ls -1t "$EMS"/backups/pre-deploy-*.dump 2>/dev/null | tail -n +$((KEEP_DUMPS + 1)) | xargs -r rm -v --

# .env and the Firebase key are the only server-only files; excluding them also
# protects them from --delete. --checksum: CI checkouts have fresh mtimes.
echo "== sync backend/ -> $EMS/app (changed files only)"
rsync -a --checksum --delete --chown=omway:omway --info=name,del \
    --exclude='/.env' --exclude='/firebase-service-account.json' \
    --exclude='__pycache__/' --exclude='*.pyc' \
    "$SRC/backend/" "$EMS/app/"

echo "== sync deploy/omway-internal/ -> $EMS/deploy"
rsync -a --checksum --delete --chown=root:root --info=name,del --exclude='__pycache__/' \
    "$SRC/deploy/omway-internal/" "$EMS/deploy/"

bash "$EMS/deploy/2-install.sh"

if [[ -f $SRC/frontend/build/web/index.html ]]; then
    bash "$EMS/deploy/install-frontend.sh" "$SRC/frontend/build/web"
else
    echo "== no frontend/build/web in the checkout; Flutter bundle left as is"
fi

echo "== smoke test"
runuser -u omway -- env -C "$EMS/app" "$EMS/venv/bin/python" "$EMS/deploy/4-smoke.py"

echo "$SHA" > "$EMS/DEPLOYED_SHA"
echo "== deployed $SHA OK"
