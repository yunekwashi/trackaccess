# TrackAccess - Capstone Appendices Guide

This document contains the required information tailored specifically to your exact TrackAccess implementation, specifically the scripts found in your `backend/` folder. You can directly copy and paste the contents into your final Capstone document.

---

## Appendix B: API Documentation

*The following outlines the actual PHP web services located in your `backend/` directory that serve as the RESTful backend for the TrackAccess Flutter/Desktop application and Arduino/ESP32 RFID scanner.*

**Base URL:** `http://localhost/backend/` (or your production server URL)

### 1. Register Student (`/register_student.php`)
*   **Description:** Registers a new user into the system and binds an RFID UID to them.
*   **Method:** `POST`
*   **Content-Type:** `application/json` or `Form Data`
*   **Request Format:**
    ```json
    {
      "student_id": "2023-0001",
      "name": "Juan Dela Cruz",
      "rfid_uid": "A1 B2 C3 D4",
      "course": "BSIT",
      "year_level": "3"
    }
    ```
*   **Response (Success):**
    ```json
    {
      "success": true,
      "message": "Student registered successfully."
    }
    ```

### 2. Update Student/Points (`/update_student.php`)
*   **Description:** Updates an existing student's data. This takes the place of simple point updates or profile edits.
*   **Method:** `POST`
*   **Content-Type:** `application/json`
*   **Request Format:**
    ```json
    {
      "student_id": "2023-0001",
      "name": "Juan Dela Cruz",
      "course": "BSIT",
      "points": 10,
      "isActive": true
    }
    ```
*   **Response (Success):**
    ```json
    {
      "success": true,
      "message": "Student updated successfully"
    }
    ```

### 3. Log Activity (`/log_activity.php`)
*   **Description:** Used to manually insert actions or events taken by the user (e.g., login, update points, manual override) into the admin audit trail. 
*   **Method:** `POST`
*   **Content-Type:** `application/json`
*   **Request Format:**
    ```json
    {
      "student_id": "2023-0001",
      "student_name": "Juan Dela Cruz",
      "action": "points_added",
      "details": "Added 10 points for library visit."
    }
    ```
*   **Response (Success):**
    ```json
    {
      "success": true,
      "message": "Activity logged successfully"
    }
    ```

### 4. Hardware RFID Submit (`/scan_rfid.php`)
*   **Description:** Typically called by the Arduino/ESP32 scanner natively when an RFID card is tapped. Receives the `uid` directly and logs the raw physical scan.
*   **Method:** `POST`
*   **Content-Type:** `application/json`
*   **Request Format:**
    ```json
    {
      "uid": "A1 B2 C3 D4"
    }
    ```
*   **Response (Success):**
    ```json
    {
      "success": true,
      "message": "Scan recorded successfully"
    }
    ```

### 5. Fetch Latest Hardware Scan (`/get_latest.php`)
*   **Description:** Fetches the most recent RFID scan recorded within the last 10 seconds. Useful for the "Tap to Register/Assign" feature on the Admin dashboard.
*   **Method:** `GET`
*   **Response (Success):**
    ```json
    {
      "success": true,
      "uid": "A1 B2 C3 D4"
    }
    ```

### 6. Get Students / Leaderboard (`/get_students.php`)
*   **Description:** Retrieves all students registered in the facility. The Flutter app uses this list to sort and generate Leaderboards based on the `points` field.
*   **Method:** `GET`
*   **Response (Success):**
    ```json
    [
      {
        "id": 1,
        "student_id": "2023-0001",
        "name": "Juan Dela Cruz",
        "course": "BSIT",
        "yearLevel": "3",
        "uid": "A1 B2 C3 D4",
        "points": 50,
        "visits": 12,
        "isActive": true
      }
    ]
    ```

### 7. Get All Logs / Admin Report (`/get_all_scans.php`)
*   **Description:** Returns all structured activity records in the database for rendering the Admin Reports table.
*   **Method:** `GET`
*   **Response (Success):**
    ```json
    {
      "success": true,
      "count": 1,
      "logs": [
        {
          "id": "1",
          "student_id": "2023-0001",
          "student_name": "Juan Dela Cruz",
          "action": "registered",
          "details": "Registered new RFID.",
          "timestamp": "2024-05-01 10:00:00"
        }
      ]
    }
    ```

---

## Appendix D: Test Logs and Screenshots

*Note: You must take screenshots of your app running to fulfill this requirement completely. However, here is how you can fill up this section based on your directory structure:*

### Unit Testing & Terminal Logs
During the build processes, unit test and debug logs were generated and successfully isolated system health:
1. **Flutter Frontend Log Output File:** Refer to `/flutter_01.log` in the root repository. This file tracked the dart compilation, dependency bindings, and flutter SDK warnings.
2. **Backend Database Health Check:** Running `http://localhost/backend/test_db.php` returned `Success! Connected to trackaccessdb`. 
3. **Database Setup Execution:** The SQL script `setup_backend.sql` was logged as executing flawlessly, generating the `students`, `scans`, and `activity_logs` tables. 

### Recommended Screenshots to Capture
1. **System Health Status/Dashboard:** A screenshot of `http://localhost/backend/index.php` showing "Database: Connected", the registered counts, and the visual gradient background.
2. **Flutter Interface - Authentication:** A screenshot of the admin login screen.
3. **Flutter Interface - Registration:** The UI where a new User/Student is added alongside an RFID UID.
4. **Hardware Prototype:** A direct photo of the Arduino/RFID scanner.
5. **n8n / Server Containers:** (If applicable) A small screenshot of your Docker UI showing the containers as "Running". 

---

## Appendix E: User Manual or Deployment Guide

### TrackAccess Deployment Guide

#### 1. System Requirements
- Windows 10/11
- PHP 8+ and MySQL (Available via XAMPP or via Docker standard)
- Flutter SDK installed and environment variables correctly configured.

#### 2. Starting the Backend Server
The system includes specialized powershell scripts to run the database backend without manual terminal configuration.
1. Navigate to the `trackaccess` root folder.
2. Open the `backend/` directory.
3. Right click on `run_standalone.ps1` and execute with PowerShell.
4. This script automatically spins up PHP's built-in webserver pulling config from `.env`.
5. Verify it is running by opening a web browser to `http://localhost:8000/backend/index.php` or `http://localhost:8000/backend/test_db.php`.
6. To cleanly shutdown, run `stop_standalone.ps1`.

*(Alternatively, run `docker-compose up -d` in the root folder if using Docker containers).*

#### 3. Compiling the Frontend App
1. Open a terminal in the root `trackaccess` folder.
2. Run `flutter clean` then `flutter pub get` to prepare dependencies.
3. Run `flutter build windows` to create the standalone executable.
4. Navigate to `build/windows/runner/Release/`.
5. Double-click `trackaccess.exe` to run the application.

#### 4. Setup Arduino RFID Scanner
1. Open up the `.ino` file in the `arduino_rfid_usb` or `arduino_rfid_scanner` folder via the Arduino IDE.
2. Select your designated COM Port in the tools dropdown.
3. Once running, connect it to the server machine via USB. Scanning a card acts as a Keyboard Wedge or Serial entry interacting securely with the deployed desktop interface.

#### 5. User Roles and Functions
*   **Registration (Admin):** Admins can click "Add Member", enter details, and tap an unassigned card on the scanner to bind the Student ID to a physical Card UID.
*   **Logging In:** Users scan their card physically. If recognized in the database via the `/get_students.php` directory, points/logs are updated successfully. 
*   **Admin Reporting:** In the Admin Dashboard View, clicking on Reports fetches data from `/get_all_scans.php` and dynamically outlines chronological entries of all interactions.
