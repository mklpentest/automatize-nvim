#!/usr/bin/env bash

set -euo pipefall

NVIM_DIR="$HOME/.config/nvim"
LAZYVIM_REPO="https://github.com/LazyVim/starter"
NVIM_MIN_VERSION="0.11.0"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"

info()  { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m[*]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[*]\033[0m %s\n' "$*"; }

if [[ $EUID -eq 0 ]]; then
  echo "No ejecutes el script como root. Se pedirá sudo cuando haga falta">&2
  exit 1
fi

pkg_installed() { dpkg -s "$1" &>/dev/null; }

install_pkgs() {
  local missing=()
  for p in "$@"; do
    pkg_installed "$p" || missing+=("$p")
  done
  if ((${missing[@]})); then
    info "Instalando: ${missing[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y "${missing[@]}"
  fi
}

# Compara versiones 
version_ge() { [[ "$printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]; }

info "Comprobando dependencias"
install_pkgs git curl build-essential ripgrep fd-find unzip fontconfig \
  nodejs npm python3 python3-venv python3-pip

mkdir -p "$HOME/.local/bin/"
if ! command -v fd &>/dev/null && command -v fdfind &>/dev/null; then
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  ok "Enlace fd -> fdfind creado en ~/.local/bin/"
fi

case ":$PATH:" in
  *":$HOME/.local/bin/:"*) ;;
  *) warn "~/.local/bin no está en tu PATH; añádelo a ~/.bashrc o ~/.profile" ;;
esac

# Neovim
install_nvim_tarball() {
  local arch asset tmp
  case "$(unamme -m)" in
    x86_64)           arch="x86_64" ;;
    aarch64|arm64)    arch="arm64" ;;
    *) echo "Arquitectura no soportada: $(uname -m)" >&2; exit 1 ;;
  esac

  asset="nvim-linux-$(arch)"
  tmp="$(mktemp -d)"
  info "Descargando Neovim (${asset})"
  curl -fL "https://github.com/neovim/neovim/releases/latest/download/${asset}.tar.gz" -o "$tmp/nvim.tar.gz"
  sudo rm -rf "/opt/${asset}"
  sudo tar -C /opt -xzf "$tmp/nvim.tar.gz"
  sudo ln -sf "/opt/${asset}/bin/nvim" /usr/local/bin/nvim
  rm -rf "$tmp"
  hash -r
}

if command -v nvim &>/dev/null; then
  current="$(nvim --version | head -n1 | sed -E 's/^NVIM v([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
  if version_ge "$current" "$NVIM_MIN_VERSION"; then
    ok "Neovim ya instalado (v$current)"
  else
    warn "Neovim v$current es demasiado antiguo. Instalando nuevo"
    install_nvim_tarball
    ok "Neovim actualizado ($(nvim --version | head -n1))"
  fi
else
  install_nvim_tarball
  ok "Neovim instalado ($(nvim --version | head -n1))"
fi

# LazyVim
if [[ -f "$NVIM_DIR/lazyvim.json" || -f "$NVIM_DIR/lua/config/lazy.lua" ]]; then
  ok "LazyVim ya instalado en $NVIM_DIR"
elif [[ -e "$NVIM_DIR" ]]; then
  warn "Ya existe $NVIM_DIR y no parece LazyVim"
  warn "Muévelo, por ejemplo: mv $NVIM_DIR $NVIM_DIR.bak"
else
  info "Instalando LazyVim"
  git clone --depth 1 "$LAZYVIM_REPO" "$NVIM_DIR"
  rm -rf "$NVIM_DIR/.git"

  info "Descargando plugins"
  nvim --headless "+Lazy! sync" +qa || warn "La sincronización inicial falló; se completará al abrir neovim"
  ok "LazyVim instalado"
fi

# Jetbrains font
if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd"; then
  ok "JetBrainsMono ya instalado"
else
  info "Descargando JetBrainsMono font"
  tmp="$(mktemp -d)"
  curl -fL "$FONT_URL" -o "$tmp/JetBrainsMono.zip"
  mkdir -p "$FONT_DIR"
  unzip -oq "$tmp/JetBrainsMono.zip" -x "LICENSE*" "README*" -d "$FONT_DIR"
  rm -rf "$tmp"
  fc-cache -f
  ok "JetBrainsMono instalado en $FONT_DIR"
fi

echo
ok "Todo listo"
warn "Recuerda seleccionar la fuente en la terminal"
