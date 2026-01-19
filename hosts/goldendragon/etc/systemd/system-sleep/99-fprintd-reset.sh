#!/usr/bin/env bash
# Reset fprintd service on suspend/resume to prevent device claim issues
# This script runs before suspend and after resume

case "${1}" in
  pre)
    # Before suspend: ensure fprintd releases all claims
    logger -t fprintd-reset "Stopping fprintd before suspend to release device claims"
    systemctl stop fprintd.service
    ;;
  post)
    # After resume: start fresh fprintd instance
    logger -t fprintd-reset "Restarting fprintd after resume with clean state"
    sleep 2
    systemctl start fprintd.service
    ;;
esac
