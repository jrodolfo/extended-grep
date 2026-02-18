#!/usr/bin/env bash

set -euo pipefail

if [ "$(uname -s)" != "Linux" ]; then
  echo "Error: tests/smoke.tests.linux.sh must be run on Linux." >&2
  exit 1
fi

bash "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/smoke.tests.sh"
