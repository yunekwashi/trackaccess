<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');

// Database connection parameters
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

$sql = "SELECT id, student_id, name, course, year_level, rfid_uid, points, visits, is_active FROM students ORDER BY name ASC";
$result = $conn->query($sql);

$students = [];
if ($result->num_rows > 0) {
    while($row = $result->fetch_assoc()) {
        $students[] = [
            "id" => (int)$row["id"],
            "student_id" => $row["student_id"],
            "name" => $row["name"],
            "course" => $row["course"],
            "yearLevel" => $row["year_level"],
            "uid" => $row["rfid_uid"],
            "points" => (int)$row["points"],
            "visits" => (int)$row["visits"],
            "isActive" => (bool)$row["is_active"]
        ];
    }
}

echo json_encode($students);

$conn->close();
?>
