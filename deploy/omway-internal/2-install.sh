#!/usr/bin/env bash
# Run as root on omway-internal after code is in /srv/ems/app and this directory is in
# /srv/ems/deploy. Idempotent: safe to re-run on every deploy.
set -euo pipefail
cd /srv/ems
[ -f app/manage.py ] || { echo "no code at /srv/ems/app"; exit 1; }
[ -f app/.env ]      || { echo "no .env — run 1-provision.sh first"; exit 1; }
[ -f app/firebase-service-account.json ] || echo "WARNING: firebase-service-account.json missing — push notifications will not work until it is copied from the cPanel host (~/ems/)"

echo "== venv + requirements (as omway)"
[ -x venv/bin/python ] || su omway -c "python3 -m venv /srv/ems/venv && /srv/ems/venv/bin/pip install -q --upgrade pip"
su omway -c "/srv/ems/venv/bin/pip install -q -r /srv/ems/app/requirements.txt"

echo "== assert the database target inside the Python process"
su omway -c "cd /srv/ems/app && /srv/ems/venv/bin/python -c \"
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE','base.settings'); django.setup()
from django.conf import settings as s
d = s.DATABASES['default']
assert d['ENGINE'].endswith('postgresql') and d['NAME'] == 'ems', d
assert s.DEBUG is False
print('DB =', d['NAME'], '| ENGINE =', d['ENGINE'], '| DEBUG =', s.DEBUG, '| HOSTS =', s.ALLOWED_HOSTS)\""

echo "== migrate + collectstatic"
su omway -c "cd /srv/ems/app && /srv/ems/venv/bin/python manage.py migrate --noinput && /srv/ems/venv/bin/python manage.py collectstatic --noinput | tail -1"

echo "== systemd"
install -m 644 deploy/ems-gunicorn.service deploy/ems-reminders.service deploy/ems-reminders.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable -q ems-gunicorn.service ems-reminders.timer
systemctl restart ems-gunicorn.service
systemctl start ems-reminders.timer

echo "== nginx"
install -m 644 deploy/nginx-ems.conf /etc/nginx/sites-available/ems
ln -sfn /etc/nginx/sites-available/ems /etc/nginx/sites-enabled/ems
nginx -t && systemctl reload nginx

echo "== status"
systemctl is-active ems-gunicorn.service ems-reminders.timer nginx
ls -la /srv/ems/run/
free -m | sed -n 2p
