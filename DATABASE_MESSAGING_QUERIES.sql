-- ============================================================
-- MESSAGING SYSTEM DATABASE QUERIES
-- Run these in your database to set up the messaging tables
-- ============================================================

-- 1. Create Conversations Table
CREATE TABLE IF NOT EXISTS equisplit.conversations (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id_1 INT NOT NULL,
  user_id_2 INT NOT NULL,
  last_message_id INT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id_1) REFERENCES equisplit.user(user_id),
  FOREIGN KEY (user_id_2) REFERENCES equisplit.user(user_id),
  UNIQUE KEY unique_conversation (user_id_1, user_id_2),
  INDEX idx_user_1 (user_id_1),
  INDEX idx_user_2 (user_id_2),
  INDEX idx_updated_at (updated_at)
);

-- 2. Create Messages Table
CREATE TABLE IF NOT EXISTS equisplit.messages (
  id INT PRIMARY KEY AUTO_INCREMENT,
  conversation_id INT NOT NULL,
  sender_id INT NOT NULL,
  receiver_id INT NOT NULL,
  content TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (conversation_id) REFERENCES equisplit.conversations(id) ON DELETE CASCADE,
  FOREIGN KEY (sender_id) REFERENCES equisplit.user(user_id),
  FOREIGN KEY (receiver_id) REFERENCES equisplit.user(user_id),
  INDEX idx_conversation (conversation_id),
  INDEX idx_sender (sender_id),
  INDEX idx_receiver (receiver_id),
  INDEX idx_created_at (created_at)
);

-- 3. Optional: Add message_count column to conversations table
ALTER TABLE equisplit.conversations ADD COLUMN unread_count INT DEFAULT 0;

-- ============================================================
-- USEFUL QUERIES FOR MESSAGING FEATURES
-- ============================================================

-- Get all conversations for a user (ordered by most recent)
-- SELECT c.id, c.user_id_1, c.user_id_2, 
--        CASE WHEN c.user_id_1 = ? THEN u2.user_id ELSE u1.user_id END as other_user_id,
--        CASE WHEN c.user_id_1 = ? THEN u2.name ELSE u1.name END as other_user_name,
--        m.content as last_message, 
--        m.created_at,
--        COUNT(CASE WHEN m.is_read = 0 AND m.receiver_id = ? THEN 1 END) as unread_count
-- FROM equisplit.conversations c
-- LEFT JOIN equisplit.user u1 ON c.user_id_1 = u1.user_id
-- LEFT JOIN equisplit.user u2 ON c.user_id_2 = u2.user_id
-- LEFT JOIN equisplit.messages m ON c.id = m.conversation_id
-- WHERE c.user_id_1 = ? OR c.user_id_2 = ?
-- GROUP BY c.id
-- ORDER BY c.updated_at DESC;

-- Get messages for a conversation
-- SELECT m.* FROM equisplit.messages m
-- WHERE m.conversation_id = ?
-- ORDER BY m.created_at ASC;

-- Mark messages as read
-- UPDATE equisplit.messages 
-- SET is_read = TRUE 
-- WHERE conversation_id = ? AND receiver_id = ? AND is_read = FALSE;

-- ============================================================
