CREATE TABLE IF NOT EXISTS posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS stats (
    id INT PRIMARY KEY,
    visit_count INT DEFAULT 0
);

INSERT INTO stats (id, visit_count) VALUES (1, 0)
ON DUPLICATE KEY UPDATE id = id;

INSERT INTO posts (title, content) VALUES
('Welcome to PKHosting Sample Site', 'This is a demo website used to test automated backup and restore procedures for PKHosting.com customers.'),
('Why Automated Backups Matter', 'Regular backups protect against data loss caused by hardware failure, accidental deletion, or security incidents. PKHosting recommends daily backups with 7-day retention.'),
('How Restore Works', 'In case of an issue, the restore script can bring both files and database back to a known good state within minutes.');
