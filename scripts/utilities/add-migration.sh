#!/bin/bash

set -e

# Find the repository root
REPO_ROOT=$(git rev-parse --show-toplevel)
MIGRATIONS_DIR="$REPO_ROOT/migrations"

# Ensure the migrations directory exists
mkdir -p "$MIGRATIONS_DIR"

# Create a new migration file with a unix timestamp
migration_file="$MIGRATIONS_DIR/$(date +%s).sh"
migration_name=$(basename "$migration_file")

# Add some boilerplate to the migration file
cat <<EOL > "$migration_file"
#!/bin/bash

set -e

echo "Running migration $migration_name"

# Your migration code here

EOL

chmod +x "$migration_file"

echo "Created new migration: $migration_file"
echo
echo "Run migrations with:"
echo "  ./scripts/install/run-migrations.sh"
echo "Or as part of a full update:"
echo "  ./scripts/install/update.sh"

# Open the new migration file in the user's editor
if [ -n "$EDITOR" ]; then
    "$EDITOR" "$migration_file"
elif command -v nvim &>/dev/null; then
    nvim "$migration_file"
elif command -v code &>/dev/null; then
    code --wait "$migration_file"
else
    # Fallback to vi
    vi "$migration_file"
fi
