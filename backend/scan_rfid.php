<?php
header('Content-Type: application/json');

// scan_rfid.php
// Receives UID from ESP32 and saves it to the database

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

// Get the POST data from the ESP32
$data = json_decode(file_get_contents("php://input"), true);

if ($data && isset($data["uid"])) {
    $uid = $conn->real_escape_string($data["uid"]);
    
    // Save the scan with a timestamp
    $sql = "INSERT INTO scans (uid, created_at) VALUES ('$uid', NOW())";
    
    if ($conn->query($sql) === true) {
        echo json_encode(["success" => true, "message" => "Scan recorded successfully"]);
    } else {
        echo json_encode(["success" => false, "message" => "Error recording scan: " . $conn->error]);
    }
} else {
    echo json_encode(["success" => false, "message" => "Invalid data"]);
}

$conn->close();
