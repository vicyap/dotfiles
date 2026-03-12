package main

import "fmt"

func formatRate(rate int64) string {
	switch {
	case rate >= 1<<30:
		return fmt.Sprintf("%5.1fG", float64(rate)/float64(1<<30))
	case rate >= 1<<20:
		return fmt.Sprintf("%5.1fM", float64(rate)/float64(1<<20))
	case rate >= 1<<10:
		return fmt.Sprintf("%5.1fK", float64(rate)/float64(1<<10))
	default:
		return fmt.Sprintf("%5.1fB", float64(rate))
	}
}
