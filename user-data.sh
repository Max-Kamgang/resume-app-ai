#!/bin/bash
set -x

# =========================
# SYSTEM SETUP
# =========================
dnf update -y
# AL2023 livre Python 3.9 comme python3 ; le SDK google-genai exige >= 3.10,
# d'ou l'installation explicite de python3.11.
dnf install -y python3.11 python3.11-pip nginx postgresql15 gcc git

# =========================
# SSM AGENT
# =========================
dnf install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# =========================
# PYTHON DEPENDENCIES
# google-genai : le SDK officiel Gemini.
# =========================
python3.11 -m pip install --upgrade pip
python3.11 -m pip install flask gunicorn boto3 psycopg2-binary google-genai

# =========================
# APP + FRONTEND DEPLOYMENT
# app.py, index.html and jobs.json live in S3 (published by Terraform),
# not inside user-data — user-data is capped at 16 KB and this keeps the
# application editable without replacing the instances.
# =========================
mkdir -p /opt/rp-app

cat > /usr/local/bin/rp-sync.sh <<'SYNC'
#!/bin/bash
# Pull the current app + frontend from S3; restart the app only if its code changed.
set -u
BUCKET="__ASSETS_BUCKET__"
APP=/opt/rp-app/app.py
BEFORE=$(sha256sum "$APP" 2>/dev/null | cut -d' ' -f1)

aws s3 cp "s3://$BUCKET/app/app.py" "$APP.new" --quiet && mv "$APP.new" "$APP"
aws s3 cp "s3://$BUCKET/index.html" /usr/share/nginx/html/index.html.new --quiet \
  && mv /usr/share/nginx/html/index.html.new /usr/share/nginx/html/index.html

AFTER=$(sha256sum "$APP" 2>/dev/null | cut -d' ' -f1)
if [ -n "$AFTER" ] && [ "$BEFORE" != "$AFTER" ]; then
  systemctl restart rp-app
fi
SYNC

sed -i "s|__ASSETS_BUCKET__|${assets_bucket}|g" /usr/local/bin/rp-sync.sh
chmod +x /usr/local/bin/rp-sync.sh
mkdir -p /usr/share/nginx/html
/usr/local/bin/rp-sync.sh

# =========================
# CLE API GEMINI
#
# Ecrite dans un fichier .env lu par systemd (EnvironmentFile), et non dans
# l'unite de service : le fichier est en 600 root, donc invisible des autres
# utilisateurs, et il ne part jamais dans S3 avec le code de l'application.
# =========================
umask 077
cat > /opt/rp-app/.env <<ENVFILE
GEMINI_API_KEY=${gemini_api_key}
ENVFILE
chmod 600 /opt/rp-app/.env
umask 022

# =========================
# SYSTEMD SERVICE (gunicorn)
# =========================
cat > /etc/systemd/system/rp-app.service <<SERVICE
[Unit]
Description=Resume Portal Flask App
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/opt/rp-app
Environment=RESUME_BUCKET=${resume_bucket}
Environment=ASSETS_BUCKET=${assets_bucket}
Environment=JOBS_KEY=${jobs_key}
Environment=DB_SECRET_NAME=${db_secret_name}
Environment=SENDER_EMAIL=${sender_email}
Environment=SENDER_NAME=${sender_name}
Environment=HR_EMAIL=${hr_email}
Environment=SES_CONFIG_SET=${ses_config_set}
Environment=GEMINI_MODEL=${gemini_model}
Environment=GEMINI_FALLBACK_MODEL=${gemini_fallback_model}
# La cle API vit dans un fichier separe, lu par systemd au demarrage.
EnvironmentFile=/opt/rp-app/.env
Environment=MATCH_THRESHOLD=${match_threshold}
Environment=INTERVIEW_BOOKING_URL=${booking_url}
Environment=AWS_REGION=${aws_region}
Environment=AWS_DEFAULT_REGION=${aws_region}
ExecStart=/usr/local/bin/gunicorn --workers 2 --threads 8 --timeout 180 --bind 127.0.0.1:5000 --access-logfile - --error-logfile - app:app
Restart=always
RestartSec=5
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

# =========================
# SYNC TIMER — picks up app/frontend changes every 2 minutes
# =========================
cat > /etc/systemd/system/rp-sync.service <<'SYNCSVC'
[Unit]
Description=Sync ResumePortal app and frontend from S3

[Service]
Type=oneshot
ExecStart=/usr/local/bin/rp-sync.sh
SYNCSVC

cat > /etc/systemd/system/rp-sync.timer <<'SYNCTIMER'
[Unit]
Description=Periodic ResumePortal asset sync

[Timer]
OnBootSec=3min
OnUnitActiveSec=2min

[Install]
WantedBy=timers.target
SYNCTIMER

# =========================
# NGINX CONFIG
# nginx serves the static form, Flask handles the API — same origin, no CORS.
# =========================
cat > /etc/nginx/conf.d/rp.conf <<'NGINX'
server {
    listen 80;
    server_name _;

    client_max_body_size 20M;
    root /usr/share/nginx/html;

    location = / {
        add_header Cache-Control "no-cache";
        try_files /index.html =404;
    }

    location ~ ^/(submit|jobs|health|application/) {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
        proxy_connect_timeout 120s;
        proxy_send_timeout 120s;
    }

    location / {
        try_files $uri /index.html;
    }
}
NGINX

rm -f /etc/nginx/conf.d/default.conf || true

# =========================
# NGINX MAIN CONFIG
# =========================
tee /etc/nginx/nginx.conf > /dev/null <<'NGINXMAIN'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile            on;
    tcp_nopush          on;
    keepalive_timeout   65;
    types_hash_max_size 4096;
    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;
    include /etc/nginx/conf.d/*.conf;
}
NGINXMAIN

# =========================
# START SERVICES
# =========================
systemctl daemon-reload
systemctl enable rp-app nginx amazon-ssm-agent rp-sync.timer
systemctl restart rp-app nginx amazon-ssm-agent
systemctl start rp-sync.timer

# =========================
# VERIFY SSM AGENT
# =========================
for i in {1..6}; do
  if systemctl is-active --quiet amazon-ssm-agent; then
    echo "SSM agent active on attempt $i"
    break
  fi
  echo "SSM agent not ready, retrying in 10s... ($i/6)"
  sleep 10
done

# =========================
# UPLOAD BOOT LOG TO S3
# =========================
sleep 5
aws s3 cp /var/log/cloud-init-output.log s3://${resume_bucket}/logs/cloud-init-$(hostname).log || true
