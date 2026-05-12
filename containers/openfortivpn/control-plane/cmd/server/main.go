package main

//go:generate bash ../../scripts/build-webui.sh

import (
	"context"
	"embed"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	httpadapter "openfortivpn-control-plane/internal/adapters/primary/http"
	"openfortivpn-control-plane/internal/adapters/secondary/config"
	"openfortivpn-control-plane/internal/adapters/secondary/dns"
	"openfortivpn-control-plane/internal/adapters/secondary/process"
	"openfortivpn-control-plane/internal/core/domain"
	"openfortivpn-control-plane/internal/core/services"
)

//go:embed webui/dist
var webUI embed.FS

func main() {
	logger := log.New(os.Stderr, "[server] ", log.LstdFlags)

	cfg, err := domain.LoadConfig()
	if err != nil {
		logger.Fatalf("Failed to load config: %v", err)
	}

	if err := cfg.Validate(); err != nil {
		logger.Fatalf("Config validation failed: %v", err)
	}

	// Wire dependencies (hexagonal architecture)
	manager := process.NewManager(cfg, logger)
	resolver := dns.NewHelperResolver(cfg)
	store := config.NewFileStore(cfg.ConfigPath)
	vpnService := services.NewVPNService(cfg, manager, resolver, store, logger)
	executor := services.NewCommandExecutor()

	// Register post-execution hooks
	executor.RegisterPostHook(func(ctx context.Context, cmd services.Command, err error) {
		if err != nil {
			logger.Printf("Command failed: %v", err)
		}
	})

	// HTTP handler
	handler := httpadapter.NewHandler(vpnService, executor, store, logger)

	// Serve web UI
	fs := http.FileServer(http.FS(webUI))
	// Note: webui/dist should be built before embedding
	_ = fs

	// Start server
	server := httpadapter.NewServer(handler, logger, cfg.APIUnixSocket, fmt.Sprintf("127.0.0.1:%d", cfg.APITCPPort))

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go func() {
		if err := server.Start(ctx); err != nil {
			logger.Printf("Server error: %v", err)
		}
	}()

	// Auto-connect if configured
	if cfg.AutoConnect {
		go func() {
			time.Sleep(2 * time.Second)
			logger.Println("Auto-connect enabled, starting VPN...")
			if _, err := vpnService.Connect(ctx); err != nil {
				logger.Printf("Auto-connect failed: %v", err)
			}
		}()
	}

	// Wait for shutdown signal
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	logger.Println("Shutdown signal received, cleaning up...")
	cancel()

	if err := vpnService.Disconnect(context.Background()); err != nil {
		logger.Printf("Disconnect error: %v", err)
	}

	logger.Println("Shutdown complete")
}
