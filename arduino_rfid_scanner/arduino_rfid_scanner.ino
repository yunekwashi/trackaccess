#include <WiFi.h>
#include <HTTPClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ArduinoJson.h>

// ----------------------------------------------------------------------------
// WIRING (ESP32 to RC522)
// ----------------------------------------------------------------------------
// SDA (SS) -> GPIO 5
// SCK      -> GPIO 18
// MOSI     -> GPIO 23
// MISO     -> GPIO 19
// RST      -> GPIO 22
// GND      -> GND
// 3.3V     -> 3.3V (DO NOT USE 5V)
// ----------------------------------------------------------------------------

#define RST_PIN         22
#define SS_PIN          5

// Network credentials
const char* WIFI_SSID     = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// XAMPP Backend API URL (Replace with your PC's local IP address)
const char* SERVER_URL    = "http://192.168.254.159:8080/scan_rfid.php";

MFRC522 mfrc522(SS_PIN, RST_PIN);

void setup() {
  Serial.begin(115200);
  delay(2000); // Wait for power to stabilize
  Serial.println(F("\n--- ESP32 RFID DIAGNOSTIC START ---"));
  Serial.flush();

  Serial.println(F("Step 1: Initializing SPI..."));
  Serial.flush();
  // Initialize SPI bus with explicit pins for ESP32 VSPI
  SPI.begin(18, 19, 23, 5); 
  Serial.println(F("SPI Initialized."));
  Serial.flush();
  
  Serial.println(F("Step 2: Initializing MFRC522..."));
  Serial.flush();
  mfrc522.PCD_Init();
  delay(10);
  Serial.println(F("MFRC522 Initialized."));
  Serial.flush();
  
  // Show details of PCD (RFID Reader)
  Serial.print(F("Step 3: Reading Version..."));
  byte v = mfrc522.PCD_ReadRegister(mfrc522.VersionReg);
  Serial.print(F(" Version Byte: 0x"));
  Serial.println(v, HEX);
  Serial.flush();
  
  // Check if initialization actually worked
  if (v == 0x00 || v == 0xFF) {
    Serial.println(F("CRITICAL: Communication failure! Check wiring and SOLDERING."));
    while(true); // Stop execution if hardware is not found
  }
  
  Serial.println(F("Connecting to WiFi..."));
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println(F("\nWiFi connected!"));
  Serial.print(F("IP Address: "));
  Serial.println(WiFi.localIP());
  
  Serial.println(F("\n--- ESP32 RFID Scanner Ready ---"));
  Serial.println(F("Please tap a card to the reader..."));
}

void loop() {
  // Check if WiFi is still connected
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi lost. Reconnecting...");
    WiFi.reconnect();
    delay(5000);
    return;
  }

  // Look for new RFID cards
  if (!mfrc522.PICC_IsNewCardPresent()) {
    return;
  }

  // Select one of the cards
  if (!mfrc522.PICC_ReadCardSerial()) {
    return;
  }

  // Card found! Read the UID
  String uidStr = "";
  for (byte i = 0; i < mfrc522.uid.size; i++) {
    uidStr += String(mfrc522.uid.uidByte[i] < 0x10 ? "0" : "");
    uidStr += String(mfrc522.uid.uidByte[i], HEX);
  }
  uidStr.toUpperCase();
  
  Serial.print(F("Card Scanned! UID: "));
  Serial.println(uidStr);

  // Halt PICC to stop reading the same card multiple times instantly
  mfrc522.PICC_HaltA();
  // Stop encryption on PCD
  mfrc522.PCD_StopCrypto1();
  
  // Send the UID to the backend
  sendUIDToBackend(uidStr);
  
  // Add a small delay so we don't spam the server
  delay(2000);
  Serial.println(F("\nReady for next card..."));
}

void sendUIDToBackend(String uid) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    
    // Start HTTP connection
    http.begin(SERVER_URL);
    
    // Specify content type (JSON)
    http.addHeader("Content-Type", "application/json");

    // Create JSON payload (Updated for ArduinoJson v7)
    JsonDocument doc;
    doc["uid"] = uid;
    doc["location"] = "College Library"; // You can hardcode this per scanner or configure it
    doc["detail"] = "Entry";
    
    String requestBody;
    serializeJson(doc, requestBody);
    
    Serial.print("Sending Data to server: ");
    Serial.println(requestBody);

    // Send HTTP POST request
    int httpResponseCode = http.POST(requestBody);
    
    if (httpResponseCode > 0) {
      Serial.print("HTTP Response Code: ");
      Serial.println(httpResponseCode);
      String response = http.getString();
      Serial.println("Server Response: " + response);
    } else {
      Serial.print("Error sending POST request. Code: ");
      Serial.println(httpResponseCode);
    }
    
    // Free resources
    http.end();
  } else {
    Serial.println("Error: WiFi not connected.");
  }
}
