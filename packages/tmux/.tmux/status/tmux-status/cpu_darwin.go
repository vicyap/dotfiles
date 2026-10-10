package main

/*
#include <mach/mach.h>
#include <mach/host_info.h>

struct cpu_ticks {
    unsigned long long user;
    unsigned long long system;
    unsigned long long idle;
    unsigned long long nice;
};

struct cpu_ticks get_cpu_ticks() {
    struct cpu_ticks result = {0, 0, 0, 0};
    host_cpu_load_info_data_t cpuInfo;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;

    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO,
                        (host_info_t)&cpuInfo, &count) == KERN_SUCCESS) {
        result.user = cpuInfo.cpu_ticks[CPU_STATE_USER];
        result.system = cpuInfo.cpu_ticks[CPU_STATE_SYSTEM];
        result.idle = cpuInfo.cpu_ticks[CPU_STATE_IDLE];
        result.nice = cpuInfo.cpu_ticks[CPU_STATE_NICE];
    }

    return result;
}
*/
import "C"

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

func collectCPU() string {
	ticks := C.get_cpu_ticks()
	user := uint64(ticks.user)
	system := uint64(ticks.system)
	idle := uint64(ticks.idle)
	nice := uint64(ticks.nice)

	total := user + system + idle + nice
	busy := user + system + nice

	cache := cachePath("cpu")
	pct := 0

	data, err := os.ReadFile(cache)
	if err == nil {
		parts := strings.Fields(string(data))
		if len(parts) == 2 {
			prevTotal, _ := strconv.ParseUint(parts[0], 10, 64)
			prevBusy, _ := strconv.ParseUint(parts[1], 10, 64)
			dt := total - prevTotal
			db := busy - prevBusy
			if dt > 0 {
				pct = int(100 * db / dt)
				if pct > 99 {
					pct = 99
				}
			}
		}
	}

	os.WriteFile(cache, []byte(fmt.Sprintf("%d %d", total, busy)), 0644)
	return fmt.Sprintf("%2d%%", pct)
}
