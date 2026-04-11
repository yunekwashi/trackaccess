<?php
header('Content-Type: application/json');

// get_all_scans.php
// Returns all RFID scans recorded in the database, ordered by time

$servername = getenv('DB_HOST') ?: "localhost";
$username = getenv('DB_USER') ?: "root";
$password = getenv('DB_PASS') ?: "";
$dbname = getenv('DB_NAME') ?: "trackaccessdb";

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    die(json_encode(["success" => false, "message" => "Connection failed"]));
}

$sql = "SELECT id, student_id, student_name, action, details, timestamp FROM activity_logs ORDER BY timestamp DESC";
$result = $conn->query($sql);

$logs = [];
if ($result && $result->num_rows > 0) {
    while($row = $result->fetch_assoc()) {
        $logs[] = $row;
    }
}

echo json_encode([
    "success" => true,
    "count" => count($logs),
    "logs" => $logs
]);

$conn->close();
?>
