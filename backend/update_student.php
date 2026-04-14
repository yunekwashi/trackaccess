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

header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

$servername = getenv('DB_HOST') ?: "localhost";
$username   = getenv('DB_USER') ?: "root";
$password   = getenv('DB_PASS') ?: "";
$dbname     = getenv('DB_NAME') ?: "trackaccessdb";

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$raw  = file_get_contents("php://input");
$data = json_decode($raw, true);

if (!$data || !isset($data["student_id"])) {
    echo json_encode(["success" => false, "message" => "Invalid data parameters"]);
    exit;
}

$student_id = $data["student_id"];
$name       = $data["name"]       ?? null;
$course     = $data["course"]     ?? null;
$year_level = $data["year_level"] ?? null;
$uid        = $data["uid"]        ?? null;
$is_active  = $data["isActive"]   ?? null;
$points     = $data["points"]     ?? null;

$conn = new mysqli($servername, $username, $password, $dbname);
if ($conn->connect_error) {
    echo json_encode(["success" => false, "message" => "Connection failed"]);
    exit;
}

$setClauses = [];
$bindTypes  = "";
$bindValues = [];

if ($name !== null)       { $setClauses[] = "name = ?";       $bindTypes .= "s"; $bindValues[] = $name; }
if ($course !== null)     { $setClauses[] = "course = ?";     $bindTypes .= "s"; $bindValues[] = $course; }
if ($year_level !== null) { $setClauses[] = "year_level = ?"; $bindTypes .= "s"; $bindValues[] = $year_level; }
if ($uid !== null)        { $setClauses[] = "rfid_uid = ?";   $bindTypes .= "s"; $bindValues[] = $uid; }
if ($is_active !== null)  { $setClauses[] = "is_active = ?";  $bindTypes .= "i"; $bindValues[] = $is_active ? 1 : 0; }
if ($points !== null)     { $setClauses[] = "points = ?";     $bindTypes .= "i"; $bindValues[] = $points; }

if (empty($setClauses)) {
    echo json_encode(["success" => false, "message" => "No fields to update"]);
    $conn->close();
    exit;
}

$bindTypes  .= "s";
$bindValues[] = $student_id;

$sql  = "UPDATE students SET " . implode(", ", $setClauses) . " WHERE student_id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param($bindTypes, ...$bindValues);

if ($stmt->execute()) {
    echo json_encode(["success" => true, "message" => "Student updated successfully"]);
} else {
    echo json_encode(["success" => false, "message" => "Error updating student: " . $stmt->error]);
}

$stmt->close();
$conn->close();
