#!/data/data/com.termux/files/usr/bin/bash
# Utilidades de dependencias para Termux (idempotentes)

# Uso:
#   source "$HOME/Proyectos/widgets-termux/lib/util_deps.sh"
#   ensure_cmd <comando> <paquete>
#   ensure_python_module <modulo>
#   ensure_storage
#   ensure_paths

ensure_cmd() {
  local cmd="$1" pkg="$2"
  command -v "$cmd" >/dev/null 2>&1 && return 0
  [ -z "$pkg" ] && pkg="$cmd"
  pkg install -y "$pkg" >/dev/null 2>&1
}

ensure_python_module() {
  local mod="$1"
  python -c "import $mod" >/dev/null 2>&1 && return 0
  python -m pip install --user "$mod" >/dev/null 2>&1
}

ensure_storage() {
  [ -d "$HOME/storage/shared" ] && return 0
  command -v termux-setup-storage >/dev/null 2>&1 && termux-setup-storage >/dev/null 2>&1 || true
}

ensure_paths() {
  mkdir -p "$HOME/.shortcuts" "$HOME/bin"
  local pf="$HOME/.profile"
  grep -q 'export PATH="$HOME/bin:$PATH"' "$pf" 2>/dev/null || echo 'export PATH="$HOME/bin:$PATH"' >> "$pf"
}
