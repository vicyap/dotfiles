package main

import (
	"fmt"
	"syscall"
)

func collectDisk() string {
	var stat syscall.Statfs_t
	if err := syscall.Statfs("/", &stat); err != nil {
		return ""
	}

	return formatBytes(uint64(stat.Bavail) * uint64(stat.Bsize))
}

// formatBytes renders n in SI units with at most three digits.
func formatBytes(n uint64) string {
	v := float64(n) / 1000
	units := "KMGTP"
	i := 0
	for v >= 999.5 && i < len(units)-1 {
		v /= 1000
		i++
	}
	return fmt.Sprintf("%.0f%c", v, units[i])
}
