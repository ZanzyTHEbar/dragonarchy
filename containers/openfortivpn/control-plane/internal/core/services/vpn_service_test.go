package services

import (
	"context"
	"log"
	"os"
	"testing"
	"time"

	"openfortivpn-control-plane/internal/core/domain"
	"openfortivpn-control-plane/internal/pkg/errors"
)

// mockVPNManager implements ports.VPNManager for testing
type mockVPNManager struct {
	state         domain.VPNState
	connectCalled bool
	disconnectCalled bool
	status        domain.VPNStatus
}

func (m *mockVPNManager) Connect(ctx context.Context) (*domain.ConnectResult, error) {
	m.connectCalled = true
	if m.state == domain.StateConnected || m.state == domain.StateConnecting {
		return nil, errors.New(errors.CodeVPNAlreadyRunning, "already running")
	}
	m.state = domain.StateConnecting
	return &domain.ConnectResult{SAMLURL: "https://test.example.com/saml", SAMLPort: 8020}, nil
}

func (m *mockVPNManager) Disconnect(ctx context.Context) error {
	m.disconnectCalled = true
	m.state = domain.StateDisconnected
	return nil
}

func (m *mockVPNManager) Status() domain.VPNStatus {
	return m.status
}

func (m *mockVPNManager) State() domain.VPNState {
	return m.state
}

func (m *mockVPNManager) IsPortListening(port int) bool {
	return true
}

// mockDNSResolver implements ports.DNSResolver for testing
type mockDNSResolver struct {
	applyCalled bool
	resetCalled bool
}

func (m *mockDNSResolver) Apply(ctx context.Context) error {
	m.applyCalled = true
	return nil
}

func (m *mockDNSResolver) Reset(ctx context.Context) error {
	m.resetCalled = true
	return nil
}

// mockConfigStore implements ports.ConfigStore for testing
type mockConfigStore struct {
	data []byte
}

func (m *mockConfigStore) Read() ([]byte, error) {
	return m.data, nil
}

func (m *mockConfigStore) Write(data []byte) error {
	m.data = data
	return nil
}

func (m *mockConfigStore) Path() string {
	return "/tmp/test-config"
}

func TestVPNService_Connect(t *testing.T) {
	logger := log.New(os.Stderr, "[test] ", log.LstdFlags)
	cfg := &domain.Config{Host: "test.example.com", Port: "443"}
	mgr := &mockVPNManager{state: domain.StateDisconnected}
	dns := &mockDNSResolver{}
	store := &mockConfigStore{data: []byte("host = test.example.com\n")}

	svc := NewVPNService(cfg, mgr, dns, store, logger)

	result, err := svc.Connect(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result.SAMLURL == "" {
		t.Error("expected SAML URL")
	}
	if !mgr.connectCalled {
		t.Error("expected Connect to be called on manager")
	}
}

func TestVPNService_Connect_AlreadyRunning(t *testing.T) {
	logger := log.New(os.Stderr, "[test] ", log.LstdFlags)
	cfg := &domain.Config{Host: "test.example.com", Port: "443"}
	mgr := &mockVPNManager{state: domain.StateConnected}
	dns := &mockDNSResolver{}
	store := &mockConfigStore{}

	svc := NewVPNService(cfg, mgr, dns, store, logger)

	_, err := svc.Connect(context.Background())
	if err == nil {
		t.Fatal("expected error for already running VPN")
	}
	if !errors.IsCode(err, errors.CodeVPNAlreadyRunning) {
		t.Errorf("expected CodeVPNAlreadyRunning, got: %v", errors.CodeOf(err))
	}
}

func TestVPNService_Disconnect(t *testing.T) {
	logger := log.New(os.Stderr, "[test] ", log.LstdFlags)
	cfg := &domain.Config{Host: "test.example.com", Port: "443"}
	mgr := &mockVPNManager{state: domain.StateConnected}
	dns := &mockDNSResolver{}
	store := &mockConfigStore{}

	svc := NewVPNService(cfg, mgr, dns, store, logger)

	err := svc.Disconnect(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !dns.resetCalled {
		t.Error("expected DNS reset to be called")
	}
	if !mgr.disconnectCalled {
		t.Error("expected Disconnect to be called on manager")
	}
}

func TestCommandExecutor(t *testing.T) {
	logger := log.New(os.Stderr, "[test] ", log.LstdFlags)
	cfg := &domain.Config{Host: "test.example.com", Port: "443"}
	mgr := &mockVPNManager{state: domain.StateDisconnected}
	dns := &mockDNSResolver{}
	store := &mockConfigStore{}
	svc := NewVPNService(cfg, mgr, dns, store, logger)

	exec := NewCommandExecutor()

	var preCalled, postCalled bool
	exec.RegisterPreHook(func(ctx context.Context, cmd Command) error {
		preCalled = true
		return nil
	})
	exec.RegisterPostHook(func(ctx context.Context, cmd Command, err error) {
		postCalled = true
	})

	cmd := &ConnectCommand{Service: svc}
	_ = exec.Execute(context.Background(), cmd)

	if !preCalled {
		t.Error("expected pre-hook to be called")
	}
	if !postCalled {
		t.Error("expected post-hook to be called")
	}
}

func TestVPNService_WaitForConnection(t *testing.T) {
	logger := log.New(os.Stderr, "[test] ", log.LstdFlags)
	cfg := &domain.Config{Host: "test.example.com", Port: "443"}
	mgr := &mockVPNManager{state: domain.StateDisconnected, status: domain.VPNStatus{State: domain.StateDisconnected}}
	dns := &mockDNSResolver{}
	store := &mockConfigStore{}

	svc := NewVPNService(cfg, mgr, dns, store, logger)

	// Should timeout quickly
	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	err := svc.WaitForConnection(ctx, 50*time.Millisecond)
	if err == nil {
		t.Fatal("expected timeout error")
	}
	if !errors.IsCode(err, errors.CodeInterfaceTimeout) {
		t.Errorf("expected CodeInterfaceTimeout, got: %v", errors.CodeOf(err))
	}
}
