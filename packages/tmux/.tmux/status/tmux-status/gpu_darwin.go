package main

/*
#cgo LDFLAGS: -framework IOKit -framework CoreFoundation
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>

// Returns GPU device utilization percentage (0-100), or -1 on error.
int gpu_utilization() {
    CFMutableDictionaryRef matching = IOServiceMatching("IOAccelerator");
    io_iterator_t iterator;
    if (IOServiceGetMatchingServices(0, matching, &iterator) != KERN_SUCCESS) {
        return -1;
    }

    int result = -1;
    io_registry_entry_t entry;
    while ((entry = IOIteratorNext(iterator)) != 0) {
        CFMutableDictionaryRef properties = NULL;
        if (IORegistryEntryCreateCFProperties(entry, &properties,
                                               kCFAllocatorDefault, 0) != KERN_SUCCESS) {
            IOObjectRelease(entry);
            continue;
        }

        CFDictionaryRef perfStats = CFDictionaryGetValue(properties,
                                                          CFSTR("PerformanceStatistics"));
        if (perfStats && CFGetTypeID(perfStats) == CFDictionaryGetTypeID()) {
            CFNumberRef util = CFDictionaryGetValue(perfStats,
                                                     CFSTR("Device Utilization %"));
            if (util && CFGetTypeID(util) == CFNumberGetTypeID()) {
                int64_t value;
                CFNumberGetValue(util, kCFNumberSInt64Type, &value);
                result = (int)value;
            }
        }

        CFRelease(properties);
        IOObjectRelease(entry);
        if (result >= 0) break;
    }
    IOObjectRelease(iterator);
    return result;
}
*/
import "C"

import "fmt"

func collectGPU() string {
	pct := int(C.gpu_utilization())
	if pct < 0 {
		return ""
	}
	return fmt.Sprintf("%d%%", pct)
}
