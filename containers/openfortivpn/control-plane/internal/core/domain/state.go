package domain

import "time"

// VPNState represents the current state of the VPN connection
type VPNState string

const (
	StateDisconnected VPNState = "disconnected"
	StateConnecting   VPNState = "connecting"
	StateConnected    VPNState = "connected"
	StateError        VPNState = "error"
)

// VPNStatus holds the current status information
type VPNStatus struct {
	State         VPNState  `json:"state"`
	Interface     string    `json:"interface,omitempty"`
	IP            string    `json:"ip,omitempty"`
	UptimeSeconds int64     `json:"uptime_seconds,omitempty"`
	LastError     string    `json:"last_error,omitempty"`
	SAMLURL       string    `json:"saml_url,omitempty"`
	SAMLPort      int       `json:"saml_port,omitempty"`
}

// ConnectResult is returned by the Connect method
type ConnectResult struct {
	SAMLURL  string `json:"saml_url,omitempty"`
	SAMLPort int    `json:"saml_port,omitempty"`
}

// StateSnapshot captures a point-in-time view of VPN state
type StateSnapshot struct {
	State     VPNState
	Interface string
	IP        string
	StartedAt time.Time
}
