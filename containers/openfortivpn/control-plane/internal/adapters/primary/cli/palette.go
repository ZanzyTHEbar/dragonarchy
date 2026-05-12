package cli

import (
	"github.com/spf13/cobra"
)

// Palette is a registry of CLI commands
type Palette struct {
	commands map[string]*cobra.Command
}

// NewPalette creates a new command palette
func NewPalette() *Palette {
	return &Palette{
		commands: make(map[string]*cobra.Command),
	}
}

// Register adds a command to the palette
func (p *Palette) Register(name string, cmd *cobra.Command) {
	p.commands[name] = cmd
}

// BuildRoot constructs the root command from registered commands
func (p *Palette) BuildRoot() *cobra.Command {
	root := &cobra.Command{
		Use:   "vpnctl",
		Short: "CLI client for openfortivpn-container",
		Long:  `Control the OpenFortiVPN container from the command line.`,
	}

	for _, cmd := range p.commands {
		root.AddCommand(cmd)
	}

	return root
}

// Get retrieves a registered command by name
func (p *Palette) Get(name string) *cobra.Command {
	return p.commands[name]
}
