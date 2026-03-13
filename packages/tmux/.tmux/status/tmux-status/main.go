package main

import (
	"fmt"
	"strings"
	"sync"
)

func main() {
	type result struct {
		label string
		value string
	}

	type collector struct {
		idx   int
		label string
		fn    func() string
	}

	collectors := []collector{
		{0, "CPU", collectCPU},
		{1, "GPU", collectGPU},
		{2, "MEM", collectMemory},
		{3, "DSK", collectDisk},
		{4, "NET", collectNetwork},
		{5, "BAT", collectBattery},
		{6, "", collectClock},
	}

	results := make([]result, len(collectors))
	var wg sync.WaitGroup

	for _, c := range collectors {
		wg.Add(1)
		go func(c collector) {
			defer wg.Done()
			results[c.idx] = result{label: c.label, value: c.fn()}
		}(c)
	}

	wg.Wait()

	var parts []string
	for _, r := range results {
		if r.value == "" {
			continue
		}
		if r.label != "" {
			parts = append(parts, r.label+" "+r.value)
		} else {
			parts = append(parts, r.value)
		}
	}

	fmt.Print(strings.Join(parts, " │ "))
}
