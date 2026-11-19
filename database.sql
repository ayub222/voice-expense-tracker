-- Database Schema for Voice Expense Tracker (Ayub - 0895374884648)
CREATE DATABASE IF NOT EXISTS `voice_expense_db`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `voice_expense_db`;

CREATE TABLE IF NOT EXISTS `users` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(100) NOT NULL,
  `whatsapp_number` VARCHAR(30) NOT NULL UNIQUE,
  `telegram_id` VARCHAR(50) DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `categories` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(60) NOT NULL UNIQUE,
  `type` ENUM('expense', 'income') NOT NULL DEFAULT 'expense',
  `icon` VARCHAR(16) NOT NULL DEFAULT '💸',
  `color` VARCHAR(16) NOT NULL DEFAULT '#38bdf8'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
  INDEX `idx_tx_user` (`user_id`),
  CONSTRAINT `fk_tx_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_tx_category` FOREIGN KEY (`category_id`) REFERENCES `categories`(`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
