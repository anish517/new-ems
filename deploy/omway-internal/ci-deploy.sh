#!/usr/bin/env bash
# Deploys one commit of OmWay EMS to this host. Invoked by the GitLab job as
#
#     sudo /srv/ems/deploy/ci-deploy.sh "$CI_PROJECT_DIR" "$CI_COMMIT_SHA"
#
# and allowed by /etc/sudoers.d/gitlab-runner-ems (installed from sudoers-gitlab-runner-ems
# next to this file). Runs as root because installing units and reloading nginx needs it;
# everything that touches the app itself runs as omway, like 2-install.sh always has.
#
# Order of operations, and why:
#   1. validate the arguments   — the sha and path come from the runner; trust nothing
#   2. pg_dump                  — a restorable copy from *before* migrate, kept for 14 deploys
#   3. rsync backend/           — mirrors the checkout; .env and the Firebase key are the only
#                                 server-only files (verified 2026-09-16) and are excluded, which
#                                 also protects them from --delete
#   4. rsync deploy/            — refreshes this directory, including this script (rsync writes a
#                                 temp file and renames, so the running copy is unaffected)
#   5. 2-install.sh             — pip, DB-target assertion, migrate, collectstatic, units, nginx
#   6. Flutter bundle           — only if the checkout carries frontend/build/web (a CI artifact);
#                                 the runner box cannot build Flutter itself, see CLAUDE.md
#   7. 4-smoke.py               — authenticated end-to-end check; a failure fails the job
#
# A full transcript goes to /srv/ems/logs/deploy-<timestamp>.log.
set -euo pipefail

SRC=${1:?usage: ci-deploy.sh <checkout-dir> <commit-sha>}
SHA=${2:?usage: ci-deploy.sh <checkout-dir> <commit-sha>}
EMS=/srv/ems
BUILDS=/home/gitlab-runner/builds
KEEP_DUMPS=14

die() { echo "ci-deploy: $*" >&2; exit 1; }

# --- 1. validate -------------------------------------------------------------------------
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

# --- 2. database backup --------------------------------------------------------------------
echo "== pg_dump before migrate"
# The URL lives in .env (mode 600, owned by omway). Turn it into libpq environment variables
# so the password reaches pg_dump through the environment and never through argv.
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
# keep the newest $KEEP_DUMPS pre-deploy dumps; the cPanel migration dumps are named differently
ls -1t "$EMS"/backups/pre-deploy-*.dump 2>/dev/null | tail -n +$((KEEP_DUMPS + 1)) | xargs -r rm -v --

# --- 3 + 4. code ---------------------------------------------------------------------------
# --checksum: a fresh CI checkout gives every file a new mtime, so without it rsync would
# re-send (and list) all ~1800 files on every deploy. With it, only files whose content changed
# are transferred, and --info=name,del makes the log a plain list of exactly those, plus
# deletions. Never pipe rsync here: under pipefail, a closed pipe kills the transfer midway.
echo "== sync backend/ -> $EMS/app (changed files only)"
rsync -a --checksum --delete --chown=omway:omway --info=name,del \
    --exclude='/.env' --exclude='/firebase-service-account.json' \
    --exclude='__pycache__/' --exclude='*.pyc' \
    "$SRC/backend/" "$EMS/app/"

echo "== sync deploy/omway-internal/ -> $EMS/deploy"
rsync -a --checksum --delete --chown=root:root --info=name,del --exclude='__pycache__/' \
    "$SRC/deploy/omway-internal/" "$EMS/deploy/"

# --- 5. install ----------------------------------------------------------------------------
bash "$EMS/deploy/2-install.sh"

# --- 6. Flutter bundle (optional) ----------------------------------------------------------
if [[ -f $SRC/frontend/build/web/index.html ]]; then
    bash "$EMS/deploy/install-frontend.sh" "$SRC/frontend/build/web"
else
    echo "== no frontend/build/web in the checkout; Flutter bundle left as is"
fi

# --- 7. smoke ------------------------------------------------------------------------------
echo "== smoke test"
runuser -u omway -- env -C "$EMS/app" "$EMS/venv/bin/python" "$EMS/deploy/4-smoke.py"

echo "$SHA" > "$EMS/DEPLOYED_SHA"
echo "== deployed $SHA OK"
