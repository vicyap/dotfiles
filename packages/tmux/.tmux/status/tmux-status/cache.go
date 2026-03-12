package main

import (
	"fmt"
	"os"
	"os/user"
	"path/filepath"
)

func cachePath(name string) string {
	u, err := user.Current()
	if err != nil {
		return filepath.Join(os.TempDir(), fmt.Sprintf("tmux-%s-unknown", name))
	}
	return filepath.Join(os.TempDir(), fmt.Sprintf("tmux-%s-%s", name, u.Username))
}
