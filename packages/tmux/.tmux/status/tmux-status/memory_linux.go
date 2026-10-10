package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

func collectMemory() string {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return ""
	}

	var totalKB, availKB uint64
	for _, line := range strings.Split(string(data), "\n") {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		key := strings.TrimSuffix(fields[0], ":")
		val, _ := strconv.ParseUint(fields[1], 10, 64)
		switch key {
		case "MemTotal":
			totalKB = val
		case "MemAvailable":
			availKB = val
		}
	}

	usedGB := float64(totalKB-availKB) / 1048576
	totalGB := float64(totalKB) / 1048576

	return fmt.Sprintf("%.1f/%.0fG", usedGB, totalGB)
}
