package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

const netWindow = 5 * time.Second

func collectNetwork() string {
	data, err := os.ReadFile("/proc/net/dev")
	if err != nil {
		return ""
	}

	var rxBytes, txBytes int64
	lines := strings.Split(string(data), "\n")
	for _, line := range lines[2:] {
		parts := strings.SplitN(strings.TrimSpace(line), ":", 2)
		if len(parts) != 2 {
			continue
		}
		iface := strings.TrimSpace(parts[0])
		if iface == "lo" || iface == "" {
			continue
		}
		fields := strings.Fields(parts[1])
		if len(fields) < 10 {
			continue
		}
		rb, _ := strconv.ParseInt(fields[0], 10, 64)
		tb, _ := strconv.ParseInt(fields[8], 10, 64)
		rxBytes += rb
		txBytes += tb
	}

	nowMs := time.Now().UnixMilli()
	cache := cachePath("net")
	var rxRate, txRate int64

	prev, err := os.ReadFile(cache)
	if err == nil {
		parts := strings.Fields(string(prev))
		if len(parts) == 3 {
			prevMs, _ := strconv.ParseInt(parts[0], 10, 64)
			prevRx, _ := strconv.ParseInt(parts[1], 10, 64)
			prevTx, _ := strconv.ParseInt(parts[2], 10, 64)
			elapsedMs := nowMs - prevMs
			if elapsedMs > 0 {
				rxRate = (rxBytes - prevRx) * 1000 / elapsedMs
				txRate = (txBytes - prevTx) * 1000 / elapsedMs
			}
			// Only rotate the cache once the window has elapsed so rates
			// are averaged over the full period.
			if elapsedMs >= netWindow.Milliseconds() {
				os.WriteFile(cache, []byte(fmt.Sprintf("%d %d %d", nowMs, rxBytes, txBytes)), 0644)
			}
			return fmt.Sprintf("↑%s ↓%s", formatRate(txRate), formatRate(rxRate))
		}
	}

	// First run or corrupt cache — seed it and show zeros.
	os.WriteFile(cache, []byte(fmt.Sprintf("%d %d %d", nowMs, rxBytes, txBytes)), 0644)
	return fmt.Sprintf("↑%s ↓%s", formatRate(txRate), formatRate(rxRate))
}
