#!/usr/bin/env bash
# Analyze and test every package in the monorepo.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
(cd packages/howl_core && dart analyze && dart test)
(cd packages/howl_net && dart analyze && dart test)
(cd apps/mobile && flutter analyze && flutter test)
