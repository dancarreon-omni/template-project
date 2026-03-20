#!/bin/bash
# bump-version.sh
# Uso: ./bump-version.sh <major|minor|patch>
#
# Lee la versión del archivo VERSION (archivo de texto plano agnóstico
# al lenguaje), incrementa la parte indicada y escribe el resultado.
#
# El archivo VERSION debe estar en la raíz del repositorio y contener
# únicamente el número de versión en formato MAJOR.MINOR.PATCH, por ejemplo:
#   1.4.2
#
# Este script no depende de ningún lenguaje ni gestor de paquetes.
# Es compatible con proyectos Node.js, Python, PHP, Java, .NET, etc.

set -euo pipefail

TIPO_BUMP="${1:-patch}"

# ---------------------------------------------------------------------------
# 1. Leer la versión desde el archivo VERSION
# ---------------------------------------------------------------------------
if [ ! -f "VERSION" ]; then
  echo "Archivo VERSION no encontrado. Creando con versión inicial 0.0.0"
  echo "0.0.0" > VERSION
fi

ACTUAL=$(cat VERSION | tr -d '[:space:]')

if [ -z "$ACTUAL" ]; then
  echo "El archivo VERSION está vacío. Inicializando con 0.0.0"
  echo "0.0.0" > VERSION
  ACTUAL="0.0.0"
fi

echo "Versión actual: $ACTUAL"

# ---------------------------------------------------------------------------
# 2. Validar formato MAJOR.MINOR.PATCH
# ---------------------------------------------------------------------------
if ! echo "$ACTUAL" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "❌ El archivo VERSION contiene un valor inválido: '$ACTUAL'"
  echo "   El formato esperado es MAJOR.MINOR.PATCH (ej: 1.4.2)"
  exit 1
fi

# ---------------------------------------------------------------------------
# 3. Separar en partes
# ---------------------------------------------------------------------------
IFS='.' read -r MAJOR MINOR PATCH <<< "$ACTUAL"

# ---------------------------------------------------------------------------
# 4. Incrementar la parte correcta
# ---------------------------------------------------------------------------
case "$TIPO_BUMP" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  *)
    echo "❌ Tipo de incremento desconocido: '$TIPO_BUMP'"
    echo "   Valores válidos: major | minor | patch"
    exit 1
    ;;
esac

NUEVA_VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo "Nueva versión:  $NUEVA_VERSION"

# ---------------------------------------------------------------------------
# 5. Escribir la nueva versión en el archivo VERSION
# ---------------------------------------------------------------------------
echo "$NUEVA_VERSION" > VERSION
echo "✅ Archivo VERSION actualizado: $ACTUAL → $NUEVA_VERSION"

# ---------------------------------------------------------------------------
# 6. Exportar para GitHub Actions
# ---------------------------------------------------------------------------
echo "NUEVA_VERSION=${NUEVA_VERSION}" >> "$GITHUB_ENV"
echo "nueva_version=${NUEVA_VERSION}" >> "$GITHUB_OUTPUT"
