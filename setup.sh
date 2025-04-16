#!/bin/bash

# Script to replace laravel-boiler references with a given project identifier
# and back up original files into setup-backup.bak for easy reversion.

set -e

# Function to convert input to kebab-case
to_kebab_case() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g'
}

# Function to convert input to snake_case
to_snake_case() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_]//g'
}

# Default project identifier
default_identifier="Not-laravel-boiler"

read -rp "What is the project name to switch Laravel boiler to? [$default_identifier]: " identifier_input
identifier_input=${identifier_input:-$default_identifier}

# Convert formats
project_identifier=$(to_kebab_case "$identifier_input")
snake_identifier=$(to_snake_case "$identifier_input")

# List of paths to scan
paths=(
    ".github/workflows/dependency-review.yml"
    ".github/workflows/fix-php-code-style-issues.yml"
    ".github/workflows/phpunit-tests.yml"
    ".github/workflows/update-changelog.yml"
    ".env"
    ".env.example"
    "docker-compose.yml"
    "docker/mysql/setup.sql"
    "docker/nginx/conf.d/app.conf"
    "resources/views/welcome.blade.php"
)

files_to_process=()
backup_dir="setup-backup.bak"

# Make a clean backup folder
rm -rf "$backup_dir"
mkdir -p "$backup_dir"

for path in "${paths[@]}"; do
    if [[ ! -e "$path" ]]; then
        echo "Warning: Path does not exist: $path. Skipping..."
        continue
    fi

    if [[ -f "$path" ]]; then
        files_to_process+=("$path")
    elif [[ -d "$path" ]]; then
        while IFS= read -r -d '' file; do
            files_to_process+=("$file")
        done < <(find "$path" -type f -print0)
    fi
done

if [[ ${#files_to_process[@]} -eq 0 ]]; then
    echo "Error: No valid files found to process."
    exit 1
fi

read -rp "This will modify files permanently. Are you sure? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

count=0
modified_files=()

for file in "${files_to_process[@]}"; do
    extension="${file##*.}"
    if [[ ! "$extension" =~ ^(json|yml|yaml|env|sql|conf|txt|php)$ ]]; then
        continue
    fi

    echo "Processing: $file"
    echo "Original content (first 100 chars): $(head -c 100 "$file")"

    # Create path in backup dir
    backup_path="$backup_dir/$file"
    mkdir -p "$(dirname "$backup_path")"
    cp "$file" "$backup_path"

    temp_file=$(mktemp)
    sed -E \
        -e "s/laravel[- ]?boiler/${project_identifier}/gi" \
        -e "s/laravel[-_]?boiler/${snake_identifier}/gi" \
        "$file" > "$temp_file"

    if ! cmp -s "$file" "$temp_file"; then
        echo "Modified: $file"
        mv "$temp_file" "$file"
        modified_files+=("$file")
        ((count++))
    else
        echo "No changes in: $file"
        rm "$temp_file"
    fi
done

echo "Completed. Modified $count files."
echo "Backup stored in: $backup_dir"

# Write the fresh-state.sh script
cat > fresh-state.sh <<EOF
#!/bin/bash
# Script to restore the project to its original state using the setup-backup.bak

set -e

echo "Restoring backup..."

backup_dir="$backup_dir"

if [[ ! -d "\$backup_dir" ]]; then
    echo "Backup directory not found: \$backup_dir"
    exit 1
fi

restore_count=0
EOF

for file in "${modified_files[@]}"; do
    echo "cp \"$backup_dir/$file\" \"$file\"" >> fresh-state.sh
    echo '((restore_count++))' >> fresh-state.sh
done

cat >> fresh-state.sh <<EOF

echo "Restored \$restore_count files from backup."

# Kill Docker containers that start with the project identifier
echo "Checking for Docker containers matching '$project_identifier'..."
container_ids=\$(docker ps -q --filter "name=^/$project_identifier" 2>/dev/null)

if [[ -n "\$container_ids" ]]; then
    echo "Killing containers..."
    echo "\$container_ids" | xargs docker kill 2>/dev/null
    echo "Containers killed."
else
    echo "No containers found matching '$project_identifier'."
fi

rm -- "\$0"
EOF


chmod +x fresh-state.sh
echo "Generated fresh-state.sh — run it to undo changes."

echo "Checking for Docker containers with names containing 'laravel-boiler'..."
container_ids=$(docker ps -q --filter "name=laravel-boiler" 2>/dev/null)

if [[ -n "$container_ids" ]]; then
    echo "Found containers:"
    while IFS= read -r container_id; do
        container_name=$(docker inspect --format '{{.Name}}' "$container_id" | sed 's|^/||')
        echo "- $container_name ($container_id)"
    done <<< "$container_ids"

    echo "Killing containers..."
    echo "$container_ids" | xargs docker kill 2>/dev/null
    echo "Containers killed."
else
    echo "No containers found matching 'laravel-boiler'."
fi

# Rebuild and restart containers
echo "Rebuilding and starting containers..."
docker compose up -d --build

