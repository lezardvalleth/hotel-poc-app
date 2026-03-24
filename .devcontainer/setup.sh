#!/bin/bash
set -e

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   SETI — Configurando ambiente de desarrollo  ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# 1. Variables de entorno
echo "⚙️  [1/4] Configurando variables de entorno..."
if [ ! -f .env ]; then
  echo 'DATABASE_URL=postgresql://postgres:postgres@localhost:5432/hoteldb' > .env
  echo 'PORT=3000' >> .env
  echo 'NODE_ENV=development' >> .env
fi
echo "    ✅ .env listo"

# 2. Dependencias
echo "📦 [2/4] Instalando dependencias npm..."
npm install --silent
echo "    ✅ $(npm list --depth=0 2>/dev/null | tail -n +2 | wc -l) paquetes instalados"

# 3. Prisma (solo si existe schema)
echo "🗄️  [3/4] Configurando Prisma..."
if [ -f prisma/schema.prisma ]; then
  npx prisma generate
  echo "    ✅ Prisma client generado"
else
  echo "    ⏭️  Sin schema.prisma — skipping (agrégalo cuando estés listo)"
fi

# 4. Smoke test
echo "🧪 [4/4] Ejecutando smoke test..."
PASS=true

# Node version
NODE_VER=$(node --version)
echo "    Node.js : $NODE_VER"

# PostgreSQL
if psql postgresql://postgres:postgres@localhost:5432/postgres -c "SELECT 1" > /dev/null 2>&1; then
  echo "    PostgreSQL : ✅ conectado"
else
  echo "    PostgreSQL : ⚠️  no disponible aún (puede tardar unos segundos)"
  PASS=false
fi

# Express disponible
if [ -d node_modules/express ]; then
  echo "    Express : ✅ disponible"
else
  echo "    Express : ❌ no encontrado"
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
