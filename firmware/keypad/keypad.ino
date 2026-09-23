#include <Arduino.h>
#include <string.h>

// Implemented by this board core's CDC + HID composite USB driver.
extern "C" int ch32x_hid_send(const uint8_t report[8]);

// Schematic: SW1..4=col1 PA0, SW5..8=col2 PA1, SW9..12=col3 PA2.
// D1/D5/D9 anodes=row1 PA3; row2 PA4; row3 PA5; row4 PA6.
// Drive one column LOW at a time; all other columns are high impedance.
// Diode current flows from pulled-up row (anode) to selected column (cathode).
static const uint8_t cols[3] = {PA0, PA1, PA2};
static const uint8_t rows[4] = {PA3, PA4, PA5, PA6};
// USB HID keyboard usages: 0..9, A, B (top row digits, independent of NumLock).
static const uint8_t keys[4][3] = {
  {0x27, 0x1E, 0x1F}, // 0 1 2
  {0x20, 0x21, 0x22}, // 3 4 5
  {0x23, 0x24, 0x25}, // 6 7 8
  {0x26, 0x04, 0x05}  // 9 A B
};

static uint16_t stable, previous;
static uint8_t count[12];
static uint8_t last_sent[8];
static unsigned long last_scan, last_report;

static uint16_t scan_matrix() {
  uint16_t bits = 0;
  for (uint8_t c = 0; c < 3; ++c) {
    digitalWrite(cols[c], LOW);
    pinMode(cols[c], OUTPUT);
    delayMicroseconds(5);
    for (uint8_t r = 0; r < 4; ++r)
      if (digitalRead(rows[r]) == LOW) bits |= (uint16_t)1 << (r * 3 + c);
    pinMode(cols[c], INPUT); // never drive another column against this one
  }
  return bits;
}

void setup() {
  for (uint8_t r = 0; r < 4; ++r) pinMode(rows[r], INPUT_PULLUP);
  for (uint8_t c = 0; c < 3; ++c) pinMode(cols[c], INPUT);
}

void loop() {
  unsigned long now = millis();
  if ((unsigned long)(now - last_scan) < 1) return;
  last_scan = now;
  uint16_t raw = scan_matrix();
  for (uint8_t i = 0; i < 12; ++i) {
    uint16_t mask = (uint16_t)1 << i;
    if ((raw & mask) == (previous & mask)) {
      if (count[i] < 5) ++count[i];
    } else count[i] = 0;
    if (count[i] == 5) {
      if (raw & mask) stable |= mask;
      else stable &= ~mask;
    }
  }
  previous = raw;

  uint8_t report[8] = {0};
  uint8_t n = 0;
  for (uint8_t i = 0; i < 12; ++i)
    if ((stable & ((uint16_t)1 << i)) && n < 6)
      report[2 + n++] = keys[i / 3][i % 3];
  // Refresh on reconnection / lost transfers, including an all-released report.
  if (memcmp(report, last_sent, 8) || (unsigned long)(now - last_report) >= 250) {
    if (ch32x_hid_send(report)) {
      memcpy(last_sent, report, 8);
      last_report = now;
    }
  }
}
