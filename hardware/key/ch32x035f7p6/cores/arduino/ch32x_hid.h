/* USB boot keyboard endpoint supplied by this board's CDC/HID composite core. */
#ifndef CH32X_HID_H
#define CH32X_HID_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Returns 1 when queued; 0 if not configured or previous report still pending. */
int ch32x_hid_send(const uint8_t report[8]);
#ifdef __cplusplus
}
#endif
#endif
