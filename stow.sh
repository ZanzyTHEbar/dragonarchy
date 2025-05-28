stow -R -v config zsh
#sudo stow -R -t /etc -v etc

# Stow the systemd units to /etc/systemd/system/
sudo stow -R -t /etc/systemd/system -v systemd

# Reload systemd to recognize new or updated units
sudo systemctl daemon-reload

# Enable and start each .automount unit
for unit in systemd/*.automount; do
    unit_name=$(basename "$unit")
    echo "starting $unit_name"
    sudo systemctl enable "$unit_name"
    sudo systemctl start "$unit_name"
done





