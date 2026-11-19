<?php
declare(strict_types=1);
require_once __DIR__ . '/config.php';
?>
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Voice Expense Tracker AI — Ayub</title>
  <style>
    :root {
      --bg-0: #0f1117;
      --bg-1: #171a23;
      --bg-2: #1f2430;
      --border: rgba(255, 255, 255, 0.08);
      --cyan: #5eead4;
      --blue: #38bdf8;
      --violet: #a78bfa;
      --green: #10b981;
      --red: #f43f5e;
      --amber: #f59e0b;
      --text: #f1f5f9;
      --muted: #94a3b8;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: radial-gradient(circle at 20% 0%, #1a2130 0%, var(--bg-0) 60%);
      color: var(--text);
      font-family: "Segoe UI", -apple-system, BlinkMacSystemFont, Roboto, sans-serif;
      min-height: 100vh;
      padding: 24px 16px 48px;
    }
    .container {
      max-width: 1180px;
      margin: 0 auto;
      display: flex;
      flex-direction: column;
      gap: 22px;
    }
    /* Header */
    .header {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      justify-content: space-between;
      gap: 14px;
      padding: 18px 22px;
      background: rgba(23, 26, 35, 0.85);
      border: 1px solid var(--border);
      border-radius: 16px;
      backdrop-filter: blur(10px);
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 14px;
    }
    .orb {
      width: 42px;
      height: 42px;
      border-radius: 50%;
      background: radial-gradient(circle at 35% 30%, #e0f2fe, var(--cyan) 35%, #0284c7 75%);
      box-shadow: 0 0 22px rgba(94, 234, 212, 0.45);
      display: grid;
      place-items: center;
      font-size: 20px;
    }
    .brand h1 {
      font-size: 19px;
      font-weight: 700;
      letter-spacing: 0.02em;
    }
    .brand p {
      font-size: 12px;
      color: var(--muted);
    }
    .badges {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 12px;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid var(--border);
      font-size: 12px;
      color: #cbd5e1;
    }
    .dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--green);
      box-shadow: 0 0 8px var(--green);
    }
    .dot.amber { background: var(--amber); box-shadow: 0 0 8px var(--amber); }

    /* AI Voice & Text Bar */
    .voice-box {
      background: linear-gradient(135deg, rgba(31, 36, 48, 0.95), rgba(23, 26, 35, 0.95));
      border: 1px solid rgba(94, 234, 212, 0.28);
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3), 0 0 24px rgba(94, 234, 212, 0.08);
      border-radius: 16px;
      padding: 20px 22px;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }
    .voice-row {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
    }
    .voice-input {
      flex: 1;
      min-width: 240px;
      background: rgba(15, 17, 23, 0.85);
      border: 1px solid var(--border);
      color: var(--text);
      padding: 13px 16px;
      border-radius: 12px;
      font-size: 14px;
      outline: none;
      transition: border-color 0.2s;
    }
    .voice-input:focus {
      border-color: var(--cyan);
    }
    .btn {
      border: none;
      border-radius: 12px;
      padding: 12px 18px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      transition: transform 0.15s, opacity 0.2s, box-shadow 0.2s;
    }
    .btn:active { transform: scale(0.98); }
    .btn-primary {
      background: linear-gradient(135deg, #14b8a6, #0284c7);
      color: #fff;
      box-shadow: 0 4px 16px rgba(20, 184, 166, 0.35);
    }
    .btn-mic {
      background: rgba(244, 63, 94, 0.15);
      color: #fda4af;
      border: 1px solid rgba(244, 63, 94, 0.4);
    }
    .btn-mic.recording {
      background: var(--red);
      color: #fff;
      animation: pulseMic 1.2s infinite;
    }
    @keyframes pulseMic {
      0%, 100% { box-shadow: 0 0 0 0 rgba(244, 63, 94, 0.6); }
      50% { box-shadow: 0 0 0 12px rgba(244, 63, 94, 0); }
    }
    .chips {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      align-items: center;
    }
    .chip-label {
      font-size: 12px;
      color: var(--muted);
    }
    .chip {
      font-size: 12px;
      padding: 5px 11px;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--border);
      color: #cbd5e1;
      cursor: pointer;
      transition: all 0.15s;
    }
    .chip:hover {
      border-color: var(--cyan);
      color: var(--cyan);
    }
    .status-toast {
      font-size: 13px;
      padding: 10px 14px;
      border-radius: 10px;
      background: rgba(16, 185, 129, 0.12);
      border: 1px solid rgba(16, 185, 129, 0.35);
      color: #6ee7b7;
      display: none;
    }

    /* Summary Cards */
    .cards {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 16px;
    }
    .card {
      background: var(--bg-1);
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 18px 20px;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .card-label {
      font-size: 12px;
      color: var(--muted);
      text-transform: uppercase;
      letter-spacing: 0.06em;
    }
    .card-val {
      font-size: 24px;
      font-weight: 700;
      font-variant-numeric: tabular-nums;
    }
    .val-cyan { color: var(--cyan); }
    .val-red { color: #fb7185; }
    .val-amber { color: #fbbf24; }
    .val-green { color: #34d399; }

    /* Main Grid */
    .grid-2 {
      display: grid;
      grid-template-columns: 1.5fr 1fr;
      gap: 20px;
    }
    @media (max-width: 900px) {
      .grid-2 { grid-template-columns: 1fr; }
    }
    .panel {
      background: var(--bg-1);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 20px;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    .panel-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-bottom: 1px solid var(--border);
      padding-bottom: 12px;
    }
    .panel-title {
      font-size: 15px;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    /* Transactions Table */
    .tx-list {
      display: flex;
      flex-direction: column;
      gap: 10px;
      max-height: 460px;
      overflow-y: auto;
    }
    .tx-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 14px;
      border-radius: 12px;
      background: var(--bg-2);
      border: 1px solid rgba(255, 255, 255, 0.04);
      gap: 12px;
    }
    .tx-left {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .tx-icon {
      width: 38px;
      height: 38px;
      border-radius: 10px;
      background: rgba(255, 255, 255, 0.05);
      display: grid;
      place-items: center;
      font-size: 18px;
    }
    .tx-desc {
      font-size: 14px;
      font-weight: 600;
    }
    .tx-meta {
      font-size: 11px;
      color: var(--muted);
    }
    .tx-right {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .tx-amount {
      font-size: 14px;
      font-weight: 700;
      font-variant-numeric: tabular-nums;
    }
    .tx-amount.expense { color: #fb7185; }
    .tx-amount.income { color: #34d399; }
    .btn-del {
      background: transparent;
      border: none;
      color: var(--muted);
      cursor: pointer;
      font-size: 14px;
      padding: 4px;
    }
    .btn-del:hover { color: var(--red); }

    /* Category Bars */
    .cat-list {
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    .cat-row {
      display: flex;
      flex-direction: column;
      gap: 5px;
    }
    .cat-top {
      display: flex;
      justify-content: space-between;
      font-size: 13px;
    }
    .bar-bg {
      height: 7px;
      background: rgba(255, 255, 255, 0.06);
      border-radius: 999px;
      overflow: hidden;
    }
    .bar-fill {
      height: 100%;
      background: linear-gradient(90deg, var(--cyan), var(--blue));
      border-radius: 999px;
    }

    /* WhatsApp Bot & Simulator Box */
    .wa-chat {
      background: #0b141a;
      border: 1px solid rgba(16, 185, 129, 0.25);
      border-radius: 12px;
      padding: 14px;
      display: flex;
      flex-direction: column;
      gap: 10px;
      max-height: 260px;
      overflow-y: auto;
      font-size: 13px;
    }
    .wa-bubble {
      padding: 9px 12px;
      border-radius: 10px;
      max-width: 88%;
      white-space: pre-wrap;
      line-height: 1.45;
    }
    .wa-bubble.user {
      align-self: flex-end;
      background: #005c4b;
      color: #e9edef;
    }
    .wa-bubble.bot {
      align-self: flex-start;
      background: #202c33;
      color: #e9edef;
    }
    .pairing-box {
      padding: 12px 14px;
      border-radius: 10px;
      background: rgba(56, 189, 248, 0.1);
      border: 1px solid rgba(56, 189, 248, 0.3);
      font-size: 12px;
      line-height: 1.5;
      color: #bae6fd;
    }
    .pairing-code {
      font-size: 20px;
      font-weight: 700;
      letter-spacing: 0.18em;
      color: var(--cyan);
      margin-top: 4px;
    }
  </style>
</head>
<body>
  <div class="container">
    <!-- Top Header -->
    <header class="header">
      <div class="brand">
        <div class="orb">🎙️</div>
        <div>
          <h1>Voice Expense Tracker AI</h1>
          <p>Asisten Pencatat Keuangan Suara & WhatsApp — Ayub (<?= htmlspecialchars(DEFAULT_WA_DISPLAY) ?>)</p>
        </div>
      </div>
      <div class="badges">
        <span class="badge"><span class="dot"></span>Groq Whisper v3 Turbo + GPT-OSS 120B</span>
        <span class="badge"><span class="dot" id="waDot"></span><span id="waBadgeText">WA Target: <?= htmlspecialchars(DEFAULT_WA_DISPLAY) ?></span></span>
      </div>
    </header>

    <!-- AI Voice & Smart Text Input -->
    <section class="voice-box">
      <div class="voice-row">
        <button type="button" class="btn btn-mic" id="btnMic" title="Tekan untuk bicara 3 detik">
          🎙️ <span id="micLabel">Rekam Suara</span>
        </button>
        <input
          type="text"
          id="smartInput"
          class="voice-input"
          placeholder="Ketik atau rekam suara, misal: 'Beli bensin 30 ribu sama kopi 18 ribu'..."
        />
        <button type="button" class="btn btn-primary" id="btnSubmit">
          ⚡ Catat dengan AI
        </button>
      </div>
      <div class="chips">
        <span class="chip-label">Coba cepat:</span>
        <span class="chip" onclick="fillSample('Beli bensin 30 ribu sama kopi 18 ribu')">⛽ Beli bensin 30 ribu sama kopi 18 ribu</span>
        <span class="chip" onclick="fillSample('Makan siang nasi padang 25rb dan parkir 3rb')">🍛 Makan siang 25rb & parkir 3rb</span>
        <span class="chip" onclick="fillSample('Dapat transfer bonus proyek 1.5 juta')">💰 Dapat bonus proyek 1.5 juta</span>
      </div>
      <div class="status-toast" id="toast"></div>
    </section>

    <!-- 4 Financial Summary Cards -->
    <section class="cards">
      <div class="card">
        <span class="card-label">🏦 Saldo Bersih</span>
        <span class="card-val val-cyan" id="valBalance">Rp 0</span>
      </div>
      <div class="card">
        <span class="card-label">🔥 Pengeluaran Hari Ini</span>
        <span class="card-val val-amber" id="valToday">Rp 0</span>
      </div>
      <div class="card">
        <span class="card-label">💸 Total Pengeluaran Bulan Ini</span>
        <span class="card-val val-red" id="valMonth">Rp 0</span>
      </div>
      <div class="card">
        <span class="card-label">💰 Total Pemasukan</span>
        <span class="card-val val-green" id="valIncome">Rp 0</span>
      </div>
    </section>

    <!-- Main 2-Column Content -->
    <section class="grid-2">
      <!-- Left: Recent Transactions -->
      <div class="panel">
        <div class="panel-head">
          <div class="panel-title">🧾 Riwayat Transaksi Terbaru</div>
          <span style="font-size:12px;color:var(--muted)" id="txCountLabel">0 transaksi</span>
        </div>
        <div class="tx-list" id="txList"></div>
      </div>

      <!-- Right: Category Breakdown + WhatsApp Bot Panel -->
      <div style="display:flex;flex-direction:column;gap:20px;">
        <div class="panel">
          <div class="panel-head">
            <div class="panel-title">📊 Distribusi Kategori</div>
          </div>
          <div class="cat-list" id="catList"></div>
        </div>

        <div class="panel">
          <div class="panel-head">
            <div class="panel-title">📱 Pengaturan Nomor WhatsApp Terdaftar</div>
            <span style="font-size:12px;color:var(--muted)" id="userCountLabel">1 nomor</span>
          </div>
          <div class="voice-row">
            <input type="text" id="newUserName" class="voice-input" style="padding:9px 12px;font-size:13px;min-width:110px;flex:0.8;" placeholder="Nama (mis: Istri / Partner)" />
            <input type="text" id="newUserPhone" class="voice-input" style="padding:9px 12px;font-size:13px;min-width:130px;flex:1;" placeholder="Nomor WA (08xxxx)" />
            <button type="button" class="btn btn-primary" style="padding:9px 14px;" onclick="addAllowedUser()">+ Tambah</button>
          </div>
          <div id="allowedUsersList" style="display:flex;flex-direction:column;gap:8px;max-height:190px;overflow-y:auto;"></div>
        </div>

        <div class="panel">
          <div class="panel-head">
            <div class="panel-title">💬 Bot WhatsApp Gratis (<?= htmlspecialchars(DEFAULT_WA_DISPLAY) ?>)</div>
            <button type="button" class="btn btn-primary" style="padding:6px 12px;font-size:12px;" onclick="requestNewPairingCode()">📲 Minta Kode Pairing</button>
          </div>
          <div class="pairing-box" id="waInfoBox">
            <strong>Status Bot WA:</strong> <span id="waStateLabel">Menunggu / Siap</span><br/>
            <span id="waInstruction">Kirim pesan teks atau Voice Note dari WA maupun simulator di bawah:</span>
            <div class="pairing-code" id="waPairingCode" style="display:none;"></div>
          </div>
          <div class="wa-chat" id="waChat">
            <div class="wa-bubble bot">Halo Ayub! 👋 Kirim Voice Note atau ketik pengeluaranmu (contoh: "Beli bensin 30 ribu sama kopi 18 ribu" atau ketik "laporan").</div>
          </div>
          <div class="voice-row">
            <input type="text" id="waInput" class="voice-input" style="padding:9px 12px;font-size:13px;" placeholder="Simulasi chat WA dari 0895374884648..." />
            <button type="button" class="btn btn-primary" style="padding:9px 14px;" onclick="sendWaSim()">Kirim WA</button>
          </div>
        </div>
      </div>
    </section>
  </div>

  <script>
    const API_URL = "api.php";

    function showToast(msg, isError = false) {
      const el = document.getElementById("toast");
      el.style.display = "block";
      el.style.background = isError ? "rgba(244, 63, 94, 0.14)" : "rgba(16, 185, 129, 0.14)";
      el.style.borderColor = isError ? "rgba(244, 63, 94, 0.4)" : "rgba(16, 185, 129, 0.4)";
      el.style.color = isError ? "#fda4af" : "#6ee7b7";
      el.textContent = msg;
      setTimeout(() => { el.style.display = "none"; }, 6000);
    }

    function fillSample(text) {
      document.getElementById("smartInput").value = text;
      submitSmartText(text, "web");
    }

    async function loadSummary() {
      try {
        const res = await fetch(`${API_URL}?action=summary`);
        const json = await res.json();
        if (!json.ok) return;
        renderSummary(json.data);
        renderWaStatus(json.wa_bot_status);
        renderAllowedUsers(json.allowed_users || []);
      } catch (e) {
        console.error(e);
      }
    }

    function renderWaStatus(st) {
      if (!st) return;
      const stateEl = document.getElementById("waStateLabel");
      const codeEl = document.getElementById("waPairingCode");
      const instEl = document.getElementById("waInstruction");
      const dotEl = document.getElementById("waDot");

      if (st.connected) {
        stateEl.textContent = "Terhubung Aktif ✅ (" + (st.target_phone || "0895374884648") + ")";
        dotEl.className = "dot";
        codeEl.style.display = "none";
        instEl.textContent = "Bot WhatsApp aktif! Kamu bisa kirim Voice Note atau chat langsung di WA.";
      } else if (st.pairing_code) {
        stateEl.textContent = "Menunggu Tautan Perangkat (Pairing Code)";
        dotEl.className = "dot amber";
        codeEl.style.display = "block";
        codeEl.textContent = st.pairing_code;
        instEl.textContent = "Di WA HP (0895374884648): Buka Perangkat Tertaut ➔ Tautkan Perangkat ➔ Tautkan dengan Nomor Telepon, lalu masukkan kode ini:";
      } else {
        stateEl.textContent = st.state || "Webhook Aktif";
      }
    }

    function renderSummary(d) {
      if (!d) return;
      document.getElementById("valBalance").textContent = d.balance_formatted;
      document.getElementById("valToday").textContent = d.today_expense_formatted;
      document.getElementById("valMonth").textContent = d.month_expense_formatted;
      document.getElementById("valIncome").textContent = d.total_income_formatted;

      // Render recent transactions
      const txs = d.recent_transactions || [];
      document.getElementById("txCountLabel").textContent = `${txs.length} transaksi`;
      const txList = document.getElementById("txList");
      if (txs.length === 0) {
        txList.innerHTML = `<div style="color:var(--muted);font-size:13px;padding:12px;">Belum ada transaksi. Coba klik salah satu contoh di atas atau rekam suara!</div>`;
      } else {
        txList.innerHTML = txs.map(t => `
          <div class="tx-item">
            <div class="tx-left">
              <div class="tx-icon">${t.category_icon || '💸'}</div>
              <div>
                <div class="tx-desc">${escapeHtml(t.description)}</div>
                <div class="tx-meta">${escapeHtml(t.category_name)} • ${t.transaction_date} • oleh <strong>${escapeHtml(t.user_name || 'Ayub')}</strong> (${t.source.toUpperCase()})</div>
              </div>
            </div>
            <div class="tx-right">
              <span class="tx-amount ${t.type}">${t.type === 'income' ? '+' : '-'}${t.amount_formatted}</span>
              <button class="btn-del" title="Hapus" onclick="deleteTx(${t.id})">✕</button>
            </div>
          </div>
        `).join("");
      }

      // Render category breakdown
      const cats = d.by_category || [];
      const catList = document.getElementById("catList");
      const maxTotal = cats.reduce((m, c) => Math.max(m, Number(c.total || 0)), 1);
      if (cats.length === 0) {
        catList.innerHTML = `<div style="color:var(--muted);font-size:13px;">Belum ada data kategori.</div>`;
      } else {
        catList.innerHTML = cats.map(c => {
          const pct = Math.min(100, Math.round((Number(c.total) / maxTotal) * 100));
          const formatted = "Rp " + Number(c.total).toLocaleString("id-ID");
          return `
            <div class="cat-row">
              <div class="cat-top">
                <span>${c.icon} ${escapeHtml(c.name)} <small style="color:var(--muted)">(${c.tx_count}x)</small></span>
                <strong>${formatted}</strong>
              </div>
              <div class="bar-bg">
                <div class="bar-fill" style="width:${pct}%;background:${c.color || 'var(--cyan)'}"></div>
              </div>
            </div>
          `;
        }).join("");
      }
    }

    async function submitSmartText(text, source = "web") {
      const trimmed = (text || "").trim();
      if (!trimmed) return;
      const btn = document.getElementById("btnSubmit");
      btn.disabled = true;
      btn.textContent = "⏳ Memproses AI...";
      try {
        const res = await fetch(`${API_URL}?action=smart_entry`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ text: trimmed, source, phone: "0895374884648" }),
        });
        const json = await res.json();
        if (json.ok) {
          document.getElementById("smartInput").value = "";
          if (json.saved_transactions) {
            showToast(`✅ Berhasil mencatat ${json.saved_transactions.length} transaksi (via ${json.ai_provider}/${json.ai_model})`);
          } else if (json.whatsapp_reply) {
            showToast(json.whatsapp_reply);
          }
          if (json.summary) renderSummary(json.summary);
        } else {
          showToast(json.error || "Gagal memproses transaksi.", true);
        }
      } catch (e) {
        showToast("Error jaringan: " + e.message, true);
      } finally {
        btn.disabled = false;
        btn.textContent = "⚡ Catat dengan AI";
      }
    }

    async function sendWaSim() {
      const inp = document.getElementById("waInput");
      const text = inp.value.trim();
      if (!text) return;
      inp.value = "";

      const chat = document.getElementById("waChat");
      chat.innerHTML += `<div class="wa-bubble user">${escapeHtml(text)}</div>`;
      chat.scrollTop = chat.scrollHeight;

      try {
        const res = await fetch(`${API_URL}?action=whatsapp_webhook`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ text, source: "whatsapp", phone: "0895374884648" }),
        });
        const json = await res.json();
        const reply = json.whatsapp_reply || json.error || "Selesai.";
        chat.innerHTML += `<div class="wa-bubble bot">${escapeHtml(reply)}</div>`;
        chat.scrollTop = chat.scrollHeight;
        if (json.summary) renderSummary(json.summary);
      } catch (e) {
        chat.innerHTML += `<div class="wa-bubble bot">Error: ${escapeHtml(e.message)}</div>`;
      }
    }

    function renderAllowedUsers(users) {
      const box = document.getElementById("allowedUsersList");
      const countEl = document.getElementById("userCountLabel");
      if (!box) return;
      countEl.textContent = `${users.length} nomor`;
      if (users.length === 0) {
        box.innerHTML = `<div style="color:var(--muted);font-size:12px;">Belum ada nomor terdaftar.</div>`;
        return;
      }
      box.innerHTML = users.map(u => {
        const active = Boolean(u.is_active);
        const badgeBg = active ? "rgba(16, 185, 129, 0.16)" : "rgba(148, 163, 184, 0.14)";
        const badgeColor = active ? "#34d399" : "#94a3b8";
        const badgeText = active ? "Aktif ✅" : "Nonaktif ⏸️";
        return `
          <div class="tx-item" style="padding:9px 12px;">
            <div class="tx-left">
              <div class="tx-icon" style="width:32px;height:32px;font-size:15px;">📱</div>
              <div>
                <div class="tx-desc" style="font-size:13px;">${escapeHtml(u.name)}</div>
                <div class="tx-meta">${escapeHtml(u.whatsapp_display || u.whatsapp_number)}</div>
              </div>
            </div>
            <div class="tx-right" style="gap:8px;">
              <button type="button" onclick="toggleAllowedUser(${u.id})" style="background:${badgeBg};color:${badgeColor};border:1px solid ${badgeColor};border-radius:999px;padding:4px 10px;font-size:11px;cursor:pointer;font-weight:600;">
                ${badgeText}
              </button>
              ${u.id !== 1 ? `<button class="btn-del" title="Hapus Nomor" onclick="deleteAllowedUser(${u.id})">✕</button>` : ``}
            </div>
          </div>
        `;
      }).join("");
    }

    async function addAllowedUser() {
      const nameEl = document.getElementById("newUserName");
      const phoneEl = document.getElementById("newUserPhone");
      const name = nameEl.value.trim();
      const phone = phoneEl.value.trim();
      if (!name || !phone) {
        showToast("Isi Nama dan Nomor WhatsApp terlebih dahulu.", true);
        return;
      }
      try {
        const res = await fetch(`${API_URL}?action=add_user`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ name, phone }),
        });
        const json = await res.json();
        if (json.ok) {
          nameEl.value = "";
          phoneEl.value = "";
          showToast(json.message || "Nomor berhasil ditambahkan!");
          renderAllowedUsers(json.allowed_users || []);
        } else {
          showToast(json.error || "Gagal menambah nomor.", true);
        }
      } catch (e) {
        showToast("Error: " + e.message, true);
      }
    }

    async function toggleAllowedUser(id) {
      try {
        const res = await fetch(`${API_URL}?action=toggle_user`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ id }),
        });
        const json = await res.json();
        if (json.ok) {
          renderAllowedUsers(json.allowed_users || []);
          showToast("Status izin nomor diperbarui.");
        }
      } catch (e) {
        console.error(e);
      }
    }

    async function deleteAllowedUser(id) {
      try {
        const res = await fetch(`${API_URL}?action=delete_user`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ id }),
        });
        const json = await res.json();
        if (json.ok) {
          renderAllowedUsers(json.allowed_users || []);
          showToast("Nomor berhasil dihapus dari daftar.");
        } else {
          showToast(json.error || "Gagal menghapus nomor.", true);
        }
      } catch (e) {
        console.error(e);
      }
    }

    async function requestNewPairingCode() {
      showToast("📲 Meminta kode pairing WhatsApp baru untuk 0895374884648 (tunggu ~4 detik)...");
      document.getElementById("waStateLabel").textContent = "Meminta Kode Pairing ke WhatsApp...";
      try {
        await fetch(`${API_URL}?action=start_wa_bot`, { method: "POST" });
        setTimeout(loadSummary, 4500);
      } catch (e) {
        showToast("Gagal menjalankan bot WA: " + e.message, true);
      }
    }

    async function deleteTx(id) {
      try {
        const res = await fetch(`${API_URL}?action=delete&id=${id}`, { method: "POST" });
        const json = await res.json();
        if (json.ok && json.summary) renderSummary(json.summary);
      } catch (e) {
        console.error(e);
      }
    }

    // === Browser Voice Recorder -> Groq Whisper Large v3 Turbo ===
    let mediaRecorder = null;
    let audioChunks = [];
    const btnMic = document.getElementById("btnMic");
    const micLabel = document.getElementById("micLabel");

    btnMic.addEventListener("click", async () => {
      if (mediaRecorder && mediaRecorder.state === "recording") {
        mediaRecorder.stop();
        return;
      }
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        audioChunks = [];
        mediaRecorder = new MediaRecorder(stream);
        mediaRecorder.ondataavailable = (e) => {
          if (e.data.size > 0) audioChunks.push(e.data);
        };
        mediaRecorder.onstop = async () => {
          btnMic.classList.remove("recording");
          micLabel.textContent = "Transkrip Whisper...";
          stream.getTracks().forEach(t => t.stop());

          const blob = new Blob(audioChunks, { type: "audio/webm" });
          const form = new FormData();
          form.append("audio", blob, "voice.webm");
          form.append("source", "voice-web");
          form.append("phone", "0895374884648");

          try {
            const res = await fetch(`${API_URL}?action=smart_entry`, {
              method: "POST",
              body: form,
            });
            const json = await res.json();
            if (json.ok) {
              showToast(`🎙️ "${json.transcribed_text}" ➔ Tercatat ${(json.saved_transactions || []).length} transaksi!`);
              if (json.summary) renderSummary(json.summary);
            } else {
              showToast(json.error || "Gagal mengenali suara.", true);
            }
          } catch (err) {
            showToast("Gagal mengirim suara: " + err.message, true);
          } finally {
            micLabel.textContent = "Rekam Suara";
          }
        };

        mediaRecorder.start();
        btnMic.classList.add("recording");
        micLabel.textContent = "Stop & Kirim (Bicara sekarang...)";
      } catch (err) {
        showToast("Izin mikrofon belum aktif di browser: " + err.message, true);
      }
    });

    document.getElementById("btnSubmit").addEventListener("click", () => {
      submitSmartText(document.getElementById("smartInput").value, "web");
    });
    document.getElementById("smartInput").addEventListener("keydown", (e) => {
      if (e.key === "Enter") submitSmartText(e.target.value, "web");
    });
    document.getElementById("waInput").addEventListener("keydown", (e) => {
      if (e.key === "Enter") sendWaSim();
    });

    function escapeHtml(s) {
      return String(s ?? "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
    }

    loadSummary();
    setInterval(loadSummary, 6000);
  </script>
</body>
</html>
