<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Database connection parameters
$servername = getenv('DB_HOST') ?: "localhost";
$username = getenv('DB_USER') ?: "root";
$password = getenv('DB_PASS') ?: "";
$dbname = getenv('DB_NAME') ?: "trackaccessdb";

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Get the POST data
$raw = file_get_contents("php://input");
$data = json_decode($raw, true);

if ($data && isset($data["student_id"])) {
    $student_id = $data["student_id"];
    $name = isset($data["name"]) ? $data["name"] : null;
    $course = isset($data["course"]) ? $data["course"] : null;
    $year_level = isset($data["year_level"]) ? $data["year_level"] : null;
    $uid = isset($data["uid"]) ? $data["uid"] : null;
    $is_active = isset($data["isActive"]) ? $data["isActive"] : null;
    $points = isset($data["points"]) ? $data["points"] : null;

    // Connect to the DB
    $conn = new mysqli($servername, $username, $password, $dbname);

    if ($conn->connect_error) {
        die(json_encode(["success" => false, "message" => "Connection failed"]));
    }

    $updates = [];
    if ($name !== null) { $updates[] = "name = '$name'"; }
    if ($course !== null) { $updates[] = "course = '$course'"; }
    if ($year_level !== null) { $updates[] = "year_level = '$year_level'"; }
    if ($uid !== null) { $updates[] = "rfid_uid = '$uid'"; }
    if ($is_active !== null) { $updates[] = "is_active = " . ($is_active ? "1" : "0"); }
    if ($points !== null) { $updates[] = "points = $points"; }

    if (empty($updates)) {
        die(json_encode(["success" => false, "message" => "No fields to update"]));
    }

    $sql = "UPDATE students SET " . implode(", ", $updates) . " WHERE student_id = '$student_id'";

    if ($conn->query($sql) === TRUE) {
        echo json_encode(["success" => true, "message" => "Student updated successfully"]);
    } else {
        echo json_encode(["success" => false, "message" => "Error updating student: " . $conn->error]);
    }

    $conn->close();
} else {
    echo json_encode(["success" => false, "message" => "Invalid data parameters"]);
}
?>
