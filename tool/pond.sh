#!/usr/bin/env sh

# Taken from sh bible
dirname() {
    dir=${1:-.}
    dir=${dir%%"${dir##*[!/]}"}
    [ "${dir##*/*}" ] && dir=.
    dir=${dir%/*}
    dir=${dir%%"${dir##*[!/]}"}
    printf '%s\n' "${dir:-/}"
}

_script_dir=$(dirname $0)

. $_script_dir/helpers.sh

# Simple Formatting System - Meant to be used with the toad ssg
# Requires GNU Coreutils

# Load backend
backend=$_script_dir/backend-${pond_backend:-web}.sh
_start=$(ms)
dbg "Pond v0"

# Check that files exists
if ! [ -f "$1" ]; then
	err "Invalid file given: '$1'"
	exit 1
fi

if ! [ -f "$backend" ]; then
	err "Invalid backend file: '$backend'"
	exit 1
fi

# Load backend
dbg "Using backend: \e[33m$backend\e[0m"
. $backend
transformers="$(grep -Po '.*(?=\(\))' $backend | tr '\n' ' ')" # POSIX ify
dbg "Available Transformers: $transformers"

# $1 = IN FILE
# $_out_f = OUT FILE
file=$(cat "$1")
in=$1

# Loop over lines
fn () {
_line_number=0
 while read -r line; do
	_line_number=$(( _line_number + 1 ))

	case "$line" in
		"#END "*)
			;;
		"#"*)
				# Detected Transformer!
				transformer=${line#\#}
				transformer=${transformer%% *}
				if ! contains "$transformers" "$(_normalize $transformer)"; then
					warn "Invalid Tranformer (DOES NOT EXIST IN BACKEND): $transformer @ $1:$_line_number"
					continue
				fi

				ending=$(grep_from "$_line_number" "$file" '-s -n -m1' "\#END $transformer")
				dbg "Found ending for: $_line_number:#$transformer at $ending"
				ending=${ending%%:*}
				ending=$(( _line_number + ending - 1 ))
				if [ -z "$ending" ]; then
					warn "Invalid Transfomer (DOES NOT HAVE AN END): $transformer @ $1:$_line_number"
					continue
				fi
				
				original_contents=$(get_between "$file" $((_line_number)) $((ending)) )
				new_contents=$($(_normalize $transformer) "$(strip_head_and_tail "$original_contents")" ) # add args support
				#printf "\n---\n$(strip_head_and_tail "$original_contents")\n---\n$new_contents\n---\n"
				new_file_contents=$(echo "$file" | $_script_dir/reeplace "$original_contents" "$new_contents")
				
				# This check fixes stuff.. idk why
				if [ -n "$new_file_contents" ]; then
					file="$new_file_contents"
				fi

				fn 
				break
			;;
	esac
done <<< "$file"
}

fn
echo "$file"

_end=$(ms)
dbg "Finished in $(( end - start ))ms"
