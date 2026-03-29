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

$sql = "SELECT uid, created_at FROM scans ORDER BY created_at ASC";
$result = $conn->query($sql);

$scans = [];
if ($result->num_rows > 0) {
    while($row = $result->fetch_assoc()) {
        $scans[] = $row;
    }
}

echo json_encode([
    "success" => true,
    "scans" => $scans
]);

$conn->close();
?>
