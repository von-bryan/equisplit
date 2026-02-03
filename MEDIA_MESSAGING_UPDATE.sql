-- ============================================================
-- MEDIA MESSAGING UPDATE - Add Photo/Video Support to Chat
-- Run these SQL commands in your database
-- ============================================================

-- Add media columns to messages table
ALTER TABLE equisplit.messages 
ADD COLUMN media_type ENUM('text', 'image', 'video') DEFAULT 'text',
ADD COLUMN media_url TEXT NULL;

-- Optional: Add index for better performance when querying media messages
CREATE INDEX idx_media_type ON equisplit.messages(media_type);

-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- Check if columns were added successfully
DESCRIBE equisplit.messages;

-- View sample messages with new columns
SELECT id, sender_id, receiver_id, content, media_type, media_url, created_at 
FROM equisplit.messages 
LIMIT 5;

-- ============================================================
