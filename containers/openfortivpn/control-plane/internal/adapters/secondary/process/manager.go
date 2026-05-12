package process

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

	"openfortivpn-control-plane/internal/core/domain"
	"openfortivpn-control-plane/internal/pkg/errors"
)

// Manager handles the openfortivpn process lifecycle
type Manager struct {
	config    *domain.Config
	cmd       *exec.Cmd
	state     domain.VPNState
	startTime time.Time
	mu        sync.RWMutex
	logger    *log.Logger
}

// NewManager creates a new process manager
func NewManager(cfg *domain.Config, logger *log.Logger) *Manager {
	return &Manager{
		config: cfg,
		state:  domain.StateDisconnected,
		logger: logger,
	}
}

// Connect starts the openfortivpn process
func (m *Manager) Connect(ctx context.Context) (*domain.ConnectResult, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.state == domain.StateConnected || m.state == domain.StateConnecting {
		return nil, errors.New(
			errors.CodeVPNAlreadyRunning,
			fmt.Sprintf("VPN is already %s", m.state),
		)
	}

	m.state = domain.StateConnecting

	tmpConfig := "/tmp/openfortivpn-waybar.conf"
	if err := m.generateWaybarConfig(tmpConfig); err != nil {
		m.state = domain.StateError
		return nil, errors.Wrap(err, errors.CodeInvalidConfig, "failed to generate waybar config")
	}

	args := []string{
		"--config", tmpConfig,
		fmt.Sprintf("--saml-login=%d", m.config.SAMLPort),
	}

	m.logger.Printf("Starting openfortivpn with args: %v", args)
	m.cmd = exec.CommandContext(ctx, "openfortivpn", args...)
	m.cmd.Stdout = os.Stdout
	m.cmd.Stderr = os.Stderr

	if err := m.cmd.Start(); err != nil {
		m.state = domain.StateError
		return nil, errors.Wrap(err, errors.CodeProcessFailed, "failed to start openfortivpn")
	}

	// Wait for SAML port
	if err := m.waitForPort(m.config.SAMLPort, 10*time.Second); err != nil {
		m.Disconnect(ctx)
		m.state = domain.StateError
		return nil, errors.Wrap(err, errors.CodeSAMLTimeout, "SAML listener did not start in time")
	}

	host := m.config.Host
	port := m.config.Port
	if host == "" {
		// Read from config file
		content, _ := os.ReadFile(m.config.ConfigPath)
		host = extractHost(string(content))
	}

	samlURL := fmt.Sprintf("https://%s:%s/remote/saml/start?redirect=1", host, port)

	result := &domain.ConnectResult{
		SAMLURL:  samlURL,
		SAMLPort: m.config.SAMLPort,
	}

	// Start goroutine to monitor interface
	go m.waitForInterface()

	return result, nil
}

// Disconnect stops the openfortivpn process
func (m *Manager) Disconnect(ctx context.Context) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.state == domain.StateDisconnected {
		return nil
	}

	m.logger.Println("Disconnecting VPN...")

	if m.cmd != nil && m.cmd.Process != nil {
		m.logger.Println("Sending SIGINT to openfortivpn...")
		m.cmd.Process.Signal(os.Interrupt)

		done := make(chan error, 1)
		go func() {
			done <- m.cmd.Wait()
		}()

		select {
		case <-done:
			m.logger.Println("openfortivpn exited gracefully")
		case <-time.After(10 * time.Second):
			m.logger.Println("openfortivpn did not exit, sending SIGKILL...")
			m.cmd.Process.Kill()
			m.cmd.Wait()
		}
	}

	m.killPPPD()
	m.bringInterfaceDown()

	m.state = domain.StateDisconnected
	m.startTime = time.Time{}
	m.cmd = nil

	return nil
}

// Status returns current VPN status
func (m *Manager) Status() domain.VPNStatus {
	m.mu.RLock()
	defer m.mu.RUnlock()

	iface := m.detectInterface()
	status := domain.VPNStatus{
		State:     m.state,
		Interface: iface,
	}

	if iface != "" && m.state == domain.StateConnected {
		status.IP = m.getInterfaceIP(iface)
		if !m.startTime.IsZero() {
			status.UptimeSeconds = int64(time.Since(m.startTime).Seconds())
		}
	}

	return status
}

// State returns current state
func (m *Manager) State() domain.VPNState {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.state
}

// IsPortListening checks if a port is listening
func (m *Manager) IsPortListening(port int) bool {
	out, err := exec.Command("ss", "-ltn", "sport", fmt.Sprintf(":%d", port)).Output()
	if err != nil {
		return false
	}
	return strings.Contains(string(out), "LISTEN")
}

func (m *Manager) waitForPort(port int, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if m.IsPortListening(port) {
			return nil
		}
		time.Sleep(500 * time.Millisecond)
	}
	return fmt.Errorf("port %d not listening after %v", port, timeout)
}

func (m *Manager) waitForInterface() {
	deadline := time.Now().Add(30 * time.Second)
	for time.Now().Before(deadline) {
		iface := m.detectInterface()
		if iface != "" {
			m.mu.Lock()
			m.state = domain.StateConnected
			m.startTime = time.Now()
			m.mu.Unlock()
			m.logger.Printf("VPN interface detected: %s", iface)
			return
		}

		if m.cmd != nil && m.cmd.Process != nil {
			if err := m.cmd.Process.Signal(os.Signal(nil)); err != nil {
				m.mu.Lock()
				m.state = domain.StateError
				m.mu.Unlock()
				m.logger.Println("openfortivpn process exited unexpectedly")
				return
			}
		}

		time.Sleep(1 * time.Second)
	}

	m.mu.Lock()
	m.state = domain.StateError
	m.mu.Unlock()
	m.logger.Println("VPN interface did not appear in time")
}

func (m *Manager) detectInterface() string {
	for _, iface := range []string{"ppp0", "ppp1", "ppp2"} {
		if m.interfaceExists(iface) {
			return iface
		}
	}

	out, err := exec.Command("ip", "-brief", "link", "show").Output()
	if err == nil {
		lines := strings.Split(string(out), "\n")
		for _, line := range lines {
			fields := strings.Fields(line)
			if len(fields) > 0 && strings.HasPrefix(fields[0], "ppp") {
				return fields[0]
			}
		}
	}
	return ""
}

func (m *Manager) interfaceExists(iface string) bool {
	_, err := exec.Command("ip", "link", "show", iface).Output()
	return err == nil
}

func (m *Manager) getInterfaceIP(iface string) string {
	out, err := exec.Command("ip", "-brief", "addr", "show", iface).Output()
	if err != nil {
		return ""
	}
	fields := strings.Fields(string(out))
	if len(fields) >= 3 {
		return strings.Split(fields[2], "/")[0]
	}
	return ""
}

func (m *Manager) generateWaybarConfig(dst string) error {
	content, err := os.ReadFile(m.config.ConfigPath)
	if err != nil {
		return err
	}

	lines := strings.Split(string(content), "\n")
	var filtered []string
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(strings.ToLower(trimmed), "saml-login") {
			continue
		}
		filtered = append(filtered, line)
	}

	return os.WriteFile(dst, []byte(strings.Join(filtered, "\n")+"\n"), 0640)
}

func (m *Manager) killPPPD() {
	exec.Command("pkill", "-TERM", "pppd").Run()
	time.Sleep(500 * time.Millisecond)
	exec.Command("pkill", "-KILL", "pppd").Run()
}

func (m *Manager) bringInterfaceDown() {
	iface := m.detectInterface()
	if iface != "" {
		exec.Command("ip", "link", "set", iface, "down").Run()
	}
}

func extractHost(content string) string {
	lines := strings.Split(content, "\n")
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "#") {
			continue
		}
		if strings.Contains(line, "host") {
			parts := strings.SplitN(line, "=", 2)
			if len(parts) == 2 {
				return strings.TrimSpace(parts[1])
			}
		}
	}
	return ""
}
