<?php
declare(strict_types=1);

/**
 * Core Configuration & Auto-Migrating PDO Database Connection
 * Project: Voice Expense Tracker AI (Multi-User WhatsApp Edition)
 */

error_reporting(E_ALL & ~E_DEPRECATED & ~E_NOTICE);
ini_set('display_errors', '0');
date_default_timezone_set('Asia/Jakarta');

define('APP_NAME', 'Voice Expense Tracker AI');
define('DEFAULT_USER_NAME', 'Ayub');
define('DEFAULT_WA_NUMBER', '62895374884648');
define('DEFAULT_WA_DISPLAY', '0895374884648');
define('IS_VERCEL', (bool)(getenv('VERCEL') || getenv('VERCEL_ENV')));
define(
    'STORAGE_DIR',
    IS_VERCEL
        ? (sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'voice_expense_storage')
        : (__DIR__ . DIRECTORY_SEPARATOR . 'storage')
);
define('ALLOWED_NUMBERS_FILE', STORAGE_DIR . DIRECTORY_SEPARATOR . 'allowed_numbers.json');

if (!is_dir(STORAGE_DIR)) {
    mkdir(STORAGE_DIR, 0775, true);
}

/**
 * Load Groq & OpenRouter API keys automatically from Antigravity's mcp_config.json
 */
function getAiCredentials(): array
{
    $groqKey = getenv('GROQ_API_KEY') ?: '';
    $openRouterKey = getenv('OPENROUTER_API_KEY') ?: '';

    $candidatePaths = [
        'C:\\Users\\USER\\.gemini\\config\\mcp_config.json',
        (getenv('USERPROFILE') ?: 'C:\\Users\\USER') . '\\.gemini\\config\\mcp_config.json',
    ];

    foreach ($candidatePaths as $mcpConfigPath) {
        if ((!$groqKey || !$openRouterKey) && is_file($mcpConfigPath)) {
            $raw = @file_get_contents($mcpConfigPath);
            $json = $raw ? json_decode($raw, true) : null;
            if (is_array($json) && isset($json['mcpServers'])) {
                $servers = $json['mcpServers'];
                if (!$groqKey && !empty($servers['grok']['env']['LLM_API_KEY'])) {
                    $groqKey = (string)$servers['grok']['env']['LLM_API_KEY'];
                }
                if (!$openRouterKey && !empty($servers['router']['env']['LLM_API_KEY'])) {
                    $openRouterKey = (string)$servers['router']['env']['LLM_API_KEY'];
                }
            }
        }
    }

    return [
        'groq_url' => 'https://api.groq.com/openai/v1',
        'groq_key' => $groqKey,
        'groq_model' => 'openai/gpt-oss-120b',
        'whisper_model' => 'whisper-large-v3-turbo',
        'openrouter_url' => 'https://openrouter.ai/api/v1',
        'openrouter_key' => $openRouterKey,
        'openrouter_model' => 'openrouter/free',
    ];
}

/**
 * Normalize Indonesian phone numbers to 628... format
 */
function normalizeWaNumber(string $phone): string
{
    $digits = preg_replace('/\D+/', '', $phone) ?? '';
    if ($digits === '') {
        return DEFAULT_WA_NUMBER;
    }
    if (str_starts_with($digits, '0')) {
        return '62' . substr($digits, 1);
    }
    if (str_starts_with($digits, '8')) {
        return '62' . $digits;
    }
    return $digits;
}

/**
 * Format 628... back to friendly 08... for display
 */
function displayWaNumber(string $phone): string
{
    $norm = normalizeWaNumber($phone);
    if (str_starts_with($norm, '62')) {
        return '0' . substr($norm, 2);
    }
    return $norm;
}

/**
 * Sync active allowed WhatsApp numbers from DB to storage/allowed_numbers.json
 * so wa-bot/bot.js can check permissions in real time without restarting.
 */
function syncAllowedNumbersCache(PDO $pdo): array
{
    $rows = $pdo->query('SELECT id, name, whatsapp_number, is_active, created_at FROM users ORDER BY id ASC')->fetchAll();
    $activeNumbers = [];
    foreach ($rows as &$r) {
        $r['id'] = (int)$r['id'];
        $r['is_active'] = (int)($r['is_active'] ?? 1) === 1;
        $r['whatsapp_display'] = displayWaNumber((string)$r['whatsapp_number']);
        if ($r['is_active']) {
            $activeNumbers[] = [
                'id' => $r['id'],
                'name' => $r['name'],
                'phone' => (string)$r['whatsapp_number'],
                'display' => $r['whatsapp_display'],
            ];
        }
    }
    @file_put_contents(
        ALLOWED_NUMBERS_FILE,
        json_encode([
            'updated_at' => date('c'),
            'owner_phone' => DEFAULT_WA_NUMBER,
            'allowed' => $activeNumbers,
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)
    );
    return $rows;
}

/**
 * Establish PDO connection (MariaDB/MySQL on Wamp64 3306, with automatic SQLite fallback)
 */
function getDb(): PDO
{
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $driver = 'mysql';
    if (IS_VERCEL && !getenv('DB_DSN')) {
        $driver = 'sqlite';
        $sqlitePath = STORAGE_DIR . DIRECTORY_SEPARATOR . 'voice_expense.sqlite';
        $pdo = new PDO(
            'sqlite:' . $sqlitePath,
            null,
            null,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            ]
        );
        initSchema($pdo, $driver);
        return $pdo;
    }

    try {
        $dsn = getenv('DB_DSN') ?: 'mysql:host=127.0.0.1;port=3306;charset=utf8mb4';
        $dbUser = getenv('DB_USER') ?: 'root';
        $dbPass = getenv('DB_PASS') ?: '';
        $pdo = new PDO(
            $dsn,
            $dbUser,
            $dbPass,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]
        );
        if (!getenv('DB_DSN')) {
            $pdo->exec('CREATE DATABASE IF NOT EXISTS `voice_expense_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
            $pdo->exec('USE `voice_expense_db`');
        }
    } catch (Throwable $e) {
        $driver = 'sqlite';
        $sqlitePath = STORAGE_DIR . DIRECTORY_SEPARATOR . 'voice_expense.sqlite';
        $pdo = new PDO(
            'sqlite:' . $sqlitePath,
            null,
            null,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            ]
        );
    }

    initSchema($pdo, $driver);
    return $pdo;
}

function initSchema(PDO $pdo, string $driver): void
{
    if ($driver === 'mysql') {
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS `users` (
              `id` INT AUTO_INCREMENT PRIMARY KEY,
              `name` VARCHAR(100) NOT NULL,
              `whatsapp_number` VARCHAR(30) NOT NULL UNIQUE,
              `telegram_id` VARCHAR(50) DEFAULT NULL,
              `is_active` TINYINT(1) NOT NULL DEFAULT 1,
              `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ");

        // Ensure is_active column exists on existing users table
        $cols = $pdo->query("SHOW COLUMNS FROM `users` LIKE 'is_active'")->fetchAll();
        if (empty($cols)) {
            $pdo->exec("ALTER TABLE `users` ADD COLUMN `is_active` TINYINT(1) NOT NULL DEFAULT 1 AFTER `telegram_id`");
        }

        $pdo->exec("
            CREATE TABLE IF NOT EXISTS `categories` (
              `id` INT AUTO_INCREMENT PRIMARY KEY,
              `name` VARCHAR(60) NOT NULL UNIQUE,
              `type` ENUM('expense', 'income') NOT NULL DEFAULT 'expense',
              `icon` VARCHAR(16) NOT NULL DEFAULT '💸',
              `color` VARCHAR(16) NOT NULL DEFAULT '#38bdf8'
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ");

        $pdo->exec("
            CREATE TABLE IF NOT EXISTS `transactions` (
              `id` INT AUTO_INCREMENT PRIMARY KEY,
              `user_id` INT NOT NULL DEFAULT 1,
              `category_id` INT NOT NULL,
              `amount` DECIMAL(15,2) NOT NULL,
              `type` ENUM('expense', 'income') NOT NULL DEFAULT 'expense',
              `description` VARCHAR(255) NOT NULL,
              `source` VARCHAR(30) NOT NULL DEFAULT 'web',
              `raw_voice_text` TEXT DEFAULT NULL,
              `transaction_date` DATE NOT NULL,
              `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
              INDEX `idx_tx_date` (`transaction_date`),
              INDEX `idx_tx_user` (`user_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ");
    } else {
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              whatsapp_number TEXT NOT NULL UNIQUE,
              telegram_id TEXT DEFAULT NULL,
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
            );
            CREATE TABLE IF NOT EXISTS categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              type TEXT NOT NULL DEFAULT 'expense',
              icon TEXT NOT NULL DEFAULT '💸',
              color TEXT NOT NULL DEFAULT '#38bdf8'
            );
            CREATE TABLE IF NOT EXISTS transactions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER NOT NULL DEFAULT 1,
              category_id INTEGER NOT NULL,
              amount REAL NOT NULL,
              type TEXT NOT NULL DEFAULT 'expense',
              description TEXT NOT NULL,
              source TEXT NOT NULL DEFAULT 'web',
              raw_voice_text TEXT DEFAULT NULL,
              transaction_date TEXT NOT NULL,
              created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
            );
        ");
    }

    // Seed default user (Ayub - 62895374884648)
    $userCount = (int)$pdo->query('SELECT COUNT(*) FROM users')->fetchColumn();
    if ($userCount === 0) {
        $stmt = $pdo->prepare('INSERT INTO users (name, whatsapp_number, is_active) VALUES (:name, :wa, 1)');
        $stmt->execute([
            ':name' => DEFAULT_USER_NAME,
            ':wa' => DEFAULT_WA_NUMBER,
        ]);
    }

    if (!is_file(ALLOWED_NUMBERS_FILE)) {
        syncAllowedNumbersCache($pdo);
    }

    // Seed default categories
    $catCount = (int)$pdo->query('SELECT COUNT(*) FROM categories')->fetchColumn();
    if ($catCount === 0) {
        $defaults = [
            ['Makan & Minum', 'expense', '🍜', '#f59e0b'],
            ['Transportasi', 'expense', '⛽', '#38bdf8'],
            ['Belanja & Harian', 'expense', '🛒', '#a78bfa'],
            ['Tagihan & Kos', 'expense', '🏠', '#fb7185'],
            ['Hiburan & Langganan', 'expense', '🎮', '#34d399'],
            ['Kesehatan', 'expense', '💊', '#f43f5e'],
            ['Gaji & Pemasukan', 'income', '💰', '#10b981'],
            ['Lainnya', 'expense', '📦', '#94a3b8'],
        ];
        $stmt = $pdo->prepare('INSERT INTO categories (name, type, icon, color) VALUES (:name, :type, :icon, :color)');
        foreach ($defaults as [$name, $type, $icon, $color]) {
            $stmt->execute([
                ':name' => $name,
                ':type' => $type,
                ':icon' => $icon,
                ':color' => $color,
            ]);
        }
    }
}

function formatRupiah(float $amount): string
{
    return 'Rp ' . number_format($amount, 0, ',', '.');
}
