package services

import (
	"context"
)

// Command is the interface for all operations
type Command interface {
	Execute(ctx context.Context) error
}

// ConnectCommand encapsulates the connect operation
type ConnectCommand struct {
	Service *VPNService
	Result  *ConnectResult
}

// ConnectResult holds the output of a connect command
type ConnectResult struct {
	SAMLURL  string
	SAMLPort int
}

func (c *ConnectCommand) Execute(ctx context.Context) error {
	res, err := c.Service.Connect(ctx)
	if err != nil {
		return err
	}
	if c.Result != nil {
		*c.Result = ConnectResult{
			SAMLURL:  res.SAMLURL,
			SAMLPort: res.SAMLPort,
		}
	}
	return nil
}

// DisconnectCommand encapsulates the disconnect operation
type DisconnectCommand struct {
	Service *VPNService
}

func (c *DisconnectCommand) Execute(ctx context.Context) error {
	return c.Service.Disconnect(ctx)
}

// StatusCommand encapsulates the status query
type StatusCommand struct {
	Service *VPNService
	Result  *StatusResult
}

// StatusResult holds the output of a status command
type StatusResult struct {
	State     string
	Interface string
	IP        string
	Uptime    int64
	Error     string
}

func (c *StatusCommand) Execute(ctx context.Context) error {
	status := c.Service.Status()
	if c.Result != nil {
		*c.Result = StatusResult{
			State:     string(status.State),
			Interface: status.Interface,
			IP:        status.IP,
			Uptime:    status.UptimeSeconds,
			Error:     status.LastError,
		}
	}
	return nil
}

// CommandExecutor executes commands with common pre/post hooks
type CommandExecutor struct {
	preHooks  []func(ctx context.Context, cmd Command) error
	postHooks []func(ctx context.Context, cmd Command, err error)
}

// NewCommandExecutor creates a new executor
func NewCommandExecutor() *CommandExecutor {
	return &CommandExecutor{}
}

// Execute runs a command through the hook chain
func (e *CommandExecutor) Execute(ctx context.Context, cmd Command) error {
	for _, hook := range e.preHooks {
		if err := hook(ctx, cmd); err != nil {
			return err
		}
	}

	err := cmd.Execute(ctx)

	for _, hook := range e.postHooks {
		hook(ctx, cmd, err)
	}

	return err
}

// RegisterPreHook adds a pre-execution hook
func (e *CommandExecutor) RegisterPreHook(hook func(ctx context.Context, cmd Command) error) {
	e.preHooks = append(e.preHooks, hook)
}

// RegisterPostHook adds a post-execution hook
func (e *CommandExecutor) RegisterPostHook(hook func(ctx context.Context, cmd Command, err error)) {
	e.postHooks = append(e.postHooks, hook)
}
