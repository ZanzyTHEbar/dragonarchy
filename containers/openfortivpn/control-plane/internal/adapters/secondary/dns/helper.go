package dns

import (
	"context"
	"fmt"
	"os/exec"

	"openfortivpn-control-plane/internal/core/domain"
	"openfortivpn-control-plane/internal/pkg/errors"
)

// HelperResolver delegates DNS operations to the dns-helper.sh script
type HelperResolver struct {
	config *domain.Config
}

// NewHelperResolver creates a new DNS helper resolver
func NewHelperResolver(cfg *domain.Config) *HelperResolver {
	return &HelperResolver{config: cfg}
}

// Apply split DNS
func (r *HelperResolver) Apply(ctx context.Context) error {
	cmd := exec.CommandContext(ctx, "/usr/local/bin/dns-helper.sh", "--apply")
	out, err := cmd.CombinedOutput()
	if err != nil {
		return errors.Wrap(err, errors.CodeDNSApplyFailed, fmt.Sprintf("dns-helper failed: %s", string(out)))
	}
	return nil
}

// Reset DNS
func (r *HelperResolver) Reset(ctx context.Context) error {
	cmd := exec.CommandContext(ctx, "/usr/local/bin/dns-helper.sh", "--reset")
	out, err := cmd.CombinedOutput()
	if err != nil {
		return errors.Wrap(err, errors.CodeDNSResetFailed, fmt.Sprintf("dns-helper reset failed: %s", string(out)))
	}
	return nil
}
