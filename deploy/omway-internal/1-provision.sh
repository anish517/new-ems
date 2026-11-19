#!/usr/bin/env bash
# Run as root on omway-internal, ONCE, before any code is uploaded.
# Creates the layout, the PostgreSQL role/database, and .env with generated secrets.
set -euo pipefail

if [ -e /srv/ems/app/.env ]; then
  echo "refusing: /srv/ems/app/.env already exists — this host is already provisioned"; exit 3
fi

echo "== packages"
dpkg -s python3.12-venv >/dev/null 2>&1 || apt-get install -y -q python3.12-venv

echo "== layout (owned by omway, like the Node apps in /srv)"
install -d -o omway -g omway -m 755 \
  /srv/ems /srv/ems/app /srv/ems/deploy /srv/ems/www /srv/ems/www/app \
  /srv/ems/media /srv/ems/static /srv/ems/logs /srv/ems/run

echo "== postgres role + database"
PW=$(openssl rand -hex 24)
if su postgres -c "psql -tAc \"select 1 from pg_roles where rolname='ems'\"" | grep -q 1; then
  echo "refusing: role 'ems' already exists"; exit 3
fi
su postgres -c "psql -v ON_ERROR_STOP=1 -q" <<SQL
CREATE ROLE ems LOGIN PASSWORD '$PW';
CREATE DATABASE ems OWNER ems ENCODING 'UTF8' TEMPLATE template0;
ALTER ROLE ems SET client_encoding TO 'utf8';
ALTER ROLE ems SET default_transaction_isolation TO 'read committed';
ALTER ROLE ems SET timezone TO 'Asia/Kathmandu';
SQL

echo "== .env (secrets generated on this host, never printed)"
SK=$(openssl rand -hex 32)
umask 077
cat > /srv/ems/app/.env <<ENV
SECRET_KEY=$SK
DEBUG=False
ALLOWED_HOSTS=ems.omwaytechnologies.com,127.0.0.1,localhost
CSRF_TRUSTED_ORIGINS=https://ems.omwaytechnologies.com
DATABASE_URL=postgres://ems:$PW@127.0.0.1:5432/ems
STATIC_ROOT=/srv/ems/static
MEDIA_ROOT=/srv/ems/media
FRONTEND_URL=https://ems.omwaytechnologies.com/app/
# Copy these two from the cPanel host's Python Selector env (see 2-install.sh notes).
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=
ENV
chown omway:omway /srv/ems/app/.env

echo "== verify: omway connects with the generated credentials"
su omway -c "PGPASSWORD='$PW' psql -h 127.0.0.1 -U ems -d ems -tAc \"select current_user || ' @ ' || current_database() || ' | tz=' || current_setting('timezone')\""
echo "== done. Next: upload code to /srv/ems/app and deploy/ to /srv/ems/deploy, then run 2-install.sh"
