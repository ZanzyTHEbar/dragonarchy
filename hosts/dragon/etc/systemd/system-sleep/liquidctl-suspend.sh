#!/bin/bash
# systemd-suspend hook for liquidctl
# Ensures AIO cooler state is preserved during suspend/resume

case "$1" in
    pre)
        # Before suspend - save current liquidctl state
        echo "Dragon: Preparing liquidctl for suspend..."
        # No special action needed - liquidctl state is in hardware
        ;;
    post)
        # After resume - reinitialize liquidctl
        echo "Dragon: Reinitializing liquidctl after resume..."
        # Wait a moment for USB devices to stabilize
        sleep 2
        
        # Reinitialize the AIO cooler
        /usr/bin/liquidctl initialize --match "h100i" || true
        
        # Reapply fan curves
        /usr/bin/liquidctl set fan speed --match "h100i" \
            30 20 \
            40 30 \
            50 50 \
            60 70 \
            70 100 || true
        
        # Reapply LED settings
        /usr/bin/liquidctl set led color fixed 0080ff --match "h100i" || true
        
        echo "Dragon: liquidctl reinitialized"
        ;;
esac

