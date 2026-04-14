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

$servername = getenv('DB_HOST') ?: "db";
$username = getenv('DB_USER') ?: "root";
$password = getenv('DB_PASS') ?: "password123";
$dbname = getenv('DB_NAME') ?: "trackaccessdb";

$raw = file_get_contents("php://input");
$data = json_decode($raw, true);

if (!$data) {
    $data = $_POST;
}

if ($data && isset($data['student_id']) && isset($data['name']) && isset($data['rfid_uid'])) {
    $student_id = trim($data['student_id']);
    $name = trim($data['name']);
    $rfid_uid = trim($data['rfid_uid']);
    $course = isset($data['course']) ? trim($data['course']) : 'N/A';
    $year_level = isset($data['year_level']) ? trim($data['year_level']) : 'N/A';

    $conn = new mysqli($servername, $username, $password, $dbname);
    if ($conn->connect_error) {
        die(json_encode(["success" => false, "message" => "Database connection failed"]));
    }

    // Check if student_id or rfid_uid already exists
    $stmt_check = $conn->prepare("SELECT id FROM students WHERE student_id = ? OR rfid_uid = ?");
    $stmt_check->bind_param("ss", $student_id, $rfid_uid);
    $stmt_check->execute();
    $result = $stmt_check->get_result();

    if ($result->num_rows > 0) {
        echo json_encode(["success" => false, "message" => "Student ID or RFID already registered."]);
    } else {
        // Insert new student
        $stmt_insert = $conn->prepare("INSERT INTO students (student_id, name, course, year_level, rfid_uid, points, visits, is_active) VALUES (?, ?, ?, ?, ?, 0, 0, 1)");
        $stmt_insert->bind_param("sssss", $student_id, $name, $course, $year_level, $rfid_uid);
        
        if ($stmt_insert->execute()) {
            echo json_encode(["success" => true, "message" => "Student registered successfully."]);
        } else {
            echo json_encode(["success" => false, "message" => "Error registering student: " . $conn->error]);
        }
        $stmt_insert->close();
    }
    
    $stmt_check->close();
    $conn->close();
} else {
    echo json_encode(["success" => false, "message" => "Invalid data: Missing required fields"]);
}
