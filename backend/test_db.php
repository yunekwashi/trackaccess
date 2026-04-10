<?php
header('Content-Type: application/json');
$servername = getenv('DB_HOST') ?: "localhost";
$username = getenv('DB_USER') ?: "root";
$password = getenv('DB_PASS') ?: "";
$dbname = getenv('DB_NAME') ?: "trackaccessdb";

$conn = new mysqli($servername, $username, $password, $dbname);

$response = [
    "status" => "unknown",
    "details" => [
        "servername" => $servername,
        "dbname" => $dbname,
        "username" => $username,
        "password_set" => !empty($password),
        "env_db_host" => getenv('DB_HOST'),
        "php_version" => phpversion()
    ]
];

if ($conn->connect_error) {
    $response["status"] = "error";
    $response["message"] = "Connection failed: " . $conn->connect_error;
} else {
    $response["status"] = "success";
    $response["message"] = "Connected successfully";
    
    // Check if tblusers exists
    $result = $conn->query("SHOW TABLES LIKE 'tblusers'");
    $response["tblusers_exists"] = ($result->num_rows > 0);
    
    if ($response["tblusers_exists"]) {
        $userCount = $conn->query("SELECT COUNT(*) as count FROM tblusers")->fetch_assoc()['count'];
        $response["user_count"] = (int)$userCount;
        
        $admin = $conn->query("SELECT usr_username, usr_password FROM tblusers WHERE usr_username = 'admin'")->fetch_assoc();
        $response["admin_found"] = ($admin !== null);
        if ($admin) {
             // For debugging only, don't do this in production
             $response["admin_password_match"] = ($admin['usr_password'] === 'password123');
        }
    }
    $conn->close();
}

echo json_encode($response);
?>
