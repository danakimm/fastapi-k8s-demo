#!/usr/bin/env bash
set -euo pipefail

cd app

poetry sync --with dev
poetry run ruff check .
poetry run pytest -v
