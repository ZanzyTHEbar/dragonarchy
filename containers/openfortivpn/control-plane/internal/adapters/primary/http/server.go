package http

import (
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
)

// Server holds the HTTP server configuration
type Server struct {
	handler  *Handler
	logger   *log.Logger
	unixSock string
	tcpAddr  string
}

// NewServer creates a new HTTP server
func NewServer(handler *Handler, logger *log.Logger, unixSock, tcpAddr string) *Server {
	return &Server{
		handler:  handler,
		logger:   logger,
		unixSock: unixSock,
		tcpAddr:  tcpAddr,
	}
}

// Start starts both Unix socket and TCP listeners
func (s *Server) Start(ctx context.Context) error {
	mux := http.NewServeMux()
	s.handler.RegisterRoutes(mux)

	// Unix socket listener
	if err := os.MkdirAll(filepath.Dir(s.unixSock), 0755); err != nil {
		return fmt.Errorf("failed to create socket directory: %w", err)
	}
	os.Remove(s.unixSock)

	unixListener, err := net.Listen("unix", s.unixSock)
	if err != nil {
		return fmt.Errorf("failed to create unix socket: %w", err)
	}
	defer unixListener.Close()
	os.Chmod(s.unixSock, 0666)

	unixServer := &http.Server{Handler: mux}
	go func() {
		s.logger.Printf("Unix API listening on %s", s.unixSock)
		if err := unixServer.Serve(unixListener); err != nil && err != http.ErrServerClosed {
			s.logger.Printf("Unix server error: %v", err)
		}
	}()

	// TCP listener
	tcpListener, err := net.Listen("tcp", s.tcpAddr)
	if err != nil {
		return fmt.Errorf("failed to create tcp listener: %w", err)
	}
	defer tcpListener.Close()

	tcpServer := &http.Server{Handler: mux}
	go func() {
		s.logger.Printf("TCP API listening on %s", tcpListener.Addr())
		if err := tcpServer.Serve(tcpListener); err != nil && err != http.ErrServerClosed {
			s.logger.Printf("TCP server error: %v", err)
		}
	}()

	<-ctx.Done()

	s.logger.Println("Shutting down HTTP servers...")
	unixServer.Shutdown(context.Background())
	tcpServer.Shutdown(context.Background())

	return nil
}
