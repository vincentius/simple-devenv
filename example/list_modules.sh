#!/bin/bash

# Path to custom addons directory
CUSTOM_ADDONS_PATH="/home/vincent/odoo_projects/bzbfedafin/custom_addons"

# Create a temporary file to store the modules
modules_file=$(mktemp)

# Find all directories containing manifest files and save to temp file
if ! find "$CUSTOM_ADDONS_PATH" -type f \( -name "__manifest__.py" -o -name "__openerp__.py" \) -exec dirname {} \; 2>/dev/null | while read dir; do
    if [ -f "$dir/__manifest__.py" ] || [ -f "$dir/__openerp__.py" ]; then
        # Check if the directory contains the expected Odoo module structure
        if [ -d "$dir/models" ] || [ -d "$dir/views" ] || [ -d "$dir/security" ]; then
            basename "$dir" >> "$modules_file"
        fi
    fi
done; then
    echo "Error: Failed to search for modules in $CUSTOM_ADDONS_PATH"
    exit 1
fi

# Read the modules and format as JSON array
modules=$(cat "$modules_file" | jq -R . | jq -s .)
rm "$modules_file"

# Update the tasks.json file
tasks_file=".vscode/tasks.json"
jq --arg modules "$modules" '.inputs[] |= if .id == "moduleToUpdate" then .options = ($modules|fromjson) else . end' "$tasks_file" > "${tasks_file}.tmp" && mv "${tasks_file}.tmp" "$tasks_file"
