#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}

show_usage() {
	print -u2 "Usage: ${0:t} [--fix]"
	exit 2
}

run_lint() {
	local mode="$1"
	cd "$project_dir"

	if [[ "$mode" == --fix ]]; then
		swift package plugin --allow-writing-to-package-directory swiftlint lint --fix
	fi
	swift package plugin --allow-writing-to-package-directory swiftlint lint --strict
}

case "${1:-}" in
"" | --fix)
	[[ $# -le 1 ]] || show_usage
	run_lint "${1:-}"
	;;
*)
	show_usage
	;;
esac
