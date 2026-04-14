<?php
header('Content-Type: application/json');
$allowed_origins = [
    'http://localhost:8000',
    'https://your-production-domain.com'
];
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if (in_array($origin, $allowed_origins)) {
    header('Access-Control-Allow-Origin: ' . $origin);
} else {
    header('Access-Control-Allow-Origin: ');
}
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$logFile = __DIR__ . '/debug.log';

$servername = getenv('DB_HOST') ?: "db";
$username = getenv('DB_USER') ?: "root";
$password = getenv('DB_PASS') ?: "password123";
$dbname = getenv('DB_NAME') ?: "trackaccessdb";

$raw = file_get_contents("php://input");
$data = json_decode($raw, true);
if (!$data) {
    $data = $_POST;
}

if ($data && isset($data['username']) && isset($data['password'])) {
    $input_username = trim($data['username']);
    $input_password = trim($data['password']);

    $conn = new mysqli($servername, $username, $password, $dbname);
    if ($conn->connect_error) {
        die(json_encode(["success" => false, "message" => "Database connection failed"]));
    }

    $stmt = $conn->prepare("SELECT * FROM tblusers WHERE usr_username = ? AND usr_password = ?");
    $stmt->bind_param("ss", $input_username, $input_password);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $user = $result->fetch_assoc();
        echo json_encode([
            "success" => true,
            "message" => "Login successful",
            "user" => [
                "id" => $user['usr_id'],
                "fullname" => $user['usr_fullname']
            ]
        ]);
    } else {
        echo json_encode(["success" => false, "message" => "Invalid username or password"]);
    }
    $stmt->close();
    $conn->close();
} else {
    echo json_encode(["success" => false, "message" => "Invalid request: missing username/password"]);
}
