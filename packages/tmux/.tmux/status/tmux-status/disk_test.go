package main

import "testing"

func TestFormatBytes(t *testing.T) {
	cases := map[uint64]string{
		1031 << 30: "1T",
		999e9:      "999G",
		999.6e9:    "1T",
		1e12:       "1T",
		2.4e12:     "2T",
		512e6:      "512M",
		600:        "1K",
		1500e3:     "2M",
	}
	for n, want := range cases {
		if got := formatBytes(n); got != want {
			t.Errorf("formatBytes(%d) = %q, want %q", n, got, want)
		}
	}
}
