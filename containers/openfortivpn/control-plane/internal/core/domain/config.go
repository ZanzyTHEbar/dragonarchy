package domain

import (
	"fmt"
	"os"
	"strconv"
)

// Config holds the application configuration
type Config struct {
	Host          string
	Port          string
	Domain        string
	DNSServers    []string
	SAMLPort      int
	DNSMethod     string
	AutoConnect   bool
	ConfigPath    string
	APITCPPort    int
	APIUnixSocket string
	LogLevel      string
	HostResolv    string
	BackupResolv  string
}

// LoadConfig reads configuration from environment variables
func LoadConfig() (*Config, error) {
	samlPort, err := strconv.Atoi(getenv("OPENFORTIVPN_SAML_PORT", "8020"))
	if err != nil {
		return nil, fmt.Errorf("invalid SAML_PORT: %w", err)
	}

	apiPort, err := strconv.Atoi(getenv("OPENFORTIVPN_API_TCP_PORT", "8080"))
	if err != nil {
		return nil, fmt.Errorf("invalid API_TCP_PORT: %w", err)
	}

	servers := splitServers(getenv("OPENFORTIVPN_DNS_SERVERS", "10.10.100.50,10.10.100.11"))

	return &Config{
		Host:          os.Getenv("OPENFORTIVPN_HOST"),
		Port:          getenv("OPENFORTIVPN_PORT", "443"),
		Domain:        getenv("OPENFORTIVPN_DOMAIN", "avular.dev"),
		DNSServers:    servers,
		SAMLPort:      samlPort,
		DNSMethod:     getenv("OPENFORTIVPN_DNS_METHOD", "auto"),
		AutoConnect:   os.Getenv("OPENFORTIVPN_AUTO_CONNECT") == "true",
		ConfigPath:    getenv("OPENFORTIVPN_CONFIG_PATH", "/etc/openfortivpn/config"),
		APITCPPort:    apiPort,
		APIUnixSocket: getenv("OPENFORTIVPN_API_UNIX_SOCKET", "/run/openfortivpn/api.sock"),
		LogLevel:      getenv("OPENFORTIVPN_LOG_LEVEL", "info"),
		HostResolv:    getenv("OPENFORTIVPN_HOST_RESOLV", "/host/etc/resolv.conf"),
		BackupResolv:  getenv("OPENFORTIVPN_BACKUP_RESOLV", "/var/lib/openfortivpn/resolv.conf.backup"),
	}, nil
}

// Validate ensures the configuration is usable
func (c *Config) Validate() error {
	if c.Host == "" {
		if _, err := os.Stat(c.ConfigPath); os.IsNotExist(err) {
			return fmt.Errorf("VPN_HOST not set and config file not found at %s", c.ConfigPath)
		}
	}
	return nil
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func splitServers(csv string) []string {
	var result []string
	start := 0
	for i := 0; i < len(csv); i++ {
		if csv[i] == ',' {
			if s := csv[start:i]; s != "" {
				result = append(result, s)
			}
			start = i + 1
		}
	}
	if s := csv[start:]; s != "" {
		result = append(result, s)
	}
	return result
}
