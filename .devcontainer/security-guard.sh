#!/bin/bash

POLICY_URL="https://raw.githubusercontent.com/lezardvalleth/seti-security-policies/main/hotel-poc-policy.ini"
POLICY_FILE="/tmp/seti-security-policy.ini"
LOG_FILE="/tmp/seti-security.log"
BASHRC="/home/node/.bashrc"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     SETI Security Guard — Aplicando políticas     ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── Parser INI manual ─────────────────────────────────────────────────────────
parse_ini_section() {
  local file="$1"
  local section="$2"
  python3 - << EOF
section = None
items = []
with open('$file') as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('[') and line.endswith(']'):
            section = line[1:-1].strip()
            continue
        if section == '$section' and '=' not in line:
            items.append(line)
print(' '.join(items))
EOF
}

parse_ini_value() {
  local file="$1"
  local section="$2"
  local key="$3"
  python3 - << EOF
section = None
with open('$file') as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('[') and line.endswith(']'):
            section = line[1:-1].strip()
            continue
        if section == '$section' and line.startswith('$key='):
            print(line.split('=',1)[1])
            break
EOF
}

# ── Descargar política desde repo privado ─────────────────────────────────────
echo -e "🔐 [1/4] Descargando política desde repositorio SETI..."

if [ -z "$SETI_POLICY_TOKEN" ]; then
  echo -e "    ${RED}❌ SETI_POLICY_TOKEN no encontrado — abortando${NC}"
  exit 1
fi

HTTP_STATUS=$(curl -s -o "$POLICY_FILE" -w "%{http_code}" \
  -H "Authorization: token $SETI_POLICY_TOKEN" \
  -H "Accept: application/vnd.github.v3.raw" \
  "$POLICY_URL")

if [ "$HTTP_STATUS" != "200" ]; then
  echo -e "    ${RED}❌ No se pudo descargar la política (HTTP $HTTP_STATUS)${NC}"
  exit 1
fi

chmod 400 "$POLICY_FILE"

CLIENTE=$(parse_ini_value "$POLICY_FILE" "cliente" "nombre")
VERSION=$(parse_ini_value "$POLICY_FILE" "cliente" "version")
CONTACTO=$(parse_ini_value "$POLICY_FILE" "cliente" "contacto")

echo -e "    ${GREEN}✅ Política descargada — Cliente: $CLIENTE v$VERSION${NC}"

NPM_BLACKLIST=$(parse_ini_section "$POLICY_FILE" "npm")
PIP_BLACKLIST=$(parse_ini_section "$POLICY_FILE" "pip")
URL_BLACKLIST=$(parse_ini_section "$POLICY_FILE" "urls")
EXT_BLACKLIST=$(parse_ini_section "$POLICY_FILE" "archivos")

# ── Instalar interceptores en .bashrc ─────────────────────────────────────────
echo -e "🛡️  [2/4] Instalando interceptores de comandos..."

sed -i '/# ── SETI Security Guard/,/# ── fin SETI Security Guard/d' "$BASHRC"

cat >> "$BASHRC" << ALIASES

# ── SETI Security Guard ───────────────────────────────────────────────────────
export SETI_LOG="$LOG_FILE"
export SETI_CONTACTO="$CONTACTO"

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
          echo "   Contacto : \$SETI_CONTACTO"
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
          echo "   Contacto : \$SETI_CONTACTO"
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

curl() {
  for banned_url in $URL_BLACKLIST; do
    for arg in "\$@"; do
      if [[ "\$arg" == *"\$banned_url"* ]]; then
        echo ""
        echo "🚫 SETI SECURITY GUARD — URL BLOQUEADA"
        echo "   URL      : \$arg"
        echo "   Contacto : \$SETI_CONTACTO"
        echo ""
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] BLOCKED curl \$arg" >> "\$SETI_LOG"
        return 1
      fi
    done
  done
  command curl "\$@"
}
export -f curl

wget() {
  for banned_url in $URL_BLACKLIST; do
    for arg in "\$@"; do
      if [[ "\$arg" == *"\$banned_url"* ]]; then
        echo ""
        echo "🚫 SETI SECURITY GUARD — URL BLOQUEADA"
        echo "   URL      : \$arg"
        echo "   Contacto : \$SETI_CONTACTO"
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

echo -e "    ${GREEN}✅ Interceptores instalados (npm, pip, curl, wget)${NC}"

# ── Git pre-commit hook con parser Python ─────────────────────────────────────
echo -e "🔒 [3/4] Instalando git hook pre-commit..."

mkdir -p /workspaces/hotel-poc-app/.git/hooks
cat > /workspaces/hotel-poc-app/.git/hooks/pre-commit << 'HOOK'
#!/bin/bash
POLICY_FILE="/tmp/seti-security-policy.ini"
LOG_FILE="/tmp/seti-security.log"
BLOCKED=false

if [ ! -f "$POLICY_FILE" ]; then
  echo "⚠️  SETI: archivo de política no encontrado — commit permitido"
  exit 0
fi

EXT_BLACKLIST=$(python3 - << 'EOF'
section = None
exts = []
with open('/tmp/seti-security-policy.ini') as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('[') and line.endswith(']'):
            section = line[1:-1].strip()
            continue
        if section == 'archivos' and '=' not in line:
            exts.append(line)
print(' '.join(exts))
EOF
)

for file in $(git diff --cached --name-only); do
  for ext in $EXT_BLACKLIST; do
    if [[ "$file" == *"$ext" ]]; then
      echo ""
      echo "🚫 SETI SECURITY GUARD — ARCHIVO BLOQUEADO EN COMMIT"
      echo "   Archivo  : $file"
      echo "   Extensión: $ext"
      echo "   Contacto : seguridad@seti.com.co"
      echo ""
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] BLOCKED commit $file ($ext)" >> "$LOG_FILE"
      BLOCKED=true
    fi
  done
done

if [ "$BLOCKED" = true ]; then
  echo "❌ Commit bloqueado por política de seguridad SETI."
  exit 1
fi
HOOK

chmod +x /workspaces/hotel-poc-app/.git/hooks/pre-commit
echo -e "    ${GREEN}✅ pre-commit hook instalado${NC}"

# ── Resumen ───────────────────────────────────────────────────────────────────
echo -e "📋 [4/4] Política activa — $CLIENTE v$VERSION:"
echo -e "    npm bloqueados : ${RED}$NPM_BLACKLIST${NC}"
echo -e "    pip bloqueados : ${RED}$PIP_BLACKLIST${NC}"
echo -e "    URLs bloqueadas: ${RED}$URL_BLACKLIST${NC}"
echo -e "    Extensiones    : ${RED}$EXT_BLACKLIST${NC}"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   🛡️  SETI Security Guard activo en este entorno  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
