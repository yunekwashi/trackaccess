# ESP32 and RC522 RFID Scanner Setup

This directory contains the firmware and setup instructions for your ESP32 + RC522 RFID scanner.

## 1. Wiring Guide (SPI Connection)

Connect your RC522 RFID module to the ESP32 using the following pins:

| RC522 Pin | ESP32 Pin | Notes |
| :--- | :--- | :--- |
| **SDA (SS)** | GPIO 5 | SPI Chip Select |
| **SCK** | GPIO 18 | SPI Clock |
| **MOSI** | GPIO 23 | SPI Master Out Slave In |
| **MISO** | GPIO 19 | SPI Master In Slave Out |
| **IRQ** | - | *Not connected* |
| **GND** | GND | Ground |
| **RST** | GPIO 22                                                                                                                                                                          | Reset |
| **3.3V** | 3.3V | **CRITICAL: Do NOT connect to 5V!** The RC522 is a 3.3V device. |

## 2. Arduino IDE Setup

1. **Install the ESP32 Board Manager**:
   - Go to `File` -> `Preferences`
   - Add `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json` to "Additional Boards Manager URLs"
   - Go to `Tools` -> `Board` -> `Boards Manager`, search for **esp32** and install it.
2. **Select your Board**:
   - Go to `Tools` -> `Board` and select **DOIT ESP32 DEVKIT V1** (or your specific model).
3. **Install the MFRC522 Library**:
   - Go to `Sketch` -> `Include Library` -> `Manage Libraries...`
   - Search for **MFRC522** (by GithubCommunity) and install it.
   - Search for **ArduinoJson** (by Benoit Blanchon) and install it (used for API requests).

## 3. Uploading the Code

1. Open `arduino_rfid_scanner.ino` in the Arduino IDE.
2. Update the `WIFI_SSID` and `WIFI_PASSWORD` with your network details.
3. Update the `SERVER_URL` to point to your XAMPP backend (e.g., `http://192.168.1.xxx/trackaccess_api/scan.php`).
4. Connect the ESP32 to your PC via USB.
5. Select the correct COM port in `Tools` -> `Port`.
6. Click **Upload**. (If it fails to connect, you may need to hold the "BOOT" button on the ESP32 when you see "Connecting...").

## 4. Integration with TrackAccess Backend

The provided code sends a POST request with the scanned RFID UID (`{"uid": "A1B2C3D4"}`) to your backend. Your XAMPP PHP backend should receive this, check the database, log the attendance, and then the Flutter app can fetch the updated logs.
