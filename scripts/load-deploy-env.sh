#!/bin/bash
# shellcheck shell=bash
#
# Shared loader for non-tracked deployment environment files.
# Source this file from other bash scripts or Make targets.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

FLOWGROOVE_ENV_FILE="${FLOWGROOVE_ENV_FILE:-$PROJECT_ROOT/.env}"
FLOWGROOVE_FTP_ENV_FILE="${FLOWGROOVE_FTP_ENV_FILE:-$PROJECT_ROOT/.ftp-env}"

declare -a FLOWGROOVE_LOADED_ENV_FILES=()

flowgroove_source_env_file() {
    local env_file="$1"

    if [ -f "$env_file" ]; then
        set -a
        # shellcheck disable=SC1090
        . "$env_file"
        set +a
        FLOWGROOVE_LOADED_ENV_FILES+=("$env_file")
    fi
}

flowgroove_is_placeholder_value() {
    case "${1:-}" in
        ""|REPLACE_ME*|YOUR_*|your_*|CHANGE_ME*|changeme|example|EXAMPLE|"<"*">")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

flowgroove_require_vars() {
    local missing=()
    local var
    local value

    for var in "$@"; do
        value="${!var:-}"
        if flowgroove_is_placeholder_value "$value"; then
            missing+=("$var")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        echo "❌ ERROR: Missing required deployment variables:" >&2
        for var in "${missing[@]}"; do
            echo "   - $var" >&2
        done
        return 1
    fi
}

flowgroove_print_loaded_sources() {
    if [ "${#FLOWGROOVE_LOADED_ENV_FILES[@]}" -eq 0 ]; then
        echo "ℹ️  No local env files loaded; using exported shell variables only"
        return
    fi

    echo "📄 Loaded env sources:"
    local env_file
    for env_file in "${FLOWGROOVE_LOADED_ENV_FILES[@]}"; do
        echo "   - $env_file"
    done
}

flowgroove_source_env_file "$FLOWGROOVE_ENV_FILE"
flowgroove_source_env_file "$FLOWGROOVE_FTP_ENV_FILE"

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    flowgroove_print_loaded_sources
fi
