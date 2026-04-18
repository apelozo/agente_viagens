#!/usr/bin/env bash
# Build Flutter Web no Render (Static Site). Requer variável API_BASE_URL (URL https do backend).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export GIT_TERMINAL_PROMPT=0
FLUTTER_DIR="${HOME}/flutter_stable"
if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  rm -rf "${FLUTTER_DIR}"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "${FLUTTER_DIR}"
fi
export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter config --no-analytics
flutter precache --web
flutter pub get

if [ -z "${API_BASE_URL:-}" ]; then
  echo "Erro: defina API_BASE_URL no painel do Static Site (ex.: https://seu-backend.onrender.com)" >&2
  exit 1
fi

flutter build web --release --dart-define="API_BASE_URL=${API_BASE_URL}"
