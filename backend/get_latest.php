<?php
header('Content-Type: application/json');

// get_latest.php
// Returns the most recent RFID scan recorded in the database

$servername = "localhost";
$username = "root";
$password = "";
$dbname = "trackaccessdb";

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    die(json_encode(["success" => false, "message" => "Connection failed"]));
}

// Fetch the most recent scan from the last 10 seconds to ensure it's "fresh"
$sql = "SELECT uid FROM scans WHERE created_at >= NOW() - INTERVAL 10 SECOND ORDER BY created_at DESC LIMIT 1";
$result = $conn->query($sql);

if ($result->num_rows > 0) {
    $row = $result->fetch_assoc();
    echo json_encode([
        "success" => true,
        "uid" => $row["uid"]
    ]);
} else {
    echo json_encode([
        "success" => false,
        "message" => "No recent scans found"
    ]);
}

$conn->close();
?>
