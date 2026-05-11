package main

import (
	"context"
	"embed"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/gorilla/mux"
)

//go:embed web/index.html
var webUI embed.FS

type Config struct {
	Host           string
	Port           string
	Domain         string
	DNSServers     string
	SAMLPort       string
	DNSMethod      string
	AutoConnect    bool
	ConfigPath     string
	APITCPPort     string
	APIUnixSocket  string
	LogLevel       string
	HostResolv     string
	BackupResolv   string
}

func loadConfig() Config {
	return Config{
		Host:          os.Getenv("OPENFORTIVPN_HOST"),
		Port:          getenv("OPENFORTIVPN_PORT", "443"),
		Domain:        getenv("OPENFORTIVPN_DOMAIN", "avular.dev"),
		DNSServers:    getenv("OPENFORTIVPN_DNS_SERVERS", "10.10.100.50,10.10.100.11"),
		SAMLPort:      getenv("OPENFORTIVPN_SAML_PORT", "8020"),
		DNSMethod:     getenv("OPENFORTIVPN_DNS_METHOD", "auto"),
		AutoConnect:   os.Getenv("OPENFORTIVPN_AUTO_CONNECT") == "true",
		ConfigPath:    getenv("OPENFORTIVPN_CONFIG_PATH", "/etc/openfortivpn/config"),
		APITCPPort:    getenv("OPENFORTIVPN_API_TCP_PORT", "8080"),
		APIUnixSocket: getenv("OPENFORTIVPN_API_UNIX_SOCKET", "/run/openfortivpn/api.sock"),
		LogLevel:      getenv("OPENFORTIVPN_LOG_LEVEL", "info"),
		HostResolv:    getenv("OPENFORTIVPN_HOST_RESOLV", "/host/etc/resolv.conf"),
		BackupResolv:  getenv("OPENFORTIVPN_BACKUP_RESOLV", "/var/lib/openfortivpn/resolv.conf.backup"),
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	cfg := loadConfig()
	
	logger := log.New(os.Stderr, "[control-plane] ", log.LstdFlags)
	
	vpnMgr := NewVPNManager(cfg, logger)
	
	router := mux.NewRouter()
	registerHandlers(router, vpnMgr, logger)
	
	// Serve web UI
	fs := http.FileServer(http.FS(webUI))
	router.PathPrefix("/ui/").Handler(http.StripPrefix("/ui/", fs))
	
	// Start Unix socket listener
	os.MkdirAll(filepath.Dir(cfg.APIUnixSocket), 0755)
	os.Remove(cfg.APIUnixSocket)
	unixListener, err := net.Listen("unix", cfg.APIUnixSocket)
	if err != nil {
		logger.Fatalf("Failed to create Unix socket: %v", err)
	}
	defer unixListener.Close()
	os.Chmod(cfg.APIUnixSocket, 0666)
	
	unixServer := &http.Server{Handler: router}
	go func() {
		logger.Printf("Unix API listening on %s", cfg.APIUnixSocket)
		if err := unixServer.Serve(unixListener); err != nil && err != http.ErrServerClosed {
			logger.Printf("Unix server error: %v", err)
		}
	}()
	
	// Start TCP listener
	tcpListener, err := net.Listen("tcp", "127.0.0.1:"+cfg.APITCPPort)
	if err != nil {
		logger.Fatalf("Failed to create TCP listener: %v", err)
	}
	defer tcpListener.Close()
	
	tcpServer := &http.Server{Handler: router}
	go func() {
		logger.Printf("TCP API listening on %s", tcpListener.Addr())
		if err := tcpServer.Serve(tcpListener); err != nil && err != http.ErrServerClosed {
			logger.Printf("TCP server error: %v", err)
		}
	}()
	
	// Auto-connect if configured
	if cfg.AutoConnect {
		go func() {
			time.Sleep(2 * time.Second)
			logger.Println("Auto-connect enabled, starting VPN...")
			if _, err := vpnMgr.Connect(); err != nil {
				logger.Printf("Auto-connect failed: %v", err)
			}
		}()
	}
	
	// Wait for shutdown signal
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh
	
	logger.Println("Shutdown signal received, cleaning up...")
	
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	
	unixServer.Shutdown(ctx)
	tcpServer.Shutdown(ctx)
	
	if err := vpnMgr.Disconnect(); err != nil {
		logger.Printf("Disconnect error: %v", err)
	}
	
	logger.Println("Shutdown complete")
}
