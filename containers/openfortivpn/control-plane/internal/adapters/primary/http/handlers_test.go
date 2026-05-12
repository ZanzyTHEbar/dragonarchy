package http

import (
	"bytes"
	"context"
	"encoding/json"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"openfortivpn-control-plane/internal/core/domain"
	"openfortivpn-control-plane/internal/core/services"
	"openfortivpn-control-plane/internal/pkg/errors"
)

// mockStore implements ports.ConfigStore for testing
type mockStore struct {
	data []byte
}

func (m *mockStore) Read() ([]byte, error) { return m.data, nil }
func (m *mockStore) Write(data []byte) error {
	m.data = data
	return nil
}
func (m *mockStore) Path() string { return "/tmp/test-config" }

// mockManager for HTTP handler tests
type mockManager struct {
	state domain.VPNState
}

func (m *mockManager) Connect(ctx context.Context) (*domain.ConnectResult, error) {
	if m.state == domain.StateConnected {
		return nil, errors.New(errors.CodeVPNAlreadyRunning, "already running")
	}
	m.state = domain.StateConnecting
	return &domain.ConnectResult{SAMLURL: "https://test.example.com/saml", SAMLPort: 8020}, nil
}

func (m *mockManager) Disconnect(ctx context.Context) error {
	m.state = domain.StateDisconnected
	return nil
}

func (m *mockManager) Status() domain.VPNStatus {
	return domain.VPNStatus{State: m.state}
}

func (m *mockManager) State() domain.VPNState { return m.state }
func (m *mockManager) IsPortListening(port int) bool { return true }

// mockDNS for HTTP handler tests
type mockDNS struct{}

func (m *mockDNS) Apply(ctx context.Context) error  { return nil }
func (m *mockDNS) Reset(ctx context.Context) error  { return nil }

func setupTestHandler() (*Handler, *services.VPNService, *services.CommandExecutor) {
	logger := log.New(os.Stderr, "[test] ", log.LstdFlags)
	cfg := &domain.Config{Host: "test.example.com", Port: "443"}
	mgr := &mockManager{state: domain.StateDisconnected}
	dns := &mockDNS{}
	store := &mockStore{data: []byte("host = test.example.com\n")}

	svc := services.NewVPNService(cfg, mgr, dns, store, logger)
	exec := services.NewCommandExecutor()
	handler := NewHandler(svc, exec, store, logger)
	return handler, svc, exec
}

func TestHandleHealth(t *testing.T) {
	handler, _, _ := setupTestHandler()
	mux := http.NewServeMux()
	handler.RegisterRoutes(mux)

	req := httptest.NewRequest("GET", "/health", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rec.Code)
	}

	var body map[string]string
	json.Unmarshal(rec.Body.Bytes(), &body)
	if body["status"] != "healthy" {
		t.Errorf("expected healthy, got %s", body["status"])
	}
}

func TestHandleStatus(t *testing.T) {
	handler, _, _ := setupTestHandler()
	mux := http.NewServeMux()
	handler.RegisterRoutes(mux)

	req := httptest.NewRequest("GET", "/status", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rec.Code)
	}

	var body domain.VPNStatus
	json.Unmarshal(rec.Body.Bytes(), &body)
	if body.State != domain.StateDisconnected {
		t.Errorf("expected disconnected, got %s", body.State)
	}
}

func TestHandleConnect(t *testing.T) {
	handler, _, _ := setupTestHandler()
	mux := http.NewServeMux()
	handler.RegisterRoutes(mux)

	req := httptest.NewRequest("POST", "/connect", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}

	var body domain.ConnectResult
	json.Unmarshal(rec.Body.Bytes(), &body)
	if body.SAMLURL == "" {
		t.Error("expected SAML URL")
	}
}

func TestHandleDisconnect(t *testing.T) {
	handler, _, _ := setupTestHandler()
	mux := http.NewServeMux()
	handler.RegisterRoutes(mux)

	req := httptest.NewRequest("POST", "/disconnect", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}
}

func TestHandleGetConfig(t *testing.T) {
	handler, _, _ := setupTestHandler()
	mux := http.NewServeMux()
	handler.RegisterRoutes(mux)

	req := httptest.NewRequest("GET", "/config", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rec.Code)
	}
	if !bytes.Contains(rec.Body.Bytes(), []byte("test.example.com")) {
		t.Errorf("expected config to contain test.example.com, got: %s", rec.Body.String())
	}
}

func TestHandlePostConfig(t *testing.T) {
	handler, _, _ := setupTestHandler()
	mux := http.NewServeMux()
	handler.RegisterRoutes(mux)

	payload := map[string]string{"config": "host = new.example.com\n"}
	data, _ := json.Marshal(payload)
	req := httptest.NewRequest("POST", "/config", bytes.NewReader(data))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d: %s", rec.Code, rec.Body.String())
	}
}
