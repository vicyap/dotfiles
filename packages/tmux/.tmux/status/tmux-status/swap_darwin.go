package main

/*
#include <mach/mach.h>
#include <sys/sysctl.h>

struct xsw_usage get_swap_usage() {
    struct xsw_usage usage = {0};
    size_t len = sizeof(usage);
    sysctlbyname("vm.swapusage", &usage, &len, NULL, 0);
    return usage;
}
*/
import "C"

import "fmt"

func collectSwap() string {
	usage := C.get_swap_usage()

	totalBytes := uint64(usage.xsu_total)
	usedBytes := uint64(usage.xsu_used)

	// No swap configured — hide the module entirely.
	if totalBytes == 0 {
		return ""
	}

	usedGB := float64(usedBytes) / (1 << 30)
	totalGB := float64(totalBytes) / (1 << 30)

	return fmt.Sprintf("%.1f/%.0fG", usedGB, totalGB)
}
