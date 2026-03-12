package main

import (
	"os/exec"
	"strings"
)

func collectGPU() string {
	out, err := exec.Command("nvidia-smi",
		"--query-gpu=utilization.gpu",
		"--format=csv,noheader,nounits").Output()
	if err != nil {
		return ""
	}

	pct := strings.TrimSpace(strings.Split(string(out), "\n")[0])
	if pct == "" {
		return ""
	}
	return pct + "%"
}
