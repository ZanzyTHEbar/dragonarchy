package errors

import (
	"fmt"

	"github.com/ZanzyTHEbar/faults-go"
)

// Domain error codes
const (
	CodeInvalidConfig     faults.Code = "openfortivpn.config.invalid"
	CodeVPNAlreadyRunning faults.Code = "openfortivpn.vpn.already_running"
	CodeVPNNotRunning     faults.Code = "openfortivpn.vpn.not_running"
	CodeSAMLTimeout       faults.Code = "openfortivpn.saml.timeout"
	CodeInterfaceTimeout  faults.Code = "openfortivpn.interface.timeout"
	CodeDNSApplyFailed    faults.Code = "openfortivpn.dns.apply_failed"
	CodeDNSResetFailed    faults.Code = "openfortivpn.dns.reset_failed"
	CodeProcessFailed     faults.Code = "openfortivpn.process.failed"
	CodeConfigNotFound    faults.Code = "openfortivpn.config.not_found"
	CodeAPIError          faults.Code = "openfortivpn.api.error"
)

func init() {
	faults.RegisterCodes(faults.Mapping{
		CodeInvalidConfig:     faults.TransportInvalidArgument,
		CodeVPNAlreadyRunning: faults.TransportFailedPrecondition,
		CodeVPNNotRunning:     faults.TransportFailedPrecondition,
		CodeSAMLTimeout:       faults.TransportDeadlineExceeded,
		CodeInterfaceTimeout:  faults.TransportDeadlineExceeded,
		CodeDNSApplyFailed:    faults.TransportInternal,
		CodeDNSResetFailed:    faults.TransportInternal,
		CodeProcessFailed:     faults.TransportInternal,
		CodeConfigNotFound:    faults.TransportNotFound,
		CodeAPIError:          faults.TransportInternal,
	})
}

// New creates a new structured fault
func New(code faults.Code, message string, fields ...any) error {
	return faults.New(code, message, fields...)
}

// Wrap wraps an existing error with additional context
func Wrap(err error, code faults.Code, message string, fields ...any) error {
	return faults.Wrap(code, message, err, fields...)
}

// IsCode reports whether err carries the given code
func IsCode(err error, code faults.Code) bool {
	return faults.IsCode(err, code)
}

// CodeOf returns the fault code from an error
func CodeOf(err error) faults.Code {
	return faults.CodeOf(err)
}

// ConfigError returns a standardized config error
func ConfigError(field string, detail string) error {
	return New(CodeInvalidConfig, fmt.Sprintf("invalid config: %s", field), "field", field, "detail", detail)
}

// ProcessError returns a standardized process management error
func ProcessError(op string, err error) error {
	return Wrap(err, CodeProcessFailed, fmt.Sprintf("failed to %s openfortivpn", op), "operation", op)
}
