#!/bin/bash

POLICY_FILE="/workspaces/hotel-poc-app/.devcontainer/security-policy.json"
LOG_FILE="/tmp/seti-security.log"
BASHRC="/home/node/.bashrc"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log_violation() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] VIOLATION: $1" >> "$LOG_FILE"
}

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     SETI Security Guard — Aplicando políticas     ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── Leer blacklists del JSON ──────────────────────────────────────────────────
NPM_BLACKLIST=$(python3 -c "
import json
with open('$POLICY_FILE') as f:
    p = json.load(f)
print(' '.join(p['rules']['npm_blacklist']))
")

PIP_BLACKLIST=$(python3 -c "
import json
with open('$POLICY_FILE') as f:
    p = json.load(f)
print(' '.join(p['rules']['pip_blacklist']))
")

URL_BLACKLIST=$(python3 -c "
import json
with open('$POLICY_FILE') as f:
    p = json.load(f)
print(' '.join(p['rules']['url_blacklist']))
")

EXT_BLACKLIST=$(python3 -c "
import json
with open('$POLICY_FILE') as f:
    p = json.load(f)
print(' '.join(p['rules']['file_extension_blacklist']))
")

# ── Instalar interceptores en .bashrc ─────────────────────────────────────────
echo -e "🛡️  [1/3] Instalando interceptores de comandos..."

cat >> "$BASHRC" << ALIASES

# ── SETI Security Guard ───────────────────────────────────────────────────────
export SETI_POLICY="$POLICY_FILE"
export SETI_LOG="$LOG_FILE"

# npm install interceptado
npm() {
  if [[ "\$1" == "install" || "\$1" == "i" ]]; then
    for pkg in "\${@:2}"; do
      pkg_clean=\$(echo "\$pkg" | sed 's/@.*//' | sed 's/^--.*//')
      [ -z "\$pkg_clean" ] && continue
      for banned in $NPM_BLACKLIST; do
        if [[ "\$pkg_clean" == "\$banned" ]]; then
          echo ""
          echo "🚫 SETI SECURITY GUARD — PAQUETE BLOQUEADO"
          echo "   Paquete  : \$pkg_clean"
          echo "   Política : \$SETI_POLICY"
          echo "   Contacto : seguridad@seti.com.co"
          echo ""
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] BLOCKED npm install \$pkg_clean" >> "\$SETI_LOG"
          return 1
        fi
      done
    done
  fi
  command npm "\$@"
}
export -f npm

# pip install interceptado
pip() {
  if [[ "\$1" == "install" ]]; then
    for pkg in "\${@:2}"; do
      pkg_clean=\$(echo "\$pkg" | sed 's/[>=<].*//' | sed 's/^--.*//')
      [ -z "\$pkg_clean" ] && continue
      for banned in $PIP_BLACKLIST; do
        if [[ "\$pkg_clean" == "\$banned" ]]; then
          echo ""
          echo "🚫 SETI SECURITY GUARD — PAQUETE BLOQUEADO"
          echo "   Paquete  : \$pkg_clean"
          echo "   Política : \$SETI_POLICY"
          echo "   Contacto : seguridad@seti.com.co"
          echo ""
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] BLOCKED pip install \$pkg_clean" >> "\$SETI_LOG"
          return 1
        fi
      done
    done
  fi
  command pip "\$@"
}
export -f pip

# pip3 interceptado
pip3() {
  pip "\$@"
}
export -f pip3

# curl interceptado
curl() {
  for banned_url in $URL_BLACKLIST; do
    for arg in "\$@"; do
      if [[ "\$arg" == *"\$banned_url"* ]]; then
        echo ""
        echo "🚫 SETI SECURITY GUARD — URL BLOQUEADA"
        echo "   URL      : \$arg"
        echo "   Política : \$SETI_POLICY"
        echo "   Contacto : seguridad@seti.com.co"
        echo ""
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] BLOCKED curl \$arg" >> "\$SETI_LOG"
        return 1
      fi
    done
  done
  command curl "\$@"
}
export -f curl

# wget interceptado
wget() {
  for banned_url in $URL_BLACKLIST; do
    for arg in "\$@"; do
      if [[ "\$arg" == *"\$banned_url"* ]]; then
        echo ""
        echo "🚫 SETI SECURITY GUARD — URL BLOQUEADA"
        echo "   URL      : \$arg"
        echo "   Política : \$SETI_POLICY"
        echo "   Contacto : seguridad@seti.com.co"
        echo ""
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] BLOCKED wget \$arg" >> "\$SETI_LOG"
        return 1
      fi
    done
  done
  command wget "\$@"
}
export -f wget

# ── fin SETI Security Guard ───────────────────────────────────────────────────
ALIASES

echo -e "    ${GREEN}✅ Interceptores instalados (npm, pip, pip3, curl, wget)${NC}"

# ── Git pre-commit hook ───────────────────────────────────────────────────────
echo -e "🔒 [2/3] Instalando git hook pre-commit..."

mkdir -p /workspaces/hotel-poc-app/.git/hooks
cat > /workspaces/hotel-poc-app/.git/hooks/pre-commit << HOOK
#!/bin/bash

POLICY_FILE="/workspaces/hotel-poc-app/.devcontainer/security-policy.json"
LOG_FILE="/tmp/seti-security.log"
BLOCKED=false

EXT_BLACKLIST=\$(python3 -c "
import json
with open('\$POLICY_FILE') as f:
    p = json.load(f)
print(' '.join(p['rules']['file_extension_blacklist']))
")

for file in \$(git diff --cached --name-only); do
  for ext in \$EXT_BLACKLIST; do
    if [[ "\$file" == *"\$ext" ]]; then
      echo ""
      echo "🚫 SETI SECURITY GUARD — ARCHIVO BLOQUEADO EN COMMIT"
      echo "   Archivo  : \$file"
      echo "   Extensión: \$ext"
      echo "   Política : \$POLICY_FILE"
      echo ""
      echo "[\$(date '+%Y-%m-%d %H:%M:%S')] BLOCKED commit \$file (\$ext)" >> "\$LOG_FILE"
      BLOCKED=true
    fi
  done
done

if [ "\$BLOCKED" = true ]; then
  echo "❌ Commit bloqueado por política de seguridad SETI."
  echo "   Contacto: seguridad@seti.com.co"
  exit 1
fi
HOOK

chmod +x /workspaces/hotel-poc-app/.git/hooks/pre-commit
echo -e "    ${GREEN}✅ pre-commit hook instalado${NC}"

# ── Resumen de política activa ────────────────────────────────────────────────
echo -e "📋 [3/3] Política activa:"
echo -e "    npm bloqueados : ${RED}$NPM_BLACKLIST${NC}"
echo -e "    pip bloqueados : ${RED}$PIP_BLACKLIST${NC}"
echo -e "    URLs bloqueadas: ${RED}$URL_BLACKLIST${NC}"
echo -e "    Extensiones    : ${RED}$EXT_BLACKLIST${NC}"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   🛡️  SETI Security Guard activo en este entorno  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
