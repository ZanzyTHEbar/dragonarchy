package main

import (
	"fmt"
	"os"

	"openfortivpn-control-plane/internal/adapters/primary/cli"
)

func main() {
	palette := cli.NewPalette()
	cli.BuildCommands(palette)

	root := palette.BuildRoot()
	if err := root.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
