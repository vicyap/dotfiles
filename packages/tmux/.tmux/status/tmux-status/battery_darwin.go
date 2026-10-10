package main

import (
	"fmt"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
)

var battPctRe = regexp.MustCompile(`(\d+)%`)

func collectBattery() string {
	out, err := exec.Command("pmset", "-g", "batt").Output()
	if err != nil {
		return ""
	}

	output := string(out)
	match := battPctRe.FindStringSubmatch(output)
	if match == nil {
		return ""
	}

	pct, _ := strconv.Atoi(match[1])

	var symbol string
	if strings.Contains(output, "AC Power") {
		symbol = "+"
	} else if pct <= 10 {
		symbol = "!"
	}

	return fmt.Sprintf("%s%d%%", symbol, pct)
}
