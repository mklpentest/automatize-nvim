#!/usr/bin/env bash

set -euo pipefail

NVIM_DIR="$HOME/.config/nvim"
LAZYVIM_REPO="https://github.com/LazyVim/starter"

info()  { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m[v]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

if [[ $EUID -eq 0 ]]; then
    echo "No ejecutes este script como root; usa tu usuario, te pedirá sudo cuando haga falta" >&2
    exit 1
fi

pkg_installed() { pacman -Qi "$1" &>/dev/null; }

install_pkgs() {
  local missing=()
  for p in "$@"; do
    pkg_installed "$p" || missing+=("$p")
  done
  if ((${#missing[@]})); then
    info "Instalando: ${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}"
  fi
}

# Dependencias LazyVim
info "Comprobando dependecias base"
install_pkgs git curl base-devel ripgrep fd unzip nodejs npm python

# Neovim
if command -v nvim &>/dev/null; then
  ok "Neovim ya instalado ($(nvim --version | head -n1))"
else
  install_pkgs neovim
  ok "Neovim instalado"
fi

# LazyVim
if [[ -f "$NVIM_DIR/lazyvim.json" || -d "$NVIM_DIR/lua/config" && -f "$NVIM_DIR/lua/config/lazy.lua" ]]; then
  ok "LazyVim ya instalado en $NVIM_DIR"
elif [[ -e "$NVIM_DIR" ]]; then
  warn "Ya existe $NVIM_DIR y no parece LazyVim"
  warn "Muévelo. Por ejemplo: mv $NVIM_DIR $NVIM_DIR.bak"
else
  info "Instalando LazyVim..."
  git clone --depth 1 "$LAZYVIM_REPO" "$NVIM_DIR"
  rm -rf "$NVIM_DIR/.git"

  info "Sincronizando..."
  nvim --headless "+Lazy! sync" +qa || warn "La sincronización inicial falló,"
  ok "LazyVim instalado"
fi

# Jetbrains fonts
if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd"; then
  ok "JetBrainsMono ya está instalada"
else
  install_pkgs ttf-jetbrains-mono-nerd fontconfig
  fc-cache -f
  ok "JetBrainsMono instalada"
fi

echo
ok "Todo listo. Abre nvim para que Mason termine de instalar pyright y ruff"
warn "Recuerda seleccionar 'JetBrainsMono' en la configuración de la terminal"

