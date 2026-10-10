package main

import "time"

func collectDate() string {
	return time.Now().Format("Mon Jan 2")
}
