package main

/*
#include <mach/mach.h>
#include <mach/vm_statistics.h>
#include <sys/sysctl.h>

struct vm_info {
    unsigned long long free_pages;
    unsigned long long inactive_pages;
    unsigned long long speculative_pages;
    unsigned long long purgeable_pages;
    unsigned long long page_size;
    unsigned long long total_bytes;
};

struct vm_info get_vm_info() {
    struct vm_info result = {0};

    vm_statistics64_data_t vmStat;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;

    if (host_statistics64(mach_host_self(), HOST_VM_INFO64,
                          (host_info64_t)&vmStat, &count) == KERN_SUCCESS) {
        result.free_pages = vmStat.free_count;
        result.inactive_pages = vmStat.inactive_count;
        result.speculative_pages = vmStat.speculative_count;
        result.purgeable_pages = vmStat.purgeable_count;
    }

    result.page_size = vm_kernel_page_size;

    int mib[2] = {CTL_HW, HW_MEMSIZE};
    unsigned long long memsize = 0;
    size_t len = sizeof(memsize);
    sysctl(mib, 2, &memsize, &len, NULL, 0);
    result.total_bytes = memsize;

    return result;
}
*/
import "C"

import "fmt"

func collectMemory() string {
	info := C.get_vm_info()

	totalBytes := uint64(info.total_bytes)
	pageSize := uint64(info.page_size)
	availBytes := (uint64(info.free_pages) + uint64(info.inactive_pages) +
		uint64(info.speculative_pages) + uint64(info.purgeable_pages)) * pageSize
	usedBytes := totalBytes - availBytes

	usedGB := float64(usedBytes) / (1 << 30)
	totalGB := float64(totalBytes) / (1 << 30)

	return fmt.Sprintf("%.1f/%.0fG", usedGB, totalGB)
}
