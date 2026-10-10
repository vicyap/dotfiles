package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

func collectBattery() string {
	capData, err := os.ReadFile("/sys/class/power_supply/BAT0/capacity")
	if err != nil {
		return ""
	}

	pct, err := strconv.Atoi(strings.TrimSpace(string(capData)))
	if err != nil {
		return ""
	}

	status := "Unknown"
	if statusData, err := os.ReadFile("/sys/class/power_supply/BAT0/status"); err == nil {
		status = strings.TrimSpace(string(statusData))
	}

	var symbol string
	if status == "Charging" {
		symbol = "+"
	} else if pct <= 10 {
		symbol = "!"
	}

	return fmt.Sprintf("%s%d%%", symbol, pct)
}
