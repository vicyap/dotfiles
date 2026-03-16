package main

import "fmt"

func formatRate(rate int64) string {
	const mb = 1_000_000
	const gb = 1_000_000_000
	switch {
	case rate >= gb:
		return " >999M"
	case rate >= mb:
		return fmt.Sprintf("%5.1fM", float64(rate)/float64(mb))
	default:
		return "   <1M"
	}
}
