package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

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

	now := time.Now().Unix()
	cache := cachePath("net")
	var rxRate, txRate int64

	prev, err := os.ReadFile(cache)
	if err == nil {
		parts := strings.Fields(string(prev))
		if len(parts) == 3 {
			prevTime, _ := strconv.ParseInt(parts[0], 10, 64)
			prevRx, _ := strconv.ParseInt(parts[1], 10, 64)
			prevTx, _ := strconv.ParseInt(parts[2], 10, 64)
			elapsed := now - prevTime
			if elapsed > 0 {
				rxRate = (rxBytes - prevRx) / elapsed
				txRate = (txBytes - prevTx) / elapsed
			}
		}
	}

	os.WriteFile(cache, []byte(fmt.Sprintf("%d %d %d", now, rxBytes, txBytes)), 0644)
	return fmt.Sprintf("↑%s ↓%s", formatRate(txRate), formatRate(rxRate))
}
