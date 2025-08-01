#!/bin/bash

# CPTC Kali VM Bootstrap Script
# Installs tools for Collegiate Penetration Testing Competition

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root for security reasons"
   exit 1
fi

log "Starting CPTC Kali VM Bootstrap..."

# Update system
log "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential dependencies
log "Installing essential dependencies..."
sudo apt install -y curl wget git build-essential libssl-dev pkg-config \
    python3-dev python3-pip python3-venv docker.io docker-compose \
    zsh fonts-powerline libclang-dev llvm-dev clang \
    libkrb5-dev libgssapi-krb5-2 vim tmux seclists

# Enable and start Docker
log "Configuring Docker..."
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# Apply Docker group membership immediately
log "Applying Docker group membership..."
newgrp docker << EOFNEWGRP || warn "Could not apply Docker group immediately - you may need to log out/in"
docker --version
EOFNEWGRP

# Install Oh My Zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    
    # Change default shell to zsh
    sudo chsh -s $(which zsh) $USER
else
    log "Oh My Zsh already installed, skipping..."
fi

# Install Oh My Zsh plugins
log "Installing Oh My Zsh plugins..."
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Clone plugins
git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions 2>/dev/null || log "zsh-autosuggestions already exists"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting 2>/dev/null || log "zsh-syntax-highlighting already exists"
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting $ZSH_CUSTOM/plugins/fast-syntax-highlighting 2>/dev/null || log "fast-syntax-highlighting already exists"

# Update .zshrc with plugins and theme
if ! grep -q "zsh-autosuggestions" ~/.zshrc; then
    sed -i 's/^plugins=(git)$/plugins=(git zsh-syntax-highlighting zsh-autosuggestions fast-syntax-highlighting)/' ~/.zshrc
    log "Updated .zshrc with plugins"
else
    log "Plugins already configured in .zshrc"
fi

# Set minimal theme
sed -i 's/^ZSH_THEME="robbyrussell"$/ZSH_THEME="minimal"/' ~/.zshrc
log "Set Oh My Zsh theme to minimal"

# Install Rustup
if ! command -v rustc &> /dev/null; then
    log "Installing Rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    
    # Add cargo to PATH in .zshrc
    echo 'export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"' >> ~/.zshrc
else
    log "Rust already installed, skipping..."
fi

# Install uv (Python package manager)
if ! command -v uv &> /dev/null; then
    log "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    
    # Add uv to current PATH immediately
    export PATH="$HOME/.local/bin:$PATH"
    
    # Add uv to PATH in .zshrc for future sessions
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
    
    # Verify installation
    if command -v uv &> /dev/null; then
        log "uv installed successfully"
    else
        error "uv installation failed"
        exit 1
    fi
else
    log "uv already installed, skipping..."
fi

# Ensure cargo and uv are in current PATH
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

# Install Python tools using uv
log "Installing Python security tools with uv..."

# Install tools from GitHub repositories
declare -a python_tools=(
    "git+https://github.com/Pennyw0rth/NetExec.git"
    "git+https://github.com/ly4k/Certipy.git"
    "git+https://github.com/fortra/impacket.git"
)

for tool in "${python_tools[@]}"; do
    tool_name=$(basename ${tool%.git} | sed 's/.*\///')
    log "Installing $tool_name..."
    uv tool install "$tool" || warn "Failed to install $tool_name, continuing..."
done

# Install bloodyAD 
log "Installing bloodyAD..."
uv tool install "git+https://github.com/CravateRouge/bloodyAD.git" || warn "Failed to install bloodyAD, continuing..."

# Create symlink for bloodyad command
if command -v bloodyAD &> /dev/null; then
    ln -sf $(which bloodyAD) ~/.local/bin/bloodyad 2>/dev/null || warn "Could not create bloodyad symlink"
    log "Created 'bloodyad' symlink for convenience"
fi

# Install BloodHound CE Python ingestors (correct branch)
log "Installing BloodHound CE Python ingestors..."
uv tool install "git+https://github.com/dirkjanm/BloodHound.py.git@bloodhound-ce" || warn "Failed to install BloodHound CE Python ingestors"

# Install Rust tools
log "Installing Rust security tools..."

# Install cargo-update first
cargo install cargo-update || warn "Failed to install cargo-update"

# Install rusthound-ce with force flag
log "Installing rusthound-ce..."
cargo install --force --git https://github.com/g0h4n/RustHound-CE.git || warn "Failed to install rusthound-ce"

# Download BloodHound CE and rockyou
log "Setting up BloodHound CE..."
cd ~
curl -Lo ./docker-compose.yml https://ghst.ly/getbhce

if [ -f "./docker-compose.yml" ]; then
    log "Pulling BloodHound CE Docker images..."
    # Try with newgrp first, fallback to warning about logout/login
    if groups | grep -q docker; then
        docker-compose pull || warn "Docker pull failed - you may need to log out and log back in to apply Docker group membership"
    else
        warn "Docker group not active yet - skipping pull. Run 'docker-compose pull' after logging out/in"
    fi
    
    log "BloodHound CE docker-compose.yml saved to home directory"
    log "To start BloodHound CE, run: docker-compose up -d"
else
    error "Failed to download BloodHound CE docker-compose.yml"
fi

# Download rockyou wordlist
log "Downloading rockyou wordlist..."
curl -Lo ~/rockyou.txt.gz https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt
log "rockyou.txt.gz saved to home directory"

# Create useful aliases in .zshrc
log "Adding useful aliases to .zshrc..."
cat >> ~/.zshrc << 'EOF'

# CPTC Aliases
alias bhce='docker-compose up -d'
alias bhce-stop='docker-compose down'
alias bhce-logs='docker-compose logs -f'

# Update all tools
alias update-cargo='cargo install-update -a'
alias update-uv='uv tool upgrade --all'
EOF

# Create tools directory structure
log "Creating tools directory structure..."
mkdir -p ~/tools/{wordlists,scripts,loot,notes}

# Set proper permissions for Docker
log "Configuring Docker permissions..."
sudo chmod 666 /var/run/docker.sock 2>/dev/null || warn "Could not set Docker socket permissions"

# Final setup
log "Performing final setup..."

# Source the updated .zshrc to make changes available
log "Configuration complete!"

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  CPTC Kali VM Bootstrap Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Log out and log back in (or restart) to apply shell changes"
echo "2. Verify installations with:"
echo "   - rustc --version"
echo "   - uv --version"
echo "   - python3 -m pip list | grep -E '(impacket|certipy|netexec)'"
echo
echo -e "${YELLOW}Installed tools:${NC}"
echo "• Oh My Zsh with syntax highlighting and autosuggestions"
echo "• Rust toolchain with cargo-update"
echo "• uv Python package manager"
echo "• Python tools: bloodyAD, netexec, certipy, impacket"
echo "• BloodHound CE Python ingestors (correct branch)"
echo "• Rust tools: rusthound-ce"
echo "• BloodHound CE (Docker): ~/docker-compose.yml"
echo "• SecLists wordlists via apt"
echo "• rockyou.txt.gz in home directory"
echo
echo -e "${YELLOW}Useful commands:${NC}"
echo "• bhce - Start BloodHound CE"
echo "• bhce-stop - Stop BloodHound CE"
echo "• update-cargo - Update all Cargo tools"
echo "• update-uv - Update all uv tools"
echo
echo -e "${GREEN}Happy hacking! 🛡️${NC}"
