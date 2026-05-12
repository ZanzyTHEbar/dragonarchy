package http

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"openfortivpn-control-plane/internal/core/domain"
	"openfortivpn-control-plane/internal/core/ports"
	"openfortivpn-control-plane/internal/core/services"
)

// Handler holds HTTP handlers
type Handler struct {
	service  *services.VPNService
	executor *services.CommandExecutor
	store    ports.ConfigStore
	logger   *log.Logger
}

// NewHandler creates a new HTTP handler
func NewHandler(
	svc *services.VPNService,
	exec *services.CommandExecutor,
	store ports.ConfigStore,
	logger *log.Logger,
) *Handler {
	return &Handler{
		service:  svc,
		executor: exec,
		store:    store,
		logger:   logger,
	}
}

// RegisterRoutes registers all routes on the provided mux
func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /health", h.handleHealth)
	mux.HandleFunc("GET /status", h.handleStatus)
	mux.HandleFunc("POST /connect", h.handleConnect)
	mux.HandleFunc("POST /disconnect", h.handleDisconnect)
	mux.HandleFunc("GET /config", h.handleGetConfig)
	mux.HandleFunc("POST /config", h.handlePostConfig)
	mux.HandleFunc("GET /logs", h.handleLogs)
	mux.HandleFunc("GET /saml/status", h.handleSAMLStatus)
}

func (h *Handler) handleHealth(w http.ResponseWriter, r *http.Request) {
	status := h.service.Status()
	if status.State == domain.StateConnected && status.Interface == "" {
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{
			"status": "unhealthy",
			"reason": "VPN interface missing",
		})
		return
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func (h *Handler) handleStatus(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(h.service.Status())
}

func (h *Handler) handleConnect(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()

	var result services.ConnectResult
	cmd := &services.ConnectCommand{
		Service: h.service,
		Result:  &result,
	}

	if err := h.executor.Execute(ctx, cmd); err != nil {
		h.logger.Printf("Connect failed: %v", err)
		w.WriteHeader(http.StatusConflict)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(domain.ConnectResult{
		SAMLURL:  result.SAMLURL,
		SAMLPort: result.SAMLPort,
	})
}

func (h *Handler) handleDisconnect(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()

	cmd := &services.DisconnectCommand{Service: h.service}
	if err := h.executor.Execute(ctx, cmd); err != nil {
		h.logger.Printf("Disconnect failed: %v", err)
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"state": string(domain.StateDisconnected),
	})
}

func (h *Handler) handleGetConfig(w http.ResponseWriter, r *http.Request) {
	content, err := h.store.Read()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}
	w.Header().Set("Content-Type", "text/plain")
	w.Write(content)
}

func (h *Handler) handlePostConfig(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Config string `json:"config"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "invalid JSON"})
		return
	}

	if err := h.store.Write([]byte(req.Config)); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "config updated"})
}

func (h *Handler) handleLogs(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain")
	fmt.Fprintln(w, "Log streaming is not yet implemented.")
	fmt.Fprintln(w, "Use 'docker logs' or 'podman logs' to view container output.")
}

func (h *Handler) handleSAMLStatus(w http.ResponseWriter, r *http.Request) {
	status := h.service.Status()
	ready := status.State == domain.StateConnecting
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"ready": ready})
}

