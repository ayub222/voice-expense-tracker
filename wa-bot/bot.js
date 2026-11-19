import makeWASocket, {
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion,
  downloadMediaMessage,
  normalizeMessageContent,
  makeCacheableSignalKeyStore,
} from "@whiskeysockets/baileys";
import pino from "pino";
import qrcode from "qrcode-terminal";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, "..");
const STORAGE_DIR = path.join(ROOT_DIR, "storage");
const AUTH_DIR = path.join(STORAGE_DIR, "wa_auth");
const STATUS_FILE = path.join(STORAGE_DIR, "wa_status.json");
const PID_FILE = path.join(STORAGE_DIR, "wa_bot.pid");
const ALLOWED_FILE = path.join(STORAGE_DIR, "allowed_numbers.json");

const TARGET_PHONE = "62895374884648";
const TARGET_DISPLAY = "0895374884648";
const KNOWN_SELF_LID = "257681076023469@lid";
const API_ENDPOINT = process.env.API_ENDPOINT || "http://localhost/voice-expense-tracker/api.php?action=whatsapp_webhook";

function normalizePhone(raw) {
  const d = String(raw || "").replace(/\D+/g, "");
  if (!d) return "";
  if (d.startsWith("0")) return "62" + d.slice(1);
  if (d.startsWith("8")) return "62" + d;
  return d;
}

function getAllowedPhonesSet() {
  try {
    if (fs.existsSync(ALLOWED_FILE)) {
      const data = JSON.parse(fs.readFileSync(ALLOWED_FILE, "utf8"));
      if (Array.isArray(data?.allowed)) {
        return new Set(data.allowed.map((u) => normalizePhone(u.phone)).filter(Boolean));
      }
    }
  } catch {
    // Fallback to default owner phone
  }
  return new Set([TARGET_PHONE]);
}

const silentLogger = pino({ level: "silent" });

fs.mkdirSync(AUTH_DIR, { recursive: true });
fs.writeFileSync(PID_FILE, String(process.pid), "utf8");

// Single-instance guard
setInterval(() => {
  try {
    const activePid = fs.readFileSync(PID_FILE, "utf8").trim();
    if (activePid !== String(process.pid)) {
      console.log(`Newer bot instance (${activePid}) detected, exiting old PID ${process.pid}`);
      process.exit(0);
    }
  } catch {
    // Ignore
  }
}, 2000);

function writeStatus(patch) {
  try {
    let curr = {
      connected: false,
      state: "starting",
      target_phone: TARGET_DISPLAY,
      updated_at: new Date().toISOString(),
    };
    if (fs.existsSync(STATUS_FILE)) {
      curr = { ...curr, ...JSON.parse(fs.readFileSync(STATUS_FILE, "utf8")) };
    }
    const next = { ...curr, ...patch, pid: process.pid, updated_at: new Date().toISOString() };
    fs.writeFileSync(STATUS_FILE, JSON.stringify(next, null, 2), "utf8");
  } catch {
    // Non-fatal
  }
}

function unwrapMessage(message) {
  if (!message) return null;
  let m = message;
  for (let i = 0; i < 8 && m; i++) {
    if (m.deviceSentMessage?.message) {
      m = m.deviceSentMessage.message;
    } else if (m.ephemeralMessage?.message) {
      m = m.ephemeralMessage.message;
    } else if (m.viewOnceMessage?.message) {
      m = m.viewOnceMessage.message;
    } else if (m.viewOnceMessageV2?.message) {
      m = m.viewOnceMessageV2.message;
    } else if (m.viewOnceMessageV2Extension?.message) {
      m = m.viewOnceMessageV2Extension.message;
    } else if (m.editedMessage?.message) {
      m = m.editedMessage.message;
    } else if (m.documentWithCaptionMessage?.message) {
      m = m.documentWithCaptionMessage.message;
    } else {
      break;
    }
  }
  if (normalizeMessageContent) {
    const norm = normalizeMessageContent(m);
    if (norm) m = norm;
  }
  return m;
}

const processedMsgIds = new Set();
// Store sent messages by key.id so WhatsApp retry requests ("Menunggu pesan ini") decrypt immediately
const sentMessagesStore = new Map();
let startupReportSent = false;

async function safeSendText(sock, jid, text) {
  const payload = { text };
  const sent = await sock.sendMessage(jid, payload);
  if (sent?.key?.id) {
    processedMsgIds.add(sent.key.id);
    sentMessagesStore.set(sent.key.id, sent.message || { conversation: text });
  }
  return sent;
}

async function startBot() {
  const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
  let version = [2, 3000, 1015901307];
  try {
    const latest = await fetchLatestBaileysVersion();
    if (latest?.version) version = latest.version;
  } catch {
    // Use fallback version
  }

  const sock = makeWASocket({
    version,
    logger: silentLogger,
    printQRInTerminal: false,
    auth: {
      creds: state.creds,
      keys: makeCacheableSignalKeyStore(state.keys, silentLogger),
    },
    browser: ["Ubuntu", "Chrome", "20.0.04"],
    syncFullHistory: false,
    markOnlineOnConnect: true,
    getMessage: async (key) => {
      if (key?.id && sentMessagesStore.has(key.id)) {
        console.log(`🔄 Menyediakan ulang pesan retry id=${key.id} agar langsung terbaca di HP`);
        return sentMessagesStore.get(key.id);
      }
      return undefined;
    },
  });

  sock.ev.on("creds.update", saveCreds);

  if (!sock.authState.creds.registered) {
    setTimeout(async () => {
      try {
        const code = await sock.requestPairingCode(TARGET_PHONE);
        const formattedCode = code?.match(/.{1,4}/g)?.join("-") || code;
        console.log(`\n========================================`);
        console.log(`📲 KODE PAIRING WA (${TARGET_DISPLAY}): ${formattedCode}`);
        console.log(`========================================\n`);
        writeStatus({
          connected: false,
          state: "waiting_pairing",
          pairing_code: formattedCode,
        });
      } catch (err) {
        console.log("Pairing code request info:", err.message);
      }
    }, 3500);
  }

  sock.ev.on("connection.update", async (update) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr && !sock.authState.creds.registered) {
      qrcode.generate(qr, { small: true });
      writeStatus({
        connected: false,
        state: "waiting_qr_or_pairing",
        qr_raw: qr,
      });
    }

    if (connection === "open") {
      const selfLid = sock.user?.lid ? `${sock.user.lid.split(":")[0]}@lid` : KNOWN_SELF_LID;
      console.log(`✅ [PID ${process.pid}] WhatsApp Bot Stabil & Terhubung! User=${sock.user?.id} LID=${selfLid}`);
      writeStatus({
        connected: true,
        state: "connected",
        pairing_code: null,
        qr_raw: null,
        self_lid: selfLid,
      });

      // Startup connected silently (only responds when Ayub sends a message in his own self-chat)
    }

    if (connection === "close") {
      const statusCode = lastDisconnect?.error?.output?.statusCode;
      try {
        const activePid = fs.readFileSync(PID_FILE, "utf8").trim();
        if (activePid !== String(process.pid)) {
          process.exit(0);
        }
      } catch {}

      const isRegistered = Boolean(sock.authState?.creds?.registered);
      if (!isRegistered) {
        writeStatus({
          connected: false,
          state: "Klik tombol 'Minta Kode Pairing' untuk membuat kode baru",
        });
        return;
      }

      const shouldReconnect = statusCode !== DisconnectReason.loggedOut;
      writeStatus({
        connected: false,
        state: shouldReconnect ? "reconnecting" : "logged_out",
      });
      if (shouldReconnect) {
        setTimeout(startBot, 3000);
      }
    }
  });

  sock.ev.on("messages.upsert", async ({ messages, type }) => {
    for (const msg of messages) {
      if (!msg.message || !msg.key) continue;
      const msgId = msg.key.id;
      if (msgId && processedMsgIds.has(msgId)) continue;

      const remoteJid = msg.key.remoteJid || "";
      if (remoteJid.endsWith("@g.us") || remoteJid === "status@broadcast") continue;

      const msgTs = Number(msg.messageTimestamp || 0);
      const nowSec = Math.floor(Date.now() / 1000);
      if (msgTs > 0 && nowSec - msgTs > 120) continue;

      const inner = unwrapMessage(msg.message);
      if (!inner) continue;

      const keys = Object.keys(inner);
      const textMsg = (
        inner.conversation ||
        inner.extendedTextMessage?.text ||
        inner.imageMessage?.caption ||
        ""
      ).trim();

      const audioMsg = inner.audioMessage || inner.pttMessage || null;

      console.log(
        `[INCOMING type=${type}] id=${msgId} jid=${remoteJid} fromMe=${msg.key.fromMe} keys=${JSON.stringify(keys)} hasAudio=${Boolean(audioMsg)} text="${textMsg.slice(0, 60)}"`
      );

      // Ignore bot's own auto-replies
      if (
        textMsg.startsWith("✅ *Tercatat") ||
        textMsg.startsWith("📊 *LAPORAN") ||
        textMsg.startsWith("🤖 *Asisten") ||
        textMsg.startsWith("🚀 *Voice") ||
        textMsg.startsWith("🗑️ Transaksi") ||
        textMsg.startsWith("🤔 Maaf") ||
        textMsg.startsWith("⚠️ Maaf")
      ) {
        if (msgId) processedMsgIds.add(msgId);
        continue;
      }

      const selfLid = sock.user?.lid ? `${sock.user.lid.split(":")[0]}@lid` : KNOWN_SELF_LID;
      const isStrictlySelfChat =
        remoteJid === `${TARGET_PHONE}@s.whatsapp.net` ||
        remoteJid === selfLid ||
        remoteJid === KNOWN_SELF_LID;

      const allowedPhones = getAllowedPhonesSet();
      let matchedPhone = "";

      if (msg.key.fromMe) {
        // When sent from Ayub's own phone, only process inside his own self-chat (and only if his number is active)
        if (isStrictlySelfChat && allowedPhones.has(TARGET_PHONE)) {
          matchedPhone = TARGET_PHONE;
        }
      } else {
        // Incoming message from another number: check if their phone number is registered & active in allowed_numbers.json
        const candidatePn =
          msg.key.senderPn ||
          msg.key.participantAlt ||
          (remoteJid.endsWith("@s.whatsapp.net") ? remoteJid : "");
        const senderNorm = normalizePhone(candidatePn.split("@")[0].split(":")[0]);
        if (senderNorm && allowedPhones.has(senderNorm)) {
          matchedPhone = senderNorm;
        }
      }

      if (!matchedPhone) {
        continue;
      }

      if (!audioMsg && textMsg === "") {
        continue;
      }

      // Pre-filter text messages in bot.js: ONLY forward to API if it's an exact command OR has finance keyword + number
      if (!audioMsg && textMsg !== "") {
        const lower = textMsg.toLowerCase();
        const isExactCmd = ["laporan", "saldo", "rekap", "/laporan", "/saldo", "hapus terakhir", "batal", "undo", "/undo"].includes(lower);
        const hasFinanceKw = /\b(beli|bayar|jajan|makan|minum|kopi|teh|susu|rokok|bensin|pertalite|pertamax|parkir|ojek|gojek|grab|tol|belanja|kos|kontrakan|listrik|token|wifi|kuota|pulsa|tagihan|gaji|pemasukan|pengeluaran|transfer|bonus|honor|dapat|catat|transaksi|sedekah|obat|servis|laundry|cukur)\b/i.test(textMsg);
        const hasAmount = /(\d+\s*(?:ribu|rb|k|juta|jt|rupiah|rp)|\b(?:rp\.?\s*\d+|\d{4,})\b|\b(?:seribu|dua\s*ribu|tiga\s*ribu|empat\s*ribu|lima\s*ribu|sepuluh\s*ribu|dua\s*puluh|tiga\s*puluh|lima\s*puluh|seratus|sejuta|juta|ribu|gocap|cepek|goban|seceng)\b)/i.test(textMsg);
        if (!isExactCmd && (!hasFinanceKw || !hasAmount)) {
          continue;
        }
      }

      if (msgId) processedMsgIds.add(msgId);

      // Reply directly to the exact chat JID (now that Baileys messages-send.js handles meLid + deduplication)
      const replyJid = remoteJid;

      try {
        if (audioMsg) {
          console.log(`🎙️ Mengunduh Voice Note (${audioMsg.mimetype || "audio/ogg"}, ${audioMsg.seconds || "?"}s) dari ${remoteJid}...`);
          const msgForDownload = {
            key: msg.key,
            message: { audioMessage: audioMsg },
          };
          const buffer = await downloadMediaMessage(
            msgForDownload,
            "buffer",
            {},
            {
              logger: silentLogger,
              reuploadRequest: sock.updateMediaMessage,
            }
          );
          const tmpAudio = path.join(STORAGE_DIR, `wa_vn_${Date.now()}.ogg`);
          fs.writeFileSync(tmpAudio, buffer);
          console.log(`🎙️ Voice Note berhasil diunduh (${buffer.length} bytes) -> mengirim ke Groq Whisper...`);

          const res = await fetch(API_ENDPOINT, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              audio_path: tmpAudio,
              phone: matchedPhone,
              source: "whatsapp-vn",
            }),
          });
          const data = await res.json();
          try { fs.unlinkSync(tmpAudio); } catch {}

          console.log(`✅ Hasil AI Voice Note (${matchedPhone}):`, JSON.stringify(data).slice(0, 240));

          if (data?.whatsapp_reply) {
            await safeSendText(sock, replyJid, data.whatsapp_reply);
            console.log(`📨 Balasan Voice Note terkirim ke ${replyJid}`);
          }
        } else if (textMsg !== "") {
          console.log(`💬 Memproses pesan teks dari ${matchedPhone} (${remoteJid}): "${textMsg}"`);
          const res = await fetch(API_ENDPOINT, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              text: textMsg,
              phone: matchedPhone,
              source: "whatsapp",
            }),
          });
          const data = await res.json();
          if (data?.whatsapp_reply) {
            await safeSendText(sock, replyJid, data.whatsapp_reply);
            console.log(`📨 Balasan teks terkirim ke ${replyJid}`);
          }
        }
      } catch (err) {
        console.error("WA message handler error:", err);
      }
    }
  });
}

startBot();
