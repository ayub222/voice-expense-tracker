<?php
declare(strict_types=1);

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . '/ai_service.php';

function httpRequestSimple(string $url, array $headers = [], ?string $postBody = null): array
{
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT => 25,
        CURLOPT_HTTPHEADER => $headers,
    ]);
    if ($postBody !== null) {
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $postBody);
    }
    $body = curl_exec($ch);
    $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return ['code' => $code, 'body' => is_string($body) ? $body : ''];
}

function getMetaWhatsAppToken(): string
{
    $tok = trim((string)getenv('WHATSAPP_ACCESS_TOKEN'));
    if ($tok === '') {
        $tok = trim((string)getenv('WHATSAPP_CLOUD_TOKEN'));
    }
    return $tok;
}

function sendMetaWhatsAppReply(string $phone, ?string $reply, string $phoneNumberId = ''): void
{
    if ($reply === null || trim($reply) === '' || $phone === '') {
        return;
    }
    $token = getMetaWhatsAppToken();
    $pid = $phoneNumberId !== '' ? $phoneNumberId : trim((string)getenv('WHATSAPP_PHONE_NUMBER_ID'));
    $ver = trim((string)getenv('WHATSAPP_GRAPH_VERSION')) ?: 'v22.0';
    if ($token === '' || $pid === '') {
        return;
    }
    httpRequestSimple(
        "https://graph.facebook.com/$ver/$pid/messages",
        ["Authorization: Bearer $token", 'Content-Type: application/json'],
        json_encode([
            'messaging_product' => 'whatsapp',
            'to' => $phone,
            'type' => 'text',
            'text' => ['body' => $reply],
        ], JSON_UNESCAPED_UNICODE)
    );
}

function downloadMetaAudioToFile(string $mediaId, string $destPath): bool
{
    $token = getMetaWhatsAppToken();
    $ver = trim((string)getenv('WHATSAPP_GRAPH_VERSION')) ?: 'v22.0';
    if ($token === '' || $mediaId === '') {
        return false;
    }
    $metaRes = httpRequestSimple(
        "https://graph.facebook.com/$ver/$mediaId",
        ["Authorization: Bearer $token"]
    );
    $metaJson = json_decode($metaRes['body'], true);
    $mediaUrl = (string)($metaJson['url'] ?? '');
    if ($mediaUrl === '') {
        return false;
    }
    $binRes = httpRequestSimple($mediaUrl, ["Authorization: Bearer $token", 'User-Agent: curl/8.0']);
    if ($binRes['code'] >= 200 && $binRes['code'] < 300 && $binRes['body'] !== '') {
        file_put_contents($destPath, $binRes['body']);
        return true;
    }
    return false;
}

try {
    $pdo = getDb();
    $action = (string)($_GET['action'] ?? $_POST['action'] ?? 'summary');

    if ($action === 'summary') {
        $limit = max(5, min(100, (int)($_GET['limit'] ?? 30)));
        $summary = getFinancialSummary($pdo, $limit);
        $allowedUsers = syncAllowedNumbersCache($pdo);
        $waStatusFile = STORAGE_DIR . DIRECTORY_SEPARATOR . 'wa_status.json';
        $waStatus = is_file($waStatusFile) ? json_decode((string)file_get_contents($waStatusFile), true) : null;

        echo json_encode([
            'ok' => true,
            'user' => [
                'name' => DEFAULT_USER_NAME,
                'whatsapp' => DEFAULT_WA_DISPLAY,
                'whatsapp_normalized' => DEFAULT_WA_NUMBER,
            ],
            'allowed_users' => $allowedUsers,
            'wa_bot_status' => $waStatus ?: [
                'connected' => false,
                'state' => 'standby',
                'target_phone' => DEFAULT_WA_DISPLAY,
            ],
            'data' => $summary,
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        exit;
    }

    if ($action === 'users') {
        echo json_encode([
            'ok' => true,
            'allowed_users' => syncAllowedNumbersCache($pdo),
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        exit;
    }

    if ($action === 'add_user') {
        $rawBody = file_get_contents('php://input');
        $jsonBody = $rawBody ? json_decode($rawBody, true) : [];
        if (!is_array($jsonBody)) {
            $jsonBody = [];
        }
        $name = trim((string)($jsonBody['name'] ?? $_POST['name'] ?? ''));
        $phoneRaw = trim((string)($jsonBody['phone'] ?? $_POST['phone'] ?? ''));
        if ($name === '' || $phoneRaw === '') {
            echo json_encode(['ok' => false, 'error' => 'Nama dan Nomor WhatsApp wajib diisi.'], JSON_UNESCAPED_UNICODE);
            exit;
        }
        $normPhone = normalizeWaNumber($phoneRaw);
        if (strlen($normPhone) < 9) {
            echo json_encode(['ok' => false, 'error' => 'Format nomor WhatsApp tidak valid.'], JSON_UNESCAPED_UNICODE);
            exit;
        }

        $chk = $pdo->prepare('SELECT id FROM users WHERE whatsapp_number = :wa LIMIT 1');
        $chk->execute([':wa' => $normPhone]);
        $existing = $chk->fetch();

        if ($existing) {
            $upd = $pdo->prepare('UPDATE users SET name = :name, is_active = 1 WHERE id = :id');
            $upd->execute([':name' => $name, ':id' => (int)$existing['id']]);
        } else {
            $ins = $pdo->prepare('INSERT INTO users (name, whatsapp_number, is_active) VALUES (:name, :wa, 1)');
            $ins->execute([':name' => $name, ':wa' => $normPhone]);
        }

        echo json_encode([
            'ok' => true,
            'message' => "Nomor " . displayWaNumber($normPhone) . " ($name) berhasil didaftarkan & diaktifkan!",
            'allowed_users' => syncAllowedNumbersCache($pdo),
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        exit;
    }

    if ($action === 'toggle_user') {
        $rawBody = file_get_contents('php://input');
        $jsonBody = $rawBody ? json_decode($rawBody, true) : [];
        $id = (int)($_GET['id'] ?? $_POST['id'] ?? $jsonBody['id'] ?? 0);
        if ($id <= 0) {
            echo json_encode(['ok' => false, 'error' => 'ID pengguna tidak valid.'], JSON_UNESCAPED_UNICODE);
            exit;
        }
        $pdo->prepare('UPDATE users SET is_active = CASE WHEN is_active = 1 THEN 0 ELSE 1 END WHERE id = :id')
            ->execute([':id' => $id]);

        echo json_encode([
            'ok' => true,
            'allowed_users' => syncAllowedNumbersCache($pdo),
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        exit;
    }

    if ($action === 'delete_user') {
        $rawBody = file_get_contents('php://input');
        $jsonBody = $rawBody ? json_decode($rawBody, true) : [];
        $id = (int)($_GET['id'] ?? $_POST['id'] ?? $jsonBody['id'] ?? 0);
        if ($id <= 0) {
            echo json_encode(['ok' => false, 'error' => 'ID pengguna tidak valid.'], JSON_UNESCAPED_UNICODE);
            exit;
        }
        if ($id === 1) {
            echo json_encode(['ok' => false, 'error' => 'Nomor utama (Ayub) tidak boleh dihapus, cukup nonaktifkan jika perlu.'], JSON_UNESCAPED_UNICODE);
            exit;
        }
        $pdo->prepare('DELETE FROM users WHERE id = :id')->execute([':id' => $id]);

        echo json_encode([
            'ok' => true,
            'allowed_users' => syncAllowedNumbersCache($pdo),
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        exit;
    }

    if ($action === 'smart_entry' || $action === 'whatsapp_webhook') {
        // 0. Handle Meta WhatsApp Cloud API Webhook Verification (GET hub.challenge)
        if (($_SERVER['REQUEST_METHOD'] ?? '') === 'GET' && isset($_GET['hub_mode'])) {
            $verifyToken = trim((string)getenv('WHATSAPP_VERIFY_TOKEN')) ?: 'voice_expense_verify';
            if (($_GET['hub_mode'] ?? '') === 'subscribe' && ($_GET['hub_verify_token'] ?? '') === $verifyToken) {
                header('Content-Type: text/plain; charset=utf-8');
                echo (string)($_GET['hub_challenge'] ?? '');
                exit;
            }
            http_response_code(403);
            echo json_encode(['ok' => false, 'error' => 'Verify token tidak cocok.']);
            exit;
        }

        $rawBody = file_get_contents('php://input');
        $jsonBody = $rawBody ? json_decode($rawBody, true) : [];
        if (!is_array($jsonBody)) {
            $jsonBody = [];
        }

        $isMetaCloud = false;
        $metaPhoneNumberId = '';
        $metaMediaId = '';

        // 0b. Parse Meta WhatsApp Cloud API POST payload if present
        if (($jsonBody['object'] ?? '') === 'whatsapp_business_account' && !empty($jsonBody['entry'][0]['changes'][0]['value'])) {
            $isMetaCloud = true;
            $val = $jsonBody['entry'][0]['changes'][0]['value'];
            $metaPhoneNumberId = (string)($val['metadata']['phone_number_id'] ?? '');
            if (empty($val['messages'][0])) {
                // Delivery/read status webhook: acknowledge 200 OK immediately
                echo json_encode(['ok' => true, 'ignored' => 'status_update']);
                exit;
            }
            $waMsg = $val['messages'][0];
            $source = 'whatsapp-cloud';
            $phone = (string)($waMsg['from'] ?? DEFAULT_WA_NUMBER);
            $msgType = (string)($waMsg['type'] ?? '');
            $inputText = $msgType === 'text' ? trim((string)($waMsg['text']['body'] ?? '')) : '';
            $metaMediaId = $msgType === 'audio' ? (string)($waMsg['audio']['id'] ?? '') : '';
            $audioPath = '';
            $audioBase64 = '';
        } else {
            $source = (string)($jsonBody['source'] ?? $_POST['source'] ?? ($action === 'whatsapp_webhook' ? 'whatsapp' : 'web'));
            $phone = (string)($jsonBody['phone'] ?? $jsonBody['sender'] ?? $_POST['phone'] ?? DEFAULT_WA_NUMBER);
            $inputText = trim((string)($jsonBody['text'] ?? $jsonBody['message'] ?? $_POST['text'] ?? ''));
            $audioPath = (string)($jsonBody['audio_path'] ?? $_POST['audio_path'] ?? '');
            $audioBase64 = (string)($jsonBody['audio_base64'] ?? $_POST['audio_base64'] ?? '');
        }
        $transcriptionModel = null;

        // 1. Handle Meta Cloud audio media_id, uploaded audio file, or base64 audio
        if ($metaMediaId !== '') {
            $dest = STORAGE_DIR . DIRECTORY_SEPARATOR . 'voice_meta_' . time() . '_' . mt_rand(100, 999) . '.ogg';
            if (!downloadMetaAudioToFile($metaMediaId, $dest)) {
                echo json_encode(['ok' => false, 'error' => 'Gagal mengunduh audio dari Meta Graph API.', 'whatsapp_reply' => null], JSON_UNESCAPED_UNICODE);
                exit;
            }
            $tr = transcribeAudioFile($dest, 'audio/ogg');
            @unlink($dest);
            if (!$tr['ok']) {
                echo json_encode(['ok' => false, 'error' => $tr['error'], 'whatsapp_reply' => null], JSON_UNESCAPED_UNICODE);
                exit;
            }
            $inputText = (string)$tr['text'];
            $transcriptionModel = $tr['model'] ?? 'whisper-large-v3-turbo';
        } elseif (!empty($_FILES['audio']['tmp_name']) && is_uploaded_file($_FILES['audio']['tmp_name'])) {
            $ext = pathinfo((string)($_FILES['audio']['name'] ?? 'voice.ogg'), PATHINFO_EXTENSION) ?: 'ogg';
            $dest = STORAGE_DIR . DIRECTORY_SEPARATOR . 'voice_' . time() . '_' . mt_rand(100, 999) . '.' . $ext;
            move_uploaded_file($_FILES['audio']['tmp_name'], $dest);
            $mime = (string)($_FILES['audio']['type'] ?? 'audio/ogg');
            $tr = transcribeAudioFile($dest, $mime);
            @unlink($dest);

            if (!$tr['ok']) {
                echo json_encode([
                    'ok' => false,
                    'error' => $tr['error'],
                    'whatsapp_reply' => null,
                ], JSON_UNESCAPED_UNICODE);
                exit;
            }
            $inputText = (string)$tr['text'];
            $transcriptionModel = $tr['model'] ?? 'whisper-large-v3-turbo';
        } elseif ($audioBase64 !== '') {
            $decodedAudio = base64_decode($audioBase64, true);
            if ($decodedAudio === false || $decodedAudio === '') {
                echo json_encode(['ok' => false, 'error' => 'Format audio_base64 tidak valid.', 'whatsapp_reply' => null], JSON_UNESCAPED_UNICODE);
                exit;
            }
            $dest = STORAGE_DIR . DIRECTORY_SEPARATOR . 'voice_b64_' . time() . '_' . mt_rand(100, 999) . '.ogg';
            file_put_contents($dest, $decodedAudio);
            $tr = transcribeAudioFile($dest, 'audio/ogg');
            @unlink($dest);

            if (!$tr['ok']) {
                echo json_encode([
                    'ok' => false,
                    'error' => $tr['error'],
                    'whatsapp_reply' => null,
                ], JSON_UNESCAPED_UNICODE);
                exit;
            }
            $inputText = (string)$tr['text'];
            $transcriptionModel = $tr['model'] ?? 'whisper-large-v3-turbo';
        } elseif ($audioPath !== '' && is_file($audioPath)) {
            $tr = transcribeAudioFile($audioPath);
            if (!$tr['ok']) {
                echo json_encode([
                    'ok' => false,
                    'error' => $tr['error'],
                    'whatsapp_reply' => null,
                ], JSON_UNESCAPED_UNICODE);
                exit;
            }
            $inputText = (string)$tr['text'];
            $transcriptionModel = $tr['model'] ?? 'whisper-large-v3-turbo';
        }

        if ($inputText === '') {
            echo json_encode([
                'ok' => false,
                'error' => 'Pesan teks atau suara kosong.',
                'whatsapp_reply' => null,
            ], JSON_UNESCAPED_UNICODE);
            exit;
        }

        // 2. Check special WhatsApp / Bot commands
        $cmdLower = strtolower($inputText);
        if (in_array($cmdLower, ['laporan', 'saldo', 'rekap', '/laporan', '/saldo'], true)) {
            $summary = getFinancialSummary($pdo, 10);
            if ($isMetaCloud) {
                sendMetaWhatsAppReply($phone, $summary['whatsapp_report'], $metaPhoneNumberId);
            }
            echo json_encode([
                'ok' => true,
                'command' => 'report',
                'whatsapp_reply' => $summary['whatsapp_report'],
                'summary' => $summary,
            ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
            exit;
        }

        if (in_array($cmdLower, ['hapus terakhir', 'batal', 'undo', '/undo'], true)) {
            $last = $pdo->query('SELECT id, description, amount FROM transactions ORDER BY id DESC LIMIT 1')->fetch();
            if ($last) {
                $del = $pdo->prepare('DELETE FROM transactions WHERE id = :id');
                $del->execute([':id' => (int)$last['id']]);
                $msg = "🗑️ Transaksi terakhir berhasil dihapus: *{$last['description']}* (" . formatRupiah((float)$last['amount']) . ")";
            } else {
                $msg = "ℹ️ Belum ada transaksi yang bisa dihapus.";
            }
            if ($isMetaCloud) {
                sendMetaWhatsAppReply($phone, $msg, $metaPhoneNumberId);
            }
            echo json_encode([
                'ok' => true,
                'command' => 'undo',
                'whatsapp_reply' => $msg,
                'summary' => getFinancialSummary($pdo, 20),
            ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
            exit;
        }

        // 2b. For WhatsApp source, strictly require BOTH a finance keyword AND a number/money unit.
        // If normal casual chat ("Iya kan tdr siang nya bentaran"), stay 100% SILENT (whatsapp_reply: null).
        $hasFinanceKeyword = (bool)preg_match(
            '/\b(beli|bayar|jajan|makan|minum|kopi|teh|susu|rokok|bensin|pertalite|pertamax|parkir|ojek|gojek|grab|tol|belanja|kos|kontrakan|listrik|token|wifi|kuota|pulsa|tagihan|gaji|pemasukan|pengeluaran|transfer|bonus|honor|dapat|catat|transaksi|sedekah|obat|servis|laundry|cukur)\b/i',
            $inputText
        );
        $hasMoneyAmount = (bool)preg_match(
            '/(\d+(?:[.,]\d+)?\s*(?:ribu|rb|k|juta|jt|rupiah|rp)|\b(?:rp\.?\s*\d[\d.,]*|\d{1,3}(?:[.,]\d{3})+|\d{4,})\b|\b(?:seribu|dua\s*ribu|tiga\s*ribu|empat\s*ribu|lima\s*ribu|sepuluh\s*ribu|limabelas\s*ribu|lima\s*belas\s*ribu|dua\s*puluh|tiga\s*puluh|lima\s*puluh|seratus|sejuta|juta|ribu|gocap|cepek|goban|seceng)\b)/i',
            $inputText
        );

        if (str_starts_with($source, 'whatsapp') && (!$hasFinanceKeyword || !$hasMoneyAmount)) {
            echo json_encode([
                'ok' => false,
                'ignored' => true,
                'transcribed_text' => $inputText,
                'whatsapp_reply' => null,
            ], JSON_UNESCAPED_UNICODE);
            exit;
        }

        // 3. Parse transactions using Groq AI / Fallback parser
        $parsed = parseTransactionsWithAi($inputText);
        if (!$parsed['ok'] || empty($parsed['items'])) {
            echo json_encode([
                'ok' => false,
                'transcribed_text' => $inputText,
                'error' => $parsed['error'] ?? 'Tidak dapat mengenali transaksi dari kalimat tersebut.',
                'whatsapp_reply' => null,
            ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
            exit;
        }

        // 4. Save to database
        $savedResult = saveParsedTransactions($pdo, $parsed['items'], $inputText, $source, $phone);
        $summary = getFinancialSummary($pdo, 30);

        if ($isMetaCloud) {
            sendMetaWhatsAppReply($phone, $savedResult['whatsapp_reply'] ?? null, $metaPhoneNumberId);
        }

        echo json_encode([
            'ok' => true,
            'transcribed_text' => $inputText,
            'transcription_model' => $transcriptionModel,
            'ai_provider' => $parsed['provider'] ?? 'groq',
            'ai_model' => $parsed['model'] ?? 'openai/gpt-oss-120b',
            'saved_transactions' => $savedResult['saved'],
            'whatsapp_reply' => $savedResult['whatsapp_reply'],
            'summary' => $summary,
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        exit;
    }

    if ($action === 'start_wa_bot') {
        $botDir = __DIR__ . DIRECTORY_SEPARATOR . 'wa-bot';
        $authDir = STORAGE_DIR . DIRECTORY_SEPARATOR . 'wa_auth';
        $statusFile = STORAGE_DIR . DIRECTORY_SEPARATOR . 'wa_status.json';
        $pidFile = STORAGE_DIR . DIRECTORY_SEPARATOR . 'wa_bot.pid';

        // Kill any previous bot.js processes (including old PID 13932 or pid from wa_bot.pid)
        if (is_file($pidFile)) {
            $oldPid = (int)trim((string)file_get_contents($pidFile));
            if ($oldPid > 0) {
                @exec("taskkill /F /PID $oldPid 2>&1");
            }
        }
        @exec("taskkill /F /PID 13932 2>&1");

        // Only clean wa_auth if creds.json is missing or not registered
        $credsFile = $authDir . DIRECTORY_SEPARATOR . 'creds.json';
        $isRegistered = false;
        if (is_file($credsFile)) {
            $credsJson = json_decode((string)file_get_contents($credsFile), true);
            $isRegistered = !empty($credsJson['registered']);
        }
        if (!$isRegistered && is_dir($authDir)) {
            foreach (glob($authDir . DIRECTORY_SEPARATOR . '*') ?: [] as $f) {
                if (is_file($f)) {
                    @unlink($f);
                }
            }
        }

        // Reset pairing status so dashboard knows it's generating a fresh code
        file_put_contents($statusFile, json_encode([
            'connected' => false,
            'state' => 'generating_pairing_code',
            'target_phone' => DEFAULT_WA_DISPLAY,
            'pairing_code' => null,
            'updated_at' => date('c'),
        ], JSON_PRETTY_PRINT));

        // Kill any previous node bot.js process and spawn fresh with full node.exe path
        $nodeExe = 'C:\\Program Files\\nodejs\\node.exe';
        if (!is_file($nodeExe)) {
            $nodeExe = 'node';
        }
        $cmd = 'start /B "" "' . $nodeExe . '" "' . $botDir . '\\bot.js" > "' . STORAGE_DIR . '\\wa_bot.log" 2>&1';
        pclose(popen($cmd, 'r'));

        echo json_encode([
            'ok' => true,
            'message' => 'Bot WhatsApp sedang meminta kode pairing baru untuk ' . DEFAULT_WA_DISPLAY . ' (tunggu ~4 detik)...',
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    if ($action === 'delete') {
        $rawBody = file_get_contents('php://input');
        $jsonBody = $rawBody ? json_decode($rawBody, true) : [];
        $id = (int)($_GET['id'] ?? $_POST['id'] ?? $jsonBody['id'] ?? 0);
        if ($id <= 0) {
            echo json_encode(['ok' => false, 'error' => 'ID transaksi tidak valid.']);
            exit;
        }
        $stmt = $pdo->prepare('DELETE FROM transactions WHERE id = :id');
        $stmt->execute([':id' => $id]);

        echo json_encode([
            'ok' => true,
            'deleted_id' => $id,
            'summary' => getFinancialSummary($pdo, 30),
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        exit;
    }

    echo json_encode(['ok' => false, 'error' => 'Action tidak dikenali: ' . $action]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'ok' => false,
        'error' => $e->getMessage(),
    ], JSON_UNESCAPED_UNICODE);
}
