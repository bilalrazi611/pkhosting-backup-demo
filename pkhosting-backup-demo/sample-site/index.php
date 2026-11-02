<?php
/**
 * PKHosting Sample Website
 * Simple demo site with database connection for backup/restore testing
 */

$host = getenv('DB_HOST') ?: 'db';
$db   = getenv('DB_NAME') ?: 'sample_site';
$user = getenv('DB_USER') ?: 'siteuser';
$pass = getenv('DB_PASS') ?: 'sitepass123';

$mysqli = new mysqli($host, $user, $pass, $db);

if ($mysqli->connect_error) {
    die("Database connection failed: " . $mysqli->connect_error);
}

// Fetch latest posts
$result = $mysqli->query("SELECT id, title, content, created_at FROM posts ORDER BY created_at DESC LIMIT 10");
$posts = [];
if ($result) {
    while ($row = $result->fetch_assoc()) {
        $posts[] = $row;
    }
}

// Simple visitor counter
$mysqli->query("UPDATE stats SET visit_count = visit_count + 1 WHERE id = 1");
$stats = $mysqli->query("SELECT visit_count FROM stats WHERE id = 1")->fetch_assoc();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PKHosting Sample Site</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: system-ui, -apple-system, sans-serif; background: #f4f6f8; color: #222; line-height: 1.6; }
        header { background: #0d6efd; color: white; padding: 1.5rem 2rem; }
        header h1 { font-size: 1.6rem; }
        header p { opacity: 0.9; font-size: 0.95rem; }
        .container { max-width: 800px; margin: 2rem auto; padding: 0 1rem; }
        .card { background: white; border-radius: 8px; padding: 1.5rem; margin-bottom: 1rem; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
        .card h2 { font-size: 1.2rem; margin-bottom: 0.5rem; color: #0d6efd; }
        .meta { font-size: 0.85rem; color: #666; margin-bottom: 0.75rem; }
        .stats { background: #e7f1ff; border-left: 4px solid #0d6efd; }
        footer { text-align: center; padding: 2rem; color: #888; font-size: 0.9rem; }
    </style>
</head>
<body>
    <header>
        <h1>PKHosting Sample Website</h1>
        <p>Demo site for automated backup & restore testing</p>
    </header>

    <div class="container">
        <div class="card stats">
            <strong>Total visits recorded:</strong> <?= htmlspecialchars($stats['visit_count'] ?? 0) ?>
        </div>

        <?php if (empty($posts)): ?>
            <div class="card">
                <p>No posts found. Database may be empty.</p>
            </div>
        <?php else: ?>
            <?php foreach ($posts as $post): ?>
                <div class="card">
                    <h2><?= htmlspecialchars($post['title']) ?></h2>
                    <div class="meta">Posted on <?= htmlspecialchars($post['created_at']) ?></div>
                    <p><?= nl2br(htmlspecialchars($post['content'])) ?></p>
                </div>
            <?php endforeach; ?>
        <?php endif; ?>
    </div>

    <footer>
        PKHosting Backup Demo &bull; Powered by PHP + MySQL
    </footer>
</body>
</html>
<?php $mysqli->close(); ?>
