package main

import (
	"fmt"
	"time"
)

func collectClock() string {
	now := time.Now()
	zone, _ := now.Zone()
	localTime := now.Format("15:04:05 MST")

	if zone == "UTC" || zone == "GMT" {
		return localTime
	}

	utcTime := now.UTC().Format("15:04:05")
	return fmt.Sprintf("%s | %s UTC", localTime, utcTime)
}
