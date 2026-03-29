<?php
header('Content-Type: application/json');

// login.php
// Simple login script for admin authentication (hardcoded for now)

// Debug logging
$logFile = __DIR__ . '/debug.log';
file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Login attempt: " . print_r($_POST, true) . "\n", FILE_APPEND);

$data = $_POST;
if (empty($data)) {
    $raw = file_get_contents("php://input");
    file_put_contents($logFile, date('[Y-m-d H:i:s] ') . "Raw input: " . $raw . "\n", FILE_APPEND);
    $data = json_decode($raw, true) ?: [];
}

$username = isset($data['username']) ? trim($data['username']) : '';
$password = isset($data['password']) ? trim($data['password']) : '';

// Hardcoded for testing - should be moved to DB in the future
if ($username === 'admin' && $password === 'password123') {
    echo json_encode(["success" => true, "message" => "Login successful"]);
} else {
    echo json_encode(["success" => false, "message" => "Invalid credentials"]);
}
?>
