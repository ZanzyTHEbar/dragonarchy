package ports

import (
	"context"

	"openfortivpn-control-plane/internal/core/domain"
)

// VPNManager defines the interface for VPN lifecycle management
type VPNManager interface {
	Connect(ctx context.Context) (*domain.ConnectResult, error)
	Disconnect(ctx context.Context) error
	Status() domain.VPNStatus
	State() domain.VPNState
	IsPortListening(port int) bool
}

// DNSResolver defines the interface for split DNS operations
type DNSResolver interface {
	Apply(ctx context.Context) error
	Reset(ctx context.Context) error
}

// ConfigStore defines the interface for configuration persistence
type ConfigStore interface {
	Read() ([]byte, error)
	Write(data []byte) error
	Path() string
}
