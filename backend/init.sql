-- Combined database initialization script for TrackAccess

-- Ensure we are using the correct database
USE trackaccessdb;

-- Create table for users (from trackaccessdb.sql)
CREATE TABLE IF NOT EXISTS `tblusers` (
  `usr_id` int(11) NOT NULL AUTO_INCREMENT,
  `usr_username` varchar(50) NOT NULL,
  `usr_password` varchar(255) NOT NULL,
  `usr_fullname` varchar(50) NOT NULL,
  PRIMARY KEY (`usr_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Insert initial users if not present
INSERT IGNORE INTO `tblusers` (`usr_id`, `usr_username`, `usr_password`, `usr_fullname`) VALUES
(1, 'admin', 'admin', 'Library Admin'),
(2, 'admin1', 'password123', 'Librarian');

-- Create table for scans (from setup_backend.sql)
CREATE TABLE IF NOT EXISTS scans (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uid VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index the created_at column for faster sorting
-- (Removing IF NOT EXISTS as it's not standard MySQL syntax for CREATE INDEX)
CREATE INDEX idx_created_at ON scans(created_at);

-- Create table for students
CREATE TABLE IF NOT EXISTS students (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    course VARCHAR(100) DEFAULT 'N/A',
    year_level VARCHAR(50) DEFAULT 'N/A',
    rfid_uid VARCHAR(50) NOT NULL UNIQUE,
    points INT DEFAULT 0,
    visits INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert initial students (migrating from Dart hardcoded data)
INSERT IGNORE INTO students (student_id, name, course, year_level, rfid_uid, points, visits) VALUES
('2023-001', 'Alice', 'BSIT', '1st Year', 'A1', 0, 0),
('2023-002', 'Bob', 'BSCS', '2nd Year', 'B2', 0, 0),
('2023-003', 'Charlie', 'BSCrim', '3rd Year', 'C3', 0, 0),
('2023-004', 'Diana', 'BSED', '4th Year', 'D4', 0, 0);

