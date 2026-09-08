#!/usr/bin/env bash
# Run as root on omway-internal. Pulls everything EMS needs from the cPanel production
# host directly, server to server: Firebase key, mail credentials, a full data dump
# loaded into PostgreSQL, and the media tree. Re-run at cutover for the final sync.
#
# Preferred: key auth. `Host cpanel` in /root/.ssh/config points at the cPanel account
# with /root/.ssh/id_ed25519_cpanel, whose public key is in that account's
# ~/.ssh/authorized_keys. Then simply:
#
#     bash /srv/ems/deploy/3-pull-from-cpanel.sh </dev/null
#
# Fallback: if a password is supplied on stdin it is used via sshpass (never argv):
#
#     bash /srv/ems/deploy/3-pull-from-cpanel.sh < <(printf '%s\n' "$CPANEL_PASSWORD")
#
# FLUSH=1 wipes this host's database before loading — for the final sync at cutover only.
set -uo pipefail
CP=cpanel
if [ -t 0 ] || ! IFS= read -r SSHPASS || [ -z "${SSHPASS:-}" ]; then
  SSH="ssh -o BatchMode=yes"; echo "auth: ssh key (Host cpanel)"
else
  export SSHPASS; SSH="sshpass -e ssh"; echo "auth: password from stdin"
fi
rc=0
TS=$(date +%F-%H%M%S)
mkdir -p /srv/ems/backups; chown omway:omway /srv/ems/backups
PY=/srv/ems/venv/bin/python
CPY='~/virtualenv/ems/3.11/bin/python'

echo "== 0. connectivity"
if ! $SSH "$CP" 'echo "   connected as $(whoami) on $(hostname)"'; then echo "   cannot reach cPanel — aborting"; exit 2; fi

echo "== 1. firebase-service-account.json"
if $SSH "$CP" 'cat ~/ems/firebase-service-account.json' > /srv/ems/app/firebase-service-account.json \
   && [ -s /srv/ems/app/firebase-service-account.json ]; then
  chown omway:omway /srv/ems/app/firebase-service-account.json; chmod 600 /srv/ems/app/firebase-service-account.json
  echo "   ok  md5=$(md5sum /srv/ems/app/firebase-service-account.json | cut -c1-32)  (cPanel copy: 29985b4fc553b35e9197839e45f3b989)"
else echo "   FAILED"; rc=1; fi

echo "== 2. mail credentials -> .env (values not printed)"
CREDS=$($SSH "$CP" "cd ~/ems && $CPY -" <<'PYEOF'
import os, django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "base.settings"); django.setup()
from django.conf import settings as s
print(s.EMAIL_HOST_USER); print(s.EMAIL_HOST_PASSWORD)
PYEOF
) || true
EU=$(printf '%s\n' "$CREDS" | sed -n 1p); EP=$(printf '%s\n' "$CREDS" | sed -n 2p)
if [ -n "$EU" ]; then
  sed -i "s|^EMAIL_HOST_USER=.*|EMAIL_HOST_USER=$EU|; s|^EMAIL_HOST_PASSWORD=.*|EMAIL_HOST_PASSWORD=$EP|" /srv/ems/app/.env
  echo "   ok  EMAIL_HOST_USER (len ${#EU}) and EMAIL_HOST_PASSWORD (len ${#EP}) written"
else echo "   cPanel has no mail credentials configured — left blank (reset mail does not send there either)"; fi

echo "== 3. data: dumpdata --all on cPanel -> loaddata into PostgreSQL"
# --all: the default manager hides soft-deleted rows; without it they would be silently dropped.
DUMP=/srv/ems/backups/cpanel-dump-$TS.json
if $SSH "$CP" "cd ~/ems && $CPY manage.py dumpdata --all --natural-foreign --exclude contenttypes --exclude auth.permission --exclude sessions --exclude admin.logentry" > "$DUMP" \
   && $PY - "$DUMP" <<'PYEOF'
import json, os, sys
p = sys.argv[1]; d = json.load(open(p))
print(f"   dump ok: {len(d)} objects across {len({o['model'] for o in d})} models, {os.path.getsize(p)} bytes")
PYEOF
then
  chown omway:omway "$DUMP"
  if [ "${FLUSH:-0}" = "1" ]; then echo "   FLUSH=1: wiping local database first"; su omway -c "cd /srv/ems/app && $PY manage.py flush --noinput"; fi
  if su omway -c "cd /srv/ems/app && $PY manage.py loaddata $DUMP" 2>&1 | tail -3 | sed 's/^/   /'; then :; else echo "   loaddata FAILED (transaction rolled back)"; rc=1; fi
else echo "   dump FAILED"; rc=1; fi

echo "== 4. media (rsync, server to server)"
RS=$(rsync -az --stats -e "$SSH" "$CP:public_html/media/" /srv/ems/media/ 2>&1); rrc=$?
printf '%s\n' "$RS" | grep -E "Number of files|Number of regular files transferred|Total file size" | sed 's/^/   /'
if [ "$rrc" -eq 0 ]; then chown -R omway:omway /srv/ems/media; echo "   ok  media on disk: $(du -sh /srv/ems/media | cut -f1), $(find /srv/ems/media -type f | wc -l) files"
else echo "   rsync FAILED (exit $rrc)"; printf '%s\n' "$RS" | tail -3 | sed 's/^/   /'; rc=1; fi

echo "== 5. proof: row counts per model, cPanel (MariaDB) vs here (PostgreSQL)"
COUNT_PY='
import os, django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "base.settings"); django.setup()
from django.apps import apps
for m in sorted(apps.get_models(), key=lambda m: m._meta.label):
    if m._meta.app_label in ("contenttypes", "sessions", "admin") or m._meta.model_name == "permission": continue
    print(f"{m._meta.label}\t{m._base_manager.count()}")
'
$SSH "$CP" "cd ~/ems && $CPY -" <<<"$COUNT_PY" > /tmp/counts-cpanel.tsv
su omway -c "cd /srv/ems/app && $PY -" <<<"$COUNT_PY" > /tmp/counts-local.tsv
join -t$'\t' -a1 -a2 -e MISSING -o 0,1.2,2.2 /tmp/counts-cpanel.tsv /tmp/counts-local.tsv \
  | awk -F'\t' 'BEGIN{bad=0;tot=0} {tot++; f=($2==$3)?"":"  <-- MISMATCH"; if(f!="")bad++; printf "   %-48s cpanel=%-6s local=%-6s%s\n",$1,$2,$3,f} END{printf "   %d models compared, %d mismatches\n",tot,bad; exit (bad>0)}' || rc=1
rm -f /tmp/counts-cpanel.tsv /tmp/counts-local.tsv
unset SSHPASS
echo "== done rc=$rc"; exit $rc
