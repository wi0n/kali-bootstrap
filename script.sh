#!/bin/zsh
# basic stuff
sudo apt update
sudo apt install tmux curl terminator git python3-dev faketime -y
sudo DEBIAN_FRONTEND=noninteractive apt install -y krb5-user cifs-utils
# docker compose
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
sudo apt install build-essential pkg-config libssl-dev libkrb5-dev libclang-dev clang libgssapi-krb5-2 -y
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# rustup
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"

# uv and tools
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
uv tool install git+https://github.com/Pennyw0rth/NetExec.git
uv tool install git+https://github.com/ly4k/Certipy.git
uv tool install git+https://github.com/fortra/impacket.git
uv tool install git+https://github.com/CravateRouge/bloodyAD.git
uv tool install git+https://github.com/dirkjanm/BloodHound.py.git@bloodhound-ce

# shell
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
sed -i 's/^plugins=(git)$/plugins=(git zsh-syntax-highlighting zsh-autosuggestions fast-syntax-highlighting)/' ~/.zshrc
sed -i 's/robbyrussell/minimal/g' ~/.zshrc

# rusthound
cargo install rusthound-ce
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.zshrc

# rockyou
curl -Lo ~/rockyou.txt https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt

# docker operations + bloodhound setup
mkdir -p ~/bloodhound
curl -Lo ~/bloodhound/docker-compose.yml https://ghst.ly/getbhce
sg docker -c 'docker-compose -f ~/bloodhound/docker-compose.yml pull'
sg docker -c '
BLOODHOUND_HOST=0.0.0.0 BLOODHOUND_PORT=8888 docker-compose -f ~/bloodhound/docker-compose.yml up -d

# Wait for the API to respond
echo "Waiting for BloodHound API to be ready..."
until curl -s -f http://localhost:8888 >/dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo " Ready!"

'
sg docker -c 'echo $(docker logs $(docker ps -qf "ancestor=specterops/bloodhound:latest") | grep -i "initial password") | cut -d# -f2'
source ~/.zshrc
