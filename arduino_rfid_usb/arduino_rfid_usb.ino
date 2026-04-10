#include <MFRC522v2.h>
#include <MFRC522DriverSPI.h>
#include <MFRC522DriverPinSimple.h>
#include <MFRC522Debug.h>

// RFID SS Pin is 5
MFRC522DriverPinSimple ss_pin(5);
MFRC522DriverSPI driver{ss_pin}; 
MFRC522 mfrc522{driver};        

void setup() {
  Serial.begin(115200); 
  while (!Serial); // Wait for Serial port to open

  mfrc522.PCD_Init();   
  Serial.println(F("TrackAccess RFID Scanner Ready"));
}

void loop() {
  // Check for new card
  if (!mfrc522.PICC_IsNewCardPresent()) {
    return;
  }

  // Read card serial
  if (!mfrc522.PICC_ReadCardSerial()) {
    return;
  }

  // Send UID to Flutter app: "XX XX XX XX"
  for (byte i = 0; i < mfrc522.uid.size; i++) {
    if (i > 0) Serial.print(" ");
    if (mfrc522.uid.uidByte[i] < 0x10) Serial.print("0");
    Serial.print(mfrc522.uid.uidByte[i], HEX);
  }
  Serial.println(); // Newline tells the app the scan is complete

  // Halt PICC and stop encryption
  mfrc522.PICC_HaltA();
  mfrc522.PCD_StopCrypto1();

  delay(1500); // Prevent multiple scans of the same card
}
