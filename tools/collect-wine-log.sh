#!/bin/sh
set -eu

: "${YMM4M_LOG_DIR:?Set YMM4M_LOG_DIR to an explicit evidence directory}"
mkdir -p "$YMM4M_LOG_DIR"
log_file="$YMM4M_LOG_DIR/wine-$(date -u +%Y%m%dT%H%M%SZ).log"
"$(dirname "$0")/run-ymm4.sh" "$@" 2>"$log_file"
echo "$log_file"

