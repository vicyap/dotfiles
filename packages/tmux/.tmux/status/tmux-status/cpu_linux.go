package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

func collectCPU() string {
	data, err := os.ReadFile("/proc/stat")
	if err != nil {
		return ""
	}

	line := strings.SplitN(string(data), "\n", 2)[0]
	fields := strings.Fields(line)
	if len(fields) < 9 || fields[0] != "cpu" {
		return ""
	}

	vals := make([]uint64, 8)
	for i := 0; i < 8; i++ {
		vals[i], _ = strconv.ParseUint(fields[i+1], 10, 64)
	}

	// user, nice, system, idle, iowait, irq, softirq, steal
	var total uint64
	for _, v := range vals {
		total += v
	}
	idle := vals[3] + vals[4]
	busy := total - idle

	cache := cachePath("cpu")
	pct := 0

	prev, err := os.ReadFile(cache)
	if err == nil {
		parts := strings.Fields(string(prev))
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
