package main

import (
	"fmt"
	"time"
)

func collectClock() string {
	now := time.Now()
	zone, _ := now.Zone()
	localDate := now.Format("Mon Jan 2")
	localTime := now.Format("15:04:05 MST")

	if zone == "UTC" || zone == "GMT" {
		return fmt.Sprintf("%s │ %s", localDate, localTime)
	}

	utcTime := now.UTC().Format("15:04:05")
	return fmt.Sprintf("%s │ %s | %s UTC", localDate, localTime, utcTime)
}
