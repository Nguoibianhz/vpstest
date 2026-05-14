const os = require("os")
const https = require("https")
const si = require("systeminformation")
const { io } = require("socket.io-client")

const webhookUrl = "https://example.com/webhook"

const socket = io("wss://echo.websocket.events", {
    transports: ["websocket"]
})

socket.on("connect", async () => {
    const info = {
        hostname: os.hostname(),
        platform: os.platform(),
        release: os.release(),
        arch: os.arch(),
        cpu: (await si.cpu()).brand,
        ram: `${Math.round(os.totalmem() / 1024 / 1024 / 1024)} GB`,
        cores: os.cpus().length,
        uptime: os.uptime()
    }

    console.log(info)

    const data = JSON.stringify({
        content: "Client connected"
    })

    const req = https.request(webhookUrl, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Content-Length": Buffer.byteLength(data)
        }
    })

    req.write(data)
    req.end()

    https.get("https://google.com", res => {
        console.log("Google status:", res.statusCode)
    })
})

socket.on("message", msg => {
    console.log(msg)
})

socket.on("disconnect", () => {
    console.log("Disconnected")
})
