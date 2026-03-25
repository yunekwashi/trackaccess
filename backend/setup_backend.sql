-- Connect to your trackaccessdb in PHPMyAdmin and run this:

CREATE TABLE IF NOT EXISTS scans (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uid VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index the created_at column for faster sorting by get_latest.php
CREATE INDEX idx_created_at ON scans(created_at);
