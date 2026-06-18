#include "CIOHID.h"
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>

// --- Prototypes IOHID privés (IOKit/IOHIDFamily) ---------------------------
// Non exposés dans les headers publics, mais exportés par IOKit.framework.
// Convention de nommage "Copy/Create" → +1 sur le compteur de références.
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef matching);
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
extern CFStringRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef property);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t timestamp);
extern double IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

// Constantes IOHID (capteurs de température "AppleVendor").
#define kIOHIDEventTypeTemperature 15
#define IOHIDEventFieldBase(type) ((type) << 16)
#define kHIDPage_AppleVendor 0xff00
#define kHIDUsage_AppleVendor_TemperatureSensor 0x0005

static CFDictionaryRef make_matching(int page, int usage) {
    CFNumberRef pageNum  = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &page);
    CFNumberRef usageNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &usage);
    const void *keys[] = { CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage") };
    const void *vals[] = { pageNum, usageNum };
    CFDictionaryRef dict = CFDictionaryCreate(kCFAllocatorDefault, keys, vals, 2,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    if (pageNum)  CFRelease(pageNum);
    if (usageNum) CFRelease(usageNum);
    return dict;
}

// Parcourt les capteurs de température. Pour chacun : si `print`, l'affiche sur
// stderr ; sinon, s'il matche `token` (sous-chaîne, insensible à la casse, ou
// token NULL/vide = tous) et que la valeur est plausible, l'accumule.
// Retourne la moyenne, ou -1.0 si aucun capteur compté (mode non-print).
static double scan_temperatures(const char *token, int print) {
    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!client) return -1.0;

    CFDictionaryRef matching = make_matching(kHIDPage_AppleVendor,
                                             kHIDUsage_AppleVendor_TemperatureSensor);
    IOHIDEventSystemClientSetMatching(client, matching);
    CFArrayRef services = IOHIDEventSystemClientCopyServices(client);

    double sum = 0.0;
    int    n   = 0;

    if (services) {
        CFIndex count = CFArrayGetCount(services);
        for (CFIndex i = 0; i < count; i++) {
            IOHIDServiceClientRef svc = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
            if (!svc) continue;

            IOHIDEventRef event = IOHIDServiceClientCopyEvent(svc, kIOHIDEventTypeTemperature, 0, 0);
            if (!event) continue;
            double value = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));

            char name[160] = {0};
            CFStringRef prod = IOHIDServiceClientCopyProperty(svc, CFSTR("Product"));
            if (prod) {
                CFStringGetCString(prod, name, sizeof(name), kCFStringEncodingUTF8);
                CFRelease(prod);
            }

            if (print) {
                fprintf(stderr, "  %-40s = %6.2f °C\n", name[0] ? name : "(?)", value);
            } else {
                int match = 1;
                if (token && token[0]) match = (strcasestr(name, token) != NULL);
                if (match && value > 0.0 && value < 200.0) { sum += value; n++; }
            }
            CFRelease((CFTypeRef)event);
        }
        CFRelease(services);
    }

    CFRelease(matching);
    CFRelease((CFTypeRef)client);
    return n > 0 ? sum / n : -1.0;
}

double cihid_temperature_avg(const char *token) {
    return scan_temperatures(token, 0);
}

void cihid_dump_temperatures(void) {
    fprintf(stderr, "== Capteurs de température IOHID ==\n");
    (void)scan_temperatures(NULL, 1);
}
