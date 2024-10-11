#!/bin/bash

set -e

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source the configuration
source "$SCRIPT_DIR/config.sh"

# Function to display usage
usage() {
    echo "Usage: $0 <project_name> [odoo_version]"
    echo "  project_name: Name of the project/customer environment"
    echo "  odoo_version: Odoo version to use (default: 16.0)"
    exit 1
}

# Check if project name is provided
if [ -z "$1" ]; then
    usage
fi

# Set project-specific variables
PROJECT_NAME="$1"
ODOO_VERSION="${2:-16.0}"
PROJECT_PATH="$BASE_PATH/$PROJECT_NAME"
VENV_PATH="$PROJECT_PATH/venv"
CUSTOM_ADDONS_PATH="$PROJECT_PATH/custom_addons"
ODOO_BASE_PATH="/opt/odoos/$ODOO_VERSION"
ODOO_PATH="$ODOO_BASE_PATH/odoo"
ENTERPRISE_PATH="$ODOO_BASE_PATH/enterprise"
DESIGN_THEMES_PATH="$ODOO_BASE_PATH/design-themes"

# Install system dependencies
sudo apt update
sudo apt install -y "${SYSTEM_DEPENDENCIES[@]}"

# Install Python if not already installed
if ! command -v "python$PYTHON_VERSION" &> /dev/null; then
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt update
    sudo apt install -y "python$PYTHON_VERSION" "python$PYTHON_VERSION-venv" "python$PYTHON_VERSION-dev"
fi

# Install UV
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Create project directory
mkdir -p "$PROJECT_PATH"

# Create and activate virtual environment
"python$PYTHON_VERSION" -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"

# Clone or update Odoo repositories
sudo mkdir -p "$ODOO_BASE_PATH"
sudo chown "$USER:$USER" "$ODOO_BASE_PATH"
clone_or_pull "git@github.com:odoo/odoo.git" "$ODOO_PATH" "$ODOO_VERSION"
clone_or_pull "git@github.com:odoo/enterprise.git" "$ENTERPRISE_PATH" "$ODOO_VERSION"
clone_or_pull "git@github.com:odoo/design-themes.git" "$DESIGN_THEMES_PATH" "$ODOO_VERSION"

# Install Odoo requirements using UV
uv pip install -r "$ODOO_PATH/requirements.txt"

# Install additional development tools
uv pip install debugpy

# Create custom addons directory
mkdir -p "$CUSTOM_ADDONS_PATH"

# Function to replace placeholders in templates
replace_placeholders() {
    sed -e "s|\$VENV_PATH|$VENV_PATH|g" \
        -e "s|\$PROJECT_PATH|$PROJECT_PATH|g" \
        -e "s|\$ODOO_PATH|$ODOO_PATH|g" \
        -e "s|\$ENTERPRISE_PATH|$ENTERPRISE_PATH|g" \
        -e "s|\$DESIGN_THEMES_PATH|$DESIGN_THEMES_PATH|g" \
        -e "s|\$CUSTOM_ADDONS_PATH|$CUSTOM_ADDONS_PATH|g" \
        -e "s|\$USER|$USER|g" \
        -e "s|\$PROJECT_NAME|$PROJECT_NAME|g"
}

# Create run_odoo_debug.sh script
cat "$SCRIPT_DIR/templates/run_odoo_debug.sh.template" | replace_placeholders > "$PROJECT_PATH/run_odoo_debug.sh"
chmod +x "$PROJECT_PATH/run_odoo_debug.sh"

# Create Odoo configuration file
cat "$SCRIPT_DIR/templates/odoo.conf.template" | replace_placeholders > "$PROJECT_PATH/odoo.conf"

# Create VSCode workspace file
cat "$SCRIPT_DIR/templates/code_workspace.json.template" | replace_placeholders > "$PROJECT_PATH/$PROJECT_NAME.code-workspace"

# Create VSCode launch configuration
mkdir -p "$PROJECT_PATH/.vscode"
cat "$SCRIPT_DIR/templates/launch.json.template" | replace_placeholders > "$PROJECT_PATH/.vscode/launch.json"
cat "$SCRIPT_DIR/templates/tasks.json.template" | replace_placeholders > "$PROJECT_PATH/.vscode/tasks.json"

echo "Odoo development environment for $PROJECT_NAME setup complete!"
echo "Your custom addons should be placed in: $CUSTOM_ADDONS_PATH"
echo "To open the project in VSCode, use: code $PROJECT_PATH/$PROJECT_NAME.code-workspace"
echo "To run Odoo with debugging enabled, use the 'Python: Odoo' launch configuration in VSCode."
echo "NOTE: Ensure your SSH key is added to your GitHub account for Odoo, Enterprise, and design-themes repositories."