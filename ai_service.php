<?php
declare(strict_types=1);

require_once __DIR__ . '/config.php';

/**
 * Transcribe an audio file (.ogg, .wav, .mp3, .m4a, .webm) to Indonesian text
 * using Groq Whisper Large v3 Turbo.
 */
function transcribeAudioFile(string $filePath, string $mimeType = 'audio/ogg'): array
{
    if (!is_file($filePath)) {
        return ['ok' => false, 'error' => 'File audio tidak ditemukan: ' . $filePath];
    }

    $creds = getAiCredentials();
    if ($creds['groq_key'] === '') {
        return ['ok' => false, 'error' => 'GROQ_API_KEY belum dikonfigurasi.'];
    }

    $ch = curl_init($creds['groq_url'] . '/audio/transcriptions');
    $cfile = new CURLFile($filePath, $mimeType, basename($filePath));
    $postFields = [
        'file' => $cfile,
        'model' => $creds['whisper_model'],
        'language' => 'id',
        'prompt' => 'Catatan keuangan harian dalam Rupiah: beli bensin, makan, kopi, parkir, gaji, transfer, ribu, juta.',
    ];

    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => $postFields,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_HTTPHEADER => [
            'Authorization: Bearer ' . $creds['groq_key'],
        ],
    ]);

    $resp = curl_exec($ch);
    $httpCode = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlErr = curl_error($ch);
    unset($ch);

    if ($resp === false || $httpCode >= 400) {
        return [
            'ok' => false,
            'error' => "Groq Whisper HTTP $httpCode: " . ($curlErr ?: (string)$resp),
        ];
    }

    $data = json_decode((string)$resp, true);
    $text = trim((string)($data['text'] ?? ''));

    return [
        'ok' => $text !== '',
        'text' => $text,
        'model' => $creds['whisper_model'],
        'error' => $text === '' ? 'Transkrip kosong.' : null,
    ];
}

/**
 * Parse natural Indonesian expense/income sentence into structured transactions
 * using Groq LLM (with OpenRouter & deterministic local parser fallbacks).
 */
function parseTransactionsWithAi(string $inputText): array
{
    $inputText = trim($inputText);
    if ($inputText === '') {
        return ['ok' => false, 'items' => [], 'error' => 'Teks input kosong.'];
    }

    $creds = getAiCredentials();
    $systemPrompt = <<<PROMPT
Kamu adalah AI parser keuangan Bahasa Indonesia.
Ubah kalimat pengguna menjadi JSON array berisi daftar transaksi keuangan.
Daftar kategori yang valid (PILIH SALAH SATU yang paling cocok untuk tiap item):
- "Makan & Minum" (contoh: makan, kopi, bakso, soto, jajan, air, sarapan)
- "Transportasi" (contoh: bensin, pertamax, pertalite, parkir, ojek, grab, gojek, tol, servis motor)
- "Belanja & Harian" (contoh: belanja, sabun, indomaret, alfamart, pulsa, kuota, pakaian)
- "Tagihan & Kos" (contoh: kos, kontrakan, listrik, token, wifi, air pdam, cicilan)
- "Hiburan & Langganan" (contoh: nonton, game, netflix, spotify, nongkrong)
- "Kesehatan" (contoh: obat, dokter, apotek, vitamin)
- "Gaji & Pemasukan" (contoh: gaji, transfer masuk, bonus, honor, proyek, dikasih)
- "Lainnya" (jika tidak masuk kategori di atas)

Aturan:
1. Konversi nominal bahasa Indonesia ke angka penuh Rupiah:
   - "30 ribu" / "30rb" / "30k" -> 30000
   - "1,5 juta" / "1.5jt" -> 1500000
   - "cepek" -> 100000, "gocap" -> 50000, "goban" -> 50000, "seceng" -> 1000
2. Field "type" bernilai "income" HANYA untuk pemasukan/gaji/transfer masuk. Selain itu "expense".
3. Balas HANYA dengan JSON murni tanpa markdown/penjelasan, format:
{"items":[{"description":"Beli bensin","amount":30000,"type":"expense","category":"Transportasi"}]}
PROMPT;

    $providers = [];
    if ($creds['groq_key'] !== '') {
        $providers[] = [
            'name' => 'groq',
            'url' => $creds['groq_url'] . '/chat/completions',
            'key' => $creds['groq_key'],
            'model' => $creds['groq_model'],
        ];
    }
    if ($creds['openrouter_key'] !== '') {
        $providers[] = [
            'name' => 'openrouter',
            'url' => $creds['openrouter_url'] . '/chat/completions',
            'key' => $creds['openrouter_key'],
            'model' => $creds['openrouter_model'],
        ];
    }

    foreach ($providers as $prov) {
        $payload = [
            'model' => $prov['model'],
            'messages' => [
                ['role' => 'system', 'content' => $systemPrompt],
                ['role' => 'user', 'content' => $inputText],
            ],
            'temperature' => 0.1,
        ];

        $ch = curl_init($prov['url']);
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => json_encode($payload),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 20,
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/json',
                'Authorization: Bearer ' . $prov['key'],
            ],
        ]);

        $resp = curl_exec($ch);
        $httpCode = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        unset($ch);

        if ($resp !== false && $httpCode >= 200 && $httpCode < 300) {
            $data = json_decode((string)$resp, true);
            $content = (string)($data['choices'][0]['message']['content'] ?? '');
            $parsedItems = extractJsonItems($content);
            if (!empty($parsedItems)) {
                return [
                    'ok' => true,
                    'items' => $parsedItems,
                    'provider' => $prov['name'],
                    'model' => $data['model'] ?? $prov['model'],
                ];
            }
        }
    }

    // Deterministic Fallback Parser (offline / rate-limit safe)
    $fallbackItems = localFallbackParse($inputText);
    return [
        'ok' => !empty($fallbackItems),
        'items' => $fallbackItems,
        'provider' => 'local-fallback',
        'model' => 'deterministic-id-parser',
        'error' => empty($fallbackItems) ? 'Tidak ditemukan nominal transaksi yang valid.' : null,
    ];
}

function extractJsonItems(string $rawContent): array
{
    $clean = trim($rawContent);
    if (preg_match('/\{[\s\S]*\}|\[[\s\S]*\]/', $clean, $m)) {
        $clean = $m[0];
    }
    $decoded = json_decode($clean, true);
    if (!is_array($decoded)) {
        return [];
    }
    $list = isset($decoded['items']) && is_array($decoded['items']) ? $decoded['items'] : $decoded;
    $valid = [];
    foreach ($list as $item) {
        if (!is_array($item)) {
            continue;
        }
        $amount = (float)($item['amount'] ?? 0);
        if ($amount <= 0) {
            continue;
        }
        $type = strtolower((string)($item['type'] ?? 'expense')) === 'income' ? 'income' : 'expense';
        $desc = trim((string)($item['description'] ?? 'Transaksi'));
        $cat = trim((string)($item['category'] ?? ($type === 'income' ? 'Gaji & Pemasukan' : 'Lainnya')));
        $valid[] = [
            'description' => $desc !== '' ? $desc : 'Transaksi',
            'amount' => $amount,
            'type' => $type,
            'category' => $cat,
        ];
    }
    return $valid;
}

/**
 * Offline regex fallback parser for Indonesian currency phrases
 * e.g. "Beli bensin 30 ribu sama kopi 18 ribu"
 */
function localFallbackParse(string $text): array
{
    $segments = preg_split('/\b(?:sama|dan|terus|lalu|serta|plus|\+|,|;)\b/i', $text) ?: [$text];
    $items = [];

    foreach ($segments as $seg) {
        $seg = trim($seg);
        if ($seg === '') {
            continue;
        }
        if (preg_match('/(\d+(?:[.,]\d+)?)\s*(juta|jt|ribu|rb|k|rupiah|rp)?/i', $seg, $m)) {
            $numStr = str_replace(',', '.', $m[1]);
            $val = (float)$numStr;
            $unit = strtolower((string)($m[2] ?? ''));

            if (in_array($unit, ['juta', 'jt'], true)) {
                $val *= 1000000;
            } elseif (in_array($unit, ['ribu', 'rb', 'k'], true)) {
                $val *= 1000;
            } elseif ($val < 1000 && $unit === '') {
                $val *= 1000;
            }

            $desc = trim(str_replace($m[0], '', $seg));
            $desc = trim($desc, " \t\n\r\0\x0B-:");
            if ($desc === '') {
                $desc = 'Transaksi';
            }

            $lower = strtolower($seg);
            $type = 'expense';
            $cat = 'Lainnya';

            if (preg_match('/\b(gaji|pemasukan|transfer masuk|bonus|honor|dapat|dikasih)\b/', $lower)) {
                $type = 'income';
                $cat = 'Gaji & Pemasukan';
            } elseif (preg_match('/\b(bensin|pertalite|pertamax|parkir|ojek|gojek|grab|tol|transport|motor|mobil)\b/', $lower)) {
                $cat = 'Transportasi';
            } elseif (preg_match('/\b(makan|minum|kopi|nasi|soto|bakso|ayam|teh|sarapan|jajan|es|warung|resto)\b/', $lower)) {
                $cat = 'Makan & Minum';
            } elseif (preg_match('/\b(kos|kontrakan|listrik|token|wifi|tagihan|air|pulsa|kuota)\b/', $lower)) {
                $cat = 'Tagihan & Kos';
            } elseif (preg_match('/\b(belanja|sabun|indomaret|alfamart|pasar|baju|sepatu)\b/', $lower)) {
                $cat = 'Belanja & Harian';
            } elseif (preg_match('/\b(obat|dokter|apotek|vitamin|sakit)\b/', $lower)) {
                $cat = 'Kesehatan';
            }

            $items[] = [
                'description' => ucfirst($desc),
                'amount' => $val,
                'type' => $type,
                'category' => $cat,
            ];
        }
    }

    return $items;
}

/**
 * Store parsed items into the database via PDO prepared statements
 * and return saved records + formatted WhatsApp reply text.
 */
function saveParsedTransactions(
    PDO $pdo,
    array $items,
    string $rawText,
    string $source = 'web',
    string $phone = DEFAULT_WA_NUMBER
): array {
    $normPhone = normalizeWaNumber($phone);

    // Ensure user exists
    $uStmt = $pdo->prepare('SELECT id, name FROM users WHERE whatsapp_number = :wa LIMIT 1');
    $uStmt->execute([':wa' => $normPhone]);
    $user = $uStmt->fetch();
    if (!$user) {
        $insU = $pdo->prepare('INSERT INTO users (name, whatsapp_number) VALUES (:name, :wa)');
        $insU->execute([':name' => DEFAULT_USER_NAME, ':wa' => $normPhone]);
        $userId = (int)$pdo->lastInsertId();
    } else {
        $userId = (int)$user['id'];
    }

    // Load categories map
    $cats = $pdo->query('SELECT id, name, icon, type FROM categories')->fetchAll();
    $catMap = [];
    $defaultExpenseCat = null;
    $defaultIncomeCat = null;
    foreach ($cats as $c) {
        $catMap[strtolower($c['name'])] = $c;
        if ($c['name'] === 'Lainnya') {
            $defaultExpenseCat = $c;
        }
        if ($c['type'] === 'income') {
            $defaultIncomeCat = $c;
        }
    }

    $today = date('Y-m-d');
    $insTx = $pdo->prepare('
        INSERT INTO transactions (user_id, category_id, amount, type, description, source, raw_voice_text, transaction_date)
        VALUES (:uid, :cid, :amount, :type, :desc, :source, :raw, :tdate)
    ');

    $saved = [];
    foreach ($items as $item) {
        $catNameLower = strtolower((string)($item['category'] ?? ''));
        $matchedCat = $catMap[$catNameLower] ?? null;

        if (!$matchedCat) {
            foreach ($catMap as $k => $c) {
                if (str_contains($k, $catNameLower) || str_contains($catNameLower, $k)) {
                    $matchedCat = $c;
                    break;
                }
            }
        }
        if (!$matchedCat) {
            $matchedCat = ($item['type'] === 'income' && $defaultIncomeCat) ? $defaultIncomeCat : ($defaultExpenseCat ?: $cats[0]);
        }

        $amount = (float)$item['amount'];
        $type = $item['type'] === 'income' ? 'income' : 'expense';
        $desc = (string)$item['description'];

        $insTx->execute([
            ':uid' => $userId,
            ':cid' => (int)$matchedCat['id'],
            ':amount' => $amount,
            ':type' => $type,
            ':desc' => $desc,
            ':source' => $source,
            ':raw' => $rawText,
            ':tdate' => $today,
        ]);

        $saved[] = [
            'id' => (int)$pdo->lastInsertId(),
            'description' => $desc,
            'amount' => $amount,
            'amount_formatted' => formatRupiah($amount),
            'type' => $type,
            'category' => $matchedCat['name'],
            'icon' => $matchedCat['icon'],
            'transaction_date' => $today,
            'source' => $source,
        ];
    }

    // Calculate today's expense total
    $tStmt = $pdo->prepare("
        SELECT COALESCE(SUM(amount), 0) FROM transactions
        WHERE user_id = :uid AND type = 'expense' AND transaction_date = :tdate
    ");
    $tStmt->execute([':uid' => $userId, ':tdate' => $today]);
    $todayExpense = (float)$tStmt->fetchColumn();

    // Build WhatsApp reply message
    $lines = ["✅ *Tercatat " . count($saved) . " Transaksi Baru*"];
    if ($rawText !== '') {
        $lines[] = "_“" . $rawText . "”_";
    }
    $lines[] = "";
    foreach ($saved as $s) {
        $sign = $s['type'] === 'income' ? '+' : '-';
        $lines[] = "{$s['icon']} *{$s['category']}*: {$sign}{$s['amount_formatted']} _({$s['description']})_";
    }
    $lines[] = "";
    $lines[] = "📊 *Total Pengeluaran Hari Ini:* " . formatRupiah($todayExpense);
    $lines[] = "💡 _Ketik *laporan* untuk cek saldo & rekap bulanan._";

    return [
        'saved' => $saved,
        'today_expense' => $todayExpense,
        'today_expense_formatted' => formatRupiah($todayExpense),
        'whatsapp_reply' => implode("\n", $lines),
    ];
}

/**
 * Build full summary report for Dashboard, Flutter App, and WhatsApp 'laporan' command
 */
function getFinancialSummary(PDO $pdo, int $limit = 30): array
{
    $today = date('Y-m-d');
    $monthPrefix = date('Y-m') . '%';

    $totals = $pdo->query("
        SELECT
            COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS total_income,
            COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS total_expense
        FROM transactions
    ")->fetch();

    $todayStmt = $pdo->prepare("
        SELECT COALESCE(SUM(amount), 0) FROM transactions
        WHERE type = 'expense' AND transaction_date = :today
    ");
    $todayStmt->execute([':today' => $today]);
    $todayExpense = (float)$todayStmt->fetchColumn();

    $monthStmt = $pdo->prepare("
        SELECT COALESCE(SUM(amount), 0) FROM transactions
        WHERE type = 'expense' AND CAST(transaction_date AS CHAR) LIKE :mp
    ");
    $monthStmt->execute([':mp' => $monthPrefix]);
    $monthExpense = (float)$monthStmt->fetchColumn();

    $byCategory = $pdo->query("
        SELECT
            c.id,
            c.name,
            c.icon,
            c.color,
            c.type,
            COALESCE(SUM(t.amount), 0) AS total,
            COUNT(t.id) AS tx_count
        FROM categories c
        LEFT JOIN transactions t ON t.category_id = c.id
        GROUP BY c.id, c.name, c.icon, c.color, c.type
        HAVING total > 0
        ORDER BY total DESC
    ")->fetchAll();

    $recentStmt = $pdo->prepare("
        SELECT
            t.id,
            t.user_id,
            t.amount,
            t.type,
            t.description,
            t.source,
            t.raw_voice_text,
            t.transaction_date,
            t.created_at,
            c.name AS category_name,
            c.icon AS category_icon,
            c.color AS category_color,
            COALESCE(u.name, 'Ayub') AS user_name,
            COALESCE(u.whatsapp_number, '62895374884648') AS user_phone
        FROM transactions t
        JOIN categories c ON c.id = t.category_id
        LEFT JOIN users u ON u.id = t.user_id
        ORDER BY t.id DESC
        LIMIT :lim
    ");
    $recentStmt->bindValue(':lim', $limit, PDO::PARAM_INT);
    $recentStmt->execute();
    $recent = $recentStmt->fetchAll();

    foreach ($recent as &$r) {
        $r['amount'] = (float)$r['amount'];
        $r['amount_formatted'] = formatRupiah($r['amount']);
    }

    $totalIncome = (float)($totals['total_income'] ?? 0);
    $totalExpense = (float)($totals['total_expense'] ?? 0);
    $balance = $totalIncome - $totalExpense;

    $waLines = [
        "📊 *LAPORAN KEUANGAN AYUB*",
        "📅 Tanggal: " . date('d M Y H:i') . " WIB",
        "",
        "💰 *Total Pemasukan:* " . formatRupiah($totalIncome),
        "💸 *Total Pengeluaran:* " . formatRupiah($totalExpense),
        "🏦 *Saldo Bersih:* " . formatRupiah($balance),
        "🔥 *Pengeluaran Hari Ini:* " . formatRupiah($todayExpense),
        "",
        "📂 *Per Kategori:*",
    ];
    if (empty($byCategory)) {
        $waLines[] = "- Belum ada transaksi.";
    } else {
        foreach ($byCategory as $cat) {
            $waLines[] = "{$cat['icon']} {$cat['name']}: " . formatRupiah((float)$cat['total']) . " ({$cat['tx_count']}x)";
        }
    }

    return [
        'total_income' => $totalIncome,
        'total_income_formatted' => formatRupiah($totalIncome),
        'total_expense' => $totalExpense,
        'total_expense_formatted' => formatRupiah($totalExpense),
        'balance' => $balance,
        'balance_formatted' => formatRupiah($balance),
        'today_expense' => $todayExpense,
        'today_expense_formatted' => formatRupiah($todayExpense),
        'month_expense' => $monthExpense,
        'month_expense_formatted' => formatRupiah($monthExpense),
        'by_category' => $byCategory,
        'recent_transactions' => $recent,
        'whatsapp_report' => implode("\n", $waLines),
    ];
}
