package cli

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"
)

// APIClient handles communication with the container API
type APIClient struct {
	baseURL string
}

// NewAPIClient creates a new API client
func NewAPIClient() *APIClient {
	socket := os.Getenv("OPENFORTIVPN_API_SOCKET")
	if socket != "" {
		return &APIClient{baseURL: "http://unix"}
	}
	url := os.Getenv("OPENFORTIVPN_API_URL")
	if url == "" {
		url = "http://127.0.0.1:8080"
	}
	return &APIClient{baseURL: url}
}

func (c *APIClient) request(method, path string, body io.Reader) (*http.Response, error) {
	url := c.baseURL + path
	req, err := http.NewRequest(method, url, body)
	if err != nil {
		return nil, err
	}

	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	client := &http.Client{}
	return client.Do(req)
}

func (c *APIClient) getJSON(path string, out any) error {
	resp, err := c.request("GET", path, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body))
	}

	return json.NewDecoder(resp.Body).Decode(out)
}

func (c *APIClient) postJSON(path string, in, out any) error {
	var body io.Reader
	if in != nil {
		data, err := json.Marshal(in)
		if err != nil {
			return err
		}
		body = strings.NewReader(string(data))
	}

	resp, err := c.request("POST", path, body)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(bodyBytes))
	}

	if out != nil {
		return json.NewDecoder(resp.Body).Decode(out)
	}
	return nil
}

// BuildCommands registers all CLI commands on the palette
func BuildCommands(palette *Palette) {
	client := NewAPIClient()

	// Status command
	statusCmd := &cobra.Command{
		Use:   "status",
		Short: "Show VPN status",
		RunE: func(cmd *cobra.Command, args []string) error {
			var status map[string]any
			if err := client.getJSON("/status", &status); err != nil {
				return err
			}
			data, _ := json.MarshalIndent(status, "", "  ")
			fmt.Println(string(data))
			return nil
		},
	}
	palette.Register("status", statusCmd)

	// Connect command
	connectCmd := &cobra.Command{
		Use:   "connect",
		Short: "Start VPN connection",
		RunE: func(cmd *cobra.Command, args []string) error {
			var result map[string]any
			if err := client.postJSON("/connect", nil, &result); err != nil {
				return err
			}
			data, _ := json.MarshalIndent(result, "", "  ")
			fmt.Println(string(data))

			if url, ok := result["saml_url"].(string); ok && url != "" {
				fmt.Printf("\nOpen this URL to complete SAML login:\n  %s\n\n", url)
				openBrowser(url)
			}
			return nil
		},
	}
	palette.Register("connect", connectCmd)

	// Disconnect command
	disconnectCmd := &cobra.Command{
		Use:   "disconnect",
		Short: "Stop VPN connection",
		RunE: func(cmd *cobra.Command, args []string) error {
			var result map[string]any
			if err := client.postJSON("/disconnect", nil, &result); err != nil {
				return err
			}
			data, _ := json.MarshalIndent(result, "", "  ")
			fmt.Println(string(data))
			return nil
		},
	}
	palette.Register("disconnect", disconnectCmd)

	// Health command
	healthCmd := &cobra.Command{
		Use:   "health",
		Short: "Check container health",
		RunE: func(cmd *cobra.Command, args []string) error {
			var result map[string]any
			if err := client.getJSON("/health", &result); err != nil {
				return err
			}
			data, _ := json.MarshalIndent(result, "", "  ")
			fmt.Println(string(data))
			return nil
		},
	}
	palette.Register("health", healthCmd)

	// Config command
	configCmd := &cobra.Command{
		Use:   "config",
		Short: "Show current config",
		RunE: func(cmd *cobra.Command, args []string) error {
			resp, err := client.request("GET", "/config", nil)
			if err != nil {
				return err
			}
			defer resp.Body.Close()
			io.Copy(os.Stdout, resp.Body)
			fmt.Println()
			return nil
		},
	}
	palette.Register("config", configCmd)
}

func openBrowser(url string) {
	var cmd string
	var args []string
	switch {
	case commandExists("xdg-open"):
		cmd = "xdg-open"
		args = []string{url}
	case commandExists("open"):
		cmd = "open"
		args = []string{url}
	case commandExists("python3"):
		cmd = "python3"
		args = []string{"-c", fmt.Sprintf("import webbrowser; webbrowser.open('%s')", url)}
	default:
		return
	}
	exec.Command(cmd, args...).Start()
}

func commandExists(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}
