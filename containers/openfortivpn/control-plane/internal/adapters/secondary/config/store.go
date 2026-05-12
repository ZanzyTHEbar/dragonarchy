package config

import (
	"os"

	"openfortivpn-control-plane/internal/core/ports"
	"openfortivpn-control-plane/internal/pkg/errors"
)

// FileStore implements ConfigStore using the filesystem
type FileStore struct {
	path string
}

// NewFileStore creates a new file-backed config store
func NewFileStore(path string) ports.ConfigStore {
	return &FileStore{path: path}
}

// Read reads the config file
func (s *FileStore) Read() ([]byte, error) {
	data, err := os.ReadFile(s.path)
	if err != nil {
		return nil, errors.Wrap(err, errors.CodeConfigNotFound, "failed to read config")
	}
	return data, nil
}

// Write writes the config file
func (s *FileStore) Write(data []byte) error {
	if err := os.WriteFile(s.path, data, 0640); err != nil {
		return errors.Wrap(err, errors.CodeInvalidConfig, "failed to write config")
	}
	return nil
}

// Path returns the config file path
func (s *FileStore) Path() string {
	return s.path
}
