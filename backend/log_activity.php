<?php
header('Content-Type: application/json');
$allowed_origins = [
    'http://localhost:8000',
    'http://your-production-domain.com'
];
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if (in_array($origin, $allowed_origins)) {
    header('Access-Control-Allow-Origin: ' . $origin);
} else {
    header('Access-Control-Allow-Origin: ');
}
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

$servername = getenv('DB_HOST') ?: "localhost";
$username = getenv('DB_USER') ?: "root";
$password = getenv('DB_PASS') ?: "";
$dbname = getenv('DB_NAME') ?: "trackaccessdb";

// Connect to the DB
$conn = new mysqli($servername, $username, $password, $dbname);

if ($conn->connect_error) {
    die(json_encode(["success" => false, "message" => "Connection failed: " . $conn->connect_error]));
}

// Ensure the table exists
$tableQuery = "CREATE TABLE IF NOT EXISTS activity_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL,
    student_name VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,
    details VARCHAR(255) NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
)";

if (!$conn->query($tableQuery)) {
    die(json_encode(["success" => false, "message" => "Failed to create table"]));
}

// Get the POST data
$data = json_decode(file_get_contents("php://input"), true);

if ($data && isset($data["student_id"]) && isset($data["student_name"]) && isset($data["action"]) && isset($data["details"])) {
    $student_id = $conn->real_escape_string($data["student_id"]);
    $student_name = $conn->real_escape_string($data["student_name"]);
    $action = $conn->real_escape_string($data["action"]);
    $details = $conn->real_escape_string($data["details"]);
    
  $sql = "INSERT INTO activity_logs (student_id, student_name, action, details, timestamp)
            VALUES ('$student_id', '$student_name', '$action', '$details', NOW())";
    if ($conn->query($sql) === true) {
        echo json_encode(["success" => true, "message" => "Activity logged successfully"]);
    } else {
        echo json_encode(["success" => false, "message" => "Error: " . $conn->error]);
    }
} else {
    echo json_encode(["success" => false, "message" => "Invalid data parameters"]);
}

$conn->close();
