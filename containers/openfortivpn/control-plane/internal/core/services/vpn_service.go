package services

import (
	"context"
	"fmt"
	"log"
	"time"

	"openfortivpn-control-plane/internal/core/domain"
	"openfortivpn-control-plane/internal/core/ports"
	"openfortivpn-control-plane/internal/pkg/errors"
)

// VPNService orchestrates VPN connect/disconnect operations
type VPNService struct {
	config    *domain.Config
	manager   ports.VPNManager
	dns       ports.DNSResolver
	store     ports.ConfigStore
	logger    *log.Logger
}

// NewVPNService creates a new VPN service
func NewVPNService(
	cfg *domain.Config,
	mgr ports.VPNManager,
	dns ports.DNSResolver,
	store ports.ConfigStore,
	logger *log.Logger,
) *VPNService {
	return &VPNService{
		config:  cfg,
		manager: mgr,
		dns:     dns,
		store:   store,
		logger:  logger,
	}
}

// Connect establishes the VPN connection
func (s *VPNService) Connect(ctx context.Context) (*domain.ConnectResult, error) {
	state := s.manager.State()
	if state == domain.StateConnected || state == domain.StateConnecting {
		return nil, errors.New(
			errors.CodeVPNAlreadyRunning,
			fmt.Sprintf("VPN is already %s", state),
		)
	}

	result, err := s.manager.Connect(ctx)
	if err != nil {
		s.logger.Printf("Connect failed: %v", err)
		return nil, err
	}

	return result, nil
}

// Disconnect tears down the VPN connection
func (s *VPNService) Disconnect(ctx context.Context) error {
	if s.manager.State() == domain.StateDisconnected {
		return nil
	}

	// Reset DNS first
	if err := s.dns.Reset(ctx); err != nil {
		s.logger.Printf("DNS reset failed: %v", err)
	}

	if err := s.manager.Disconnect(ctx); err != nil {
		s.logger.Printf("Disconnect failed: %v", err)
		return err
	}

	return nil
}

// Status returns the current VPN status
func (s *VPNService) Status() domain.VPNStatus {
	return s.manager.Status()
}

// WaitForConnection polls until the VPN interface appears or timeout
func (s *VPNService) WaitForConnection(ctx context.Context, timeout time.Duration) error {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return errors.New(
				errors.CodeInterfaceTimeout,
				"VPN interface did not appear within timeout",
			)
		case <-ticker.C:
			status := s.manager.Status()
			if status.State == domain.StateConnected {
				return nil
			}
			if status.State == domain.StateError {
				return errors.New(
					errors.CodeInterfaceTimeout,
					fmt.Sprintf("VPN entered error state: %s", status.LastError),
				)
			}
		}
	}
}
