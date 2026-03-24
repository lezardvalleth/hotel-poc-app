#!/bin/bash
set -e

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   SETI — Configurando ambiente de desarrollo  ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

echo "⚙️  [1/5] Configurando variables de entorno..."
if [ ! -f .env ]; then
  echo 'DATABASE_URL=postgresql://postgres:postgres@localhost:5432/hoteldb' > .env
  echo 'PORT=3000' >> .env
  echo 'NODE_ENV=development' >> .env
fi
echo "    ✅ .env listo"

echo "📦 [2/5] Instalando dependencias npm..."
npm install --silent
echo "    ✅ $(npm list --depth=0 2>/dev/null | tail -n +2 | wc -l) paquetes instalados"

echo "🗄️  [3/5] Configurando Prisma..."
if [ -f prisma/schema.prisma ]; then
  npx prisma generate
  echo "    ✅ Prisma client generado"
else
  echo "    ⏭️  Sin schema.prisma — skipping"
fi

echo "🛡️  [4/5] Aplicando políticas de seguridad SETI..."
bash .devcontainer/security-guard.sh

echo "🧪 [5/5] Ejecutando smoke test..."
PASS=true
NODE_VER=$(node --version)
echo "    Node.js    : $NODE_VER"
if psql postgresql://postgres:postgres@localhost:5432/postgres -c "SELECT 1" > /dev/null 2>&1; then
  echo "    PostgreSQL : ✅ conectado"
else
  echo "    PostgreSQL : ⚠️  no disponible aún"
  PASS=false
fi
if [ -d node_modules/express ]; then
  echo "    Express    : ✅ disponible"
else
  echo "    Express    : ❌ no encontrado"
  PASS=false
fi

echo ""
if [ "$PASS" = true ]; then
  echo "╔══════════════════════════════════════════════╗"
  echo "║   ✅ AMBIENTE LISTO — Happy coding!           ║"
  echo "╚══════════════════════════════════════════════╝"
else
  echo "╔══════════════════════════════════════════════╗"
  echo "║   ⚠️  AMBIENTE LISTO CON ADVERTENCIAS         ║"
  echo "╚══════════════════════════════════════════════╝"
fi
echo ""
