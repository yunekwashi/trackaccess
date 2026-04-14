<?php
/**
 * TrackAccess Dashboard
 * This is the main entry point for the backend service.
 * It provides a premium visual interface to monitor the system status and activity.
 */

// Database connection parameters (matching existing scripts)
$servername = getenv('DB_HOST') ?: "localhost";
$username = getenv('DB_USER') ?: "root";
$password = getenv('DB_PASS') ?: "";
$dbname = getenv('DB_NAME') ?: "trackaccessdb";

// Connect to the DB
$conn = new mysqli($servername, $username, $password);
$db_connected = false;
$stats = [
    'students' => 0,
    'logs_today' => 0,
    'total_logs' => 0
];
$recent_logs = [];

if (!$conn->connect_error) {
    if ($conn->select_db($dbname)) {
        $db_connected = true;
        
        // Ensure activity_logs table exists (to prevent fatal errors on fresh installations)
        $conn->query("CREATE TABLE IF NOT EXISTS activity_logs (
            id INT AUTO_INCREMENT PRIMARY KEY,
            student_id VARCHAR(50) NOT NULL,
            student_name VARCHAR(100) NOT NULL,
            action VARCHAR(50) NOT NULL,
            details VARCHAR(255) NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )");

        // Fetch Stats - Students
        $res = $conn->query("SELECT COUNT(*) as count FROM students");
        if ($res && $res->num_rows > 0) {
            $stats['students'] = $res->fetch_assoc()['count'];
        }

        // Fetch Stats - Total Logs
        $res = $conn->query("SELECT COUNT(*) as count FROM activity_logs");
        if ($res && $res->num_rows > 0) {
            $stats['total_logs'] = $res->fetch_assoc()['count'];
        }

        // Fetch Stats - Logs Today
        $res = $conn->query("SELECT COUNT(*) as count FROM activity_logs WHERE DATE(timestamp) = CURDATE()");
        if ($res && $res->num_rows > 0) {
            $stats['logs_today'] = $res->fetch_assoc()['count'];
        
        // Fetch Recent Logs
        $res = $conn->query("SELECT * FROM activity_logs ORDER BY timestamp DESC LIMIT 10");
        if ($res && $res->num_rows > 0) {
            while($row = $res->fetch_assoc()) {
                $recent_logs[] = $row;
            }
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TrackAccess Dashboard</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;700&family=Plus+Jakarta+Sans:wght@300;400;600;700&display=swap"
      rel="stylesheet"
      crossorigin="anonymous">
    <style>
        :root {
            --primary: #6366f1;
            --primary-light: #818cf8;
            --bg: #0f172a;
            --card-bg: rgba(30, 41, 59, 0.7);
            --border: rgba(255, 255, 255, 0.1);
            --text-main: #f8fafc;
            --text-dim: #94a3b8;
            --success: #10b981;
            --error: #ef4444;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
        }

        body {
            background-color: var(--bg);
            background-image: 
                radial-gradient(at 0% 0%, rgba(99, 102, 241, 0.15) 0px, transparent 50%),
                radial-gradient(at 100% 100%, rgba(139, 92, 246, 0.15) 0px, transparent 50%);
            color: var(--text-main);
            min-height: 100vh;
            padding: 2rem;
            display: flex;
            flex-direction: column;
            align-items: center;
        }

        .container {
            width: 100%;
            max-width: 1200px;
        }

        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 3rem;
            width: 100%;
        }

        .logo-section h1 {
            font-family: 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
            font-size: 2rem;
            font-weight: 700;
            background: linear-gradient(135deg, #fff 0%, #818cf8 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            letter-spacing: -0.02em;
        }

        .status-badge {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.5rem 1rem;
            background: var(--card-bg);
            border: 1px border var(--border);
            border-radius: 99px;
            font-size: 0.875rem;
            backdrop-filter: blur(10px);
        }

        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background-color: <?php echo $db_connected ? 'var(--success)' : 'var(--error)'; ?>;
            box-shadow: 0 0 10px <?php echo $db_connected ? 'var(--success)' : 'var(--error)'; ?>;
        }

        /* Stats Grid */
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 1.5rem;
            margin-bottom: 3rem;
        }

        .stat-card {
            background: var(--card-bg);
            border: 1px solid var(--border);
            padding: 2rem;
            border-radius: 1.5rem;
            backdrop-filter: blur(16px);
            transition: transform 0.3s ease, border-color 0.3s ease;
        }

        .stat-card:hover {
            transform: translateY(-5px);
            border-color: var(--primary-light);
        }

        .stat-card h3 {
            color: var(--text-dim);
            font-size: 0.875rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin-bottom: 0.5rem;
        }

        .stat-card .value {
            font-size: 2.5rem;
            font-weight: 700;
            color: #fff;
        }

        /* Content Section */
        .content-layout {
            display: grid;
            grid-template-columns: 2fr 1fr;
            gap: 1.5rem;
        }

        @media (max-width: 900px) {
            .content-layout {
                grid-template-columns: 1fr;
            }
        }

        .panel {
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 1.5rem;
            padding: 1.5rem;
            backdrop-filter: blur(16px);
        }

        .panel h2 {
            font-size: 1.25rem;
            margin-bottom: 1.5rem;
            display: flex;
            align-items: center;
            gap: 0.75rem;
        }

        /* Activity Table */
        .activity-table-wrapper {
            overflow-x: auto;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            text-align: left;
        }

        th {
            color: var(--text-dim);
            font-weight: 600;
            font-size: 0.75rem;
            text-transform: uppercase;
            padding: 1rem;
            border-bottom: 1px solid var(--border);
        }

        td {
            padding: 1rem;
            border-bottom: 1px solid var(--border);
            font-size: 0.875rem;
        }

        tr:last-child td {
            border-bottom: none;
        }

        .badge-action {
            display: inline-block;
            padding: 0.25rem 0.5rem;
            border-radius: 0.375rem;
            font-size: 0.75rem;
            font-weight: 600;
            background: rgba(99, 102, 241, 0.2);
            color: var(--primary-light);
        }

        /* Sidebar/Quick Actions */
        .action-list {
            display: flex;
            flex-direction: column;
            gap: 0.75rem;
        }

        .action-btn {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 1rem;
            background: rgba(255, 255, 255, 0.03);
            border: 1px solid var(--border);
            border-radius: 1rem;
            text-decoration: none;
            color: var(--text-main);
            transition: all 0.2s ease;
        }

        .action-btn:hover {
            background: rgba(255, 255, 255, 0.08);
            border-color: var(--primary-light);
            padding-left: 1.25rem;
        }

        .action-btn i {
            color: var(--primary-light);
        }

        .error-msg {
            color: var(--error);
            font-size: 0.875rem;
            margin-top: 1rem;
            padding: 1rem;
            background: rgba(239, 68, 68, 0.1);
            border-radius: 0.75rem;
            border: 1px solid rgba(239, 68, 68, 0.2);
        }

        /* Animations */
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }

        .animate {
            animation: fadeIn 0.5s ease-out forwards;
        }

        .delay-1 { animation-delay: 0.1s; }
        .delay-2 { animation-delay: 0.2s; }
        .delay-3 { animation-delay: 0.3s; }
    </style>
</head>
<body>
    <div class="container">
        <header class="animate">
            <div class="logo-section">
                <h1>TrackAccess Dashboard</h1>
            </div>
            <div class="status-badge">
                <div class="status-dot"></div>
                <span>Database: <?php echo $db_connected ? 'Connected' : 'Offline'; ?></span>
            </div>
        </header>

        <?php if (!$db_connected): ?>
            <div class="error-msg animate">
                <strong>Attention:</strong> Could not connect to the database. Please ensure your Docker services are running and check the <code>.env</code> file configuration.
                <br>Error: <?php echo $conn->connect_error; ?>
            </div>
        <?php endif; ?>

        <div class="stats-grid animate delay-1">
            <div class="stat-card">
                <h3>Total Registered Students</h3>
                <div class="value"><?php echo number_format($stats['students']); ?></div>
            </div>
            <div class="stat-card">
                <h3>Scans Recorded Today</h3>
                <div class="value"><?php echo number_format($stats['logs_today']); ?></div>
            </div>
            <div class="stat-card">
                <h3>System Logs Total</h3>
                <div class="value"><?php echo number_format($stats['total_logs']); ?></div>
            </div>
        </div>

        <div class="content-layout">
            <div class="panel animate delay-2">
                <h2>Recent Activity Logs</h2>
                <div class="activity-table-wrapper">
                    <table>
                        <thead>
                            <tr>
                                <th>Student</th>
                                <th>Action</th>
                                <th>Details</th>
                                <th>Time</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($recent_logs)): ?>
                                <tr>
                                    <td colspan="4" style="text-align: center; color: var(--text-dim); padding: 3rem;">No recent logs found. Start scanning to see data!</td>
                                </tr>
                            <?php else: ?>
                                <?php foreach ($recent_logs as $log): ?>
                                    <tr>
                                        <td>
                                            <div style="font-weight: 600;"><?php echo htmlspecialchars($log['student_name']); ?></div>
                                            <div style="font-size: 0.75rem; color: var(--text-dim);"><?php echo htmlspecialchars($log['student_id']); ?></div>
                                        </td>
                                        <td><span class="badge-action"><?php echo htmlspecialchars($log['action']); ?></span></td>
                                        <td style="color: var(--text-dim);"><?php echo htmlspecialchars($log['details']); ?></td>
                                        <td style="white-space: nowrap;"><?php echo date('H:i:s', strtotime($log['timestamp'])); ?></td>
                                    </tr>
                                <?php endforeach; ?>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>

            <div class="panel animate delay-3">
                <h2>Quick Actions</h2>
                <div class="action-list">
                    <a href="http://localhost:8001" target="_blank" class="action-btn">
                        <span>Database Management (PMA)</span>
                        <i>&rarr;</i>
                    </a>
                    <a href="get_students.php" target="_blank" class="action-btn">
                        <span>View Students JSON</span>
                        <i>&rarr;</i>
                    </a>
                    <a href="get_all_scans.php" target="_blank" class="action-btn">
                        <span>View Scan Logs JSON</span>
                        <i>&rarr;</i>
                    </a>
                    <a href="test_db.php" target="_blank" class="action-btn">
                        <span>System Health Test</span>
                        <i>&rarr;</i>
                    </a>
                </div>

                <div style="margin-top: 2rem; padding: 1rem; background: rgba(255,255,255,0.03); border-radius: 1rem; border: 1px dashed var(--border);">
                    <h4 style="font-size: 0.875rem; margin-bottom: 0.5rem; color: var(--primary-light);">Developer Note</h4>
                    <p style="font-size: 0.75rem; color: var(--text-dim); line-height: 1.5;">
                        This dashboard is served from the <code>trackaccess_app</code> container. All API endpoints are accessible via this host.
                    </p>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
