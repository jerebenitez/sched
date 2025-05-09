#!/bin/bash

set -e

SRC_DIR="/usr/src"
TOOL="diff3"

print_usage() {
    echo "Usage: $0 [--src=<path>] <command> [options]"
    echo ""
    echo "Commands:"
    echo "  check|c             Test if patch applies cleanly over current files"
    echo "  install|i           Copy files and apply patches"
    echo "  generate-diff|gd    Generate diff from orig/ and src/ into patches/"
    echo ""
    echo "Options:"
    echo "  --src=<path>        Path to the FreeBSD source tree (default: /usr/src)"
}

parse_global_opts() {
    for arg in "$@"; do
        case $arg in
            --src=*)
                SRC_DIR="${arg#*=}"
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
        esac
    done
}

rel_paths() {
    find orig -type f | sed 's|^orig/||'
}

command_check() {
    echo $SRC_DIR
    echo "🔍 Running check on patches and file existence..."
    local failed=0
    for file in $(rel_paths); do
        if [[ -f "$SRC_DIR/$file" ]]; then
            echo "[✔] $file exists in source tree"
        else
            echo "[✘] $file missing in source tree"
            failed=1
        fi
    done

    echo "🧪 Testing patch application..."
    find patches -type f -name "*.patch" | while read -r patch_path; do
        rel_file="${patch_path#patches/}"
        rel_file="${rel_file%.patch}"

        target_file="$SRC_DIR/$rel_file"

        if [[ ! -f "$target_file" ]]; then
            echo "[!] Skipping $rel_file: does not exist in source tree"
            failed=1
            continue
        fi

        echo "  → Applying patch to $rel_file"
        if patch --dry-run -p1 --strip=0 "$target_file" < "$patch_path" &> /dev/null; then
            echo "[✔] Patch $patch applies cleanly"
        else
            echo "[✘] Patch $patch FAILED to apply"
            failed=1
        fi
    done

    if [[ $failed -eq 0 ]]; then
        echo "✅ All checks passed"
    else
        echo "❌ Some checks failed"
        exit 1
    fi
}

command_install() {
    echo "📁 Installing files to $SRC_DIR..."
    for file in $(rel_paths); do
        echo "  → Copying $file"
        cp "src/$file" "$SRC_DIR/$file"
    done

    echo "📦 Applying patches..."
    for patch in patches/*.patch; do
        echo "  → Applying $patch"
        patch -p1 -d "$SRC_DIR" < "$patch"
    done

    echo "✅ Installation complete."
}

command_generate_diff() {
    local input_file=""
    local orig_override=""

    # Parse command-specific options
    while [[ "$1" != "" ]]; do
        case "$1" in
            -i|--input)
                shift
                input_file="$1"
                ;;
            --input=*)
                input_file="${1#*=}"
                ;;
            --original)
                shift
                orig_override="$1"
                ;;
            --original=*)
                orig_override="${1#*=}"
                ;;
            *)
                echo "[!] Unknown option for generate-diff: $1"
                exit 1
                ;;
        esac
        shift
    done

    if [[ -z "$input_file" ]]; then
        echo "[!] You must specify a file with -i path/to/file"
        return 1
    fi

    local src_path="$SRC_DIR/$input_file"
    local orig_path="orig/$input_file"
    local patch_path="patches/$input_file.patch"

    mkdir -p "$(dirname "$orig_path")" "$(dirname "$patch_path")"

    echo "📄 Generating diff for: $input_file"

    if [[ -n "$orig_override" ]]; then
        # No Git — use provided original file
        echo "🔹 Using user-provided original: $orig_override"
        cp "$orig_override" "$orig_path"
    elif git -C "$SRC_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
        # In Git repo — use HEAD version
        echo "🔹 Using Git version from HEAD"
        if git -C "$SRC_DIR" cat-file -e "HEAD:$input_file" 2>/dev/null; then
            git -C "$SRC_DIR" show "HEAD:$input_file" > "$orig_path"
        else
            echo "⚠️  File $input_file is new (not in HEAD)"
            echo "" > "$orig_path"
        fi
    else
        echo "[!] Not a Git repo, please provide a reference to the original file with --original"
        return 1
    fi

    # Generate the patch
    if [[ -f "$src_path" ]]; then
        diff -u "$orig_path" "$src_path" > "$patch_path" || true
        echo "✅ Patch written to $patch_path"
    else
        echo "[!] Cannot find $src_path in source tree"
        return 1
    fi
}

### Entry Point

# Extract global options
parse_global_opts "$@"

# Shift global options
while [[ "$1" == --* ]]; do shift; done

CMD="$1"; shift || true

case "$CMD" in
    check|c)           command_check "$@";;
    install|i)         command_install "$@";;
    generate-diff|gd)  command_generate_diff "$@";;
    *)                 print_usage; exit 1;;
esac
