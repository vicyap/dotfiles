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

	freeBytes := uint64(stat.Bavail) * uint64(stat.Bsize)

	switch {
	case freeBytes >= 1<<40:
		return fmt.Sprintf("%.0fTi free", float64(freeBytes)/float64(1<<40))
	case freeBytes >= 1<<30:
		return fmt.Sprintf("%.0fGi free", float64(freeBytes)/float64(1<<30))
	case freeBytes >= 1<<20:
		return fmt.Sprintf("%.0fMi free", float64(freeBytes)/float64(1<<20))
	default:
		return fmt.Sprintf("%.0fKi free", float64(freeBytes)/float64(1<<10))
	}
}
