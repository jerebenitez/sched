#!/bin/bash

set -e
source ./cli-completion.sh

SRC_DIR="/usr/src"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_usage() {
    echo "Usage: $0 [--src=<path>] <command> [options]"
    echo ""
    echo "Commands:"
    echo "  check|c             Test if patch applies cleanly over current files"
    echo "  install|i           Copy files and apply patches"
    echo "  generate-diff|gd    Generate diff from source tree into patches/ and copy original files"
    echo "  update|u            Update one or more patches"
    echo ""
    echo "Options:"
    echo "  --src=<path>        Path to the FreeBSD source tree (default: /usr/src)"
}

print_generate_diff_usage() {
    echo ""
    echo "Usage: $0 [--src=<path>] gd -i <file> [--original=<path>]"
    echo ""
    echo "Description:"
    echo "  Generate a patch for a modified file in the source tree."
    echo "  - If the file exists in Git, the original version is taken from HEAD."
    echo "  - If Git is not available, you must provide the original version manually."
    echo ""
    echo "Options:"
    echo "  -i, --input <file>           Relative path to the file inside the source tree (e.g. sys/kern/kern_exec.c)"
    echo "      --original=<path>        Path to the original (unmodified) file. Required if the source tree is not a Git repo."
    echo "      --src=<path>             Path to the FreeBSD source tree (default: /usr/src)"
    echo ""
    echo "Examples:"
    echo "  $0 --src=/usr/src gd -i sys/kern/kern_exec.c"
    echo "  $0 gd -i sys/kern/kern_exec.c --original=/home/user/kern_exec_orig.c"
    echo ""
}

print_update_usage() {
    echo ""
    echo "Usage: $0 update --src=<path> -i <file> [-i <file2> ...] [--tool=<merge_tool>] [--all]"
    echo ""
    echo "Description:"
    echo "  Updates one or more patches when the corresponding source files in the kernel have changed."
    echo "  Reconstructs your modified version using orig/ + patch, then performs a 3-way merge"
    echo "  with the updated file in the source tree. The result is used to regenerate the patch."
    echo ""
    echo "Options:"
    echo "  -i, --input <file>        Relative path to a file in the source tree"
    echo "  -a, --all                 Update all files in patches/"
    echo "      --tool=<tool>         Merge tool to use (default: diff3). Supported: diff3, vimdiff, meld"
    echo "      --src=<path>          Path to the FreeBSD source tree (default: /usr/src)"
    echo ""
    echo "Examples:"
    echo "  $0 update --src=/usr/src -i sys/kern/foo.c"
    echo "  $0 update -i sys/kern/foo.c -i sys/conf/options.amd64 --tool=vimdiff"
    echo ""
}

parse_global_opts() {
    for arg in "$@"; do
        case $arg in
            --src=*)
                SRC_DIR="${arg#*=}"
                shift
                ;;
        esac
    done
}

rel_paths() {
    find orig -type f | sed 's|^orig/||'
}

update_patch_for_file() {
    local file="$1"
    local merge_tool="${2:-diff3}"  # default: diff3

    local orig_file="orig/$file"
    local upstream_file="$SRC_DIR/$file"
    local patch_file="patches/$file.patch"
    local reconstructed_my_version
    local merged_tmp
    local old_patch_tmp new_patch_tmp

    if [[ ! -f "$orig_file" ]]; then
        echo -e "${RED}Missing orig/$file${NC}"
        return 1
    fi
    if [[ ! -f "$patch_file" ]]; then
        echo -e "${RED}Missing patches/$file.patch${NC}"
        return 1
    fi
    if [[ ! -f "$upstream_file" ]]; then
        echo -e "${RED}Missing $SRC_DIR/$file${NC}"
        return 1
    fi

    echo "Reconstructing modified version of $file..."
    reconstructed_my_version=$(mktemp)
    cp "$orig_file" "$reconstructed_my_version"
    if ! patch --silent "$reconstructed_my_version" < "$patch_file"; then
        echo -e "${RED}Failed to apply patch to orig/$file — cannot reconstruct${NC}"
        rm -f "$reconstructed_my_version"
        return 1
    fi

    echo "Performing 3-way merge with tool: $merge_tool"
    merged_tmp=$(mktemp)

    case "$merge_tool" in
        diff3)
            if ! diff3 -m "$reconstructed_my_version" "$orig_file" "$upstream_file" > "$merged_tmp"; then
                echo -e "${YELLOW}Merge conflict detected — please resolve manually${NC}"
                rm -f "$reconstructed_my_version" "$merged_tmp"
                return 1
            fi
            ;;
        vimdiff|meld|kdiff3)
            echo "Opening visual merge tool: $merge_tool"
            $merge_tool "$reconstructed_my_version" "$orig_file" "$upstream_file"
            echo "Merge tool exited — please verify changes and regenerate patch if needed."
            rm -f "$reconstructed_my_version"
            return 0
            ;;
        *)
            echo -e "${RED}Unsupported merge tool: $merge_tool${NC}"
            rm -f "$reconstructed_my_version"
            return 1
            ;;
    esac

    echo "Updating orig/$file with upstream version"
    cp "$upstream_file" "$orig_file"

    echo "Regenerating patch..."
    mkdir -p "$(dirname "$patch_file")"

    old_patch_tmp=$(mktemp)
    cp "$patch_file" "$old_patch_tmp"
    diff -u "$orig_file" "$reconstructed_my_version" > "$patch_file" || true
    new_patch_tmp=$(mktemp)
    cp "$patch_file" "$new_patch_tmp"

    if diff -q "$old_patch_tmp" "$new_patch_tmp" &>/dev/null; then
        echo "No changes detected in patch ($file.patch remains the same)"
    else
        echo -e "${GREEN}Patch updated: $patch_file${NC}"
    fi

    rm -f "$reconstructed_my_version" "$merged_tmp" "$old_patch_tmp" "$new_patch_tmp"
}

command_check() {
    echo "Running check on patches and file existence..."
    local failed=0
    for file in $(rel_paths); do
        src_file="$SRC_DIR/$file"
        orig_file="orig/$file"

        # 1. Verify existence
        if [[ -f "$src_file" ]]; then
            printf "%b%s exists in source tree%b: " "$GREEN" "$file" "$NC"
            
            # 2. Verify if something changed
            if [[ -f "$orig_file" ]]; then
                if ! diff -q "$orig_file" "$src_file" &> /dev/null; then
                    printf "%b[CHANGED]%b\n" "$YELLOW" "$NC"
                else
                    printf "%b[NOT CHANGED]%b\n" "$GREEN" "$NC"
                fi
            else
                echo -e "${YELLOW}No orig/ version for $file. Can't compare.${NC}"
            fi

        else
            echo -e "${RED}$file missing in source tree${NC}"
            : $(( failed += 1 ))
        fi

    done

    echo "Testing patch application..."
    while read -r patch_path; do
        rel_file="${patch_path#patches/}"
        rel_file="${rel_file%.patch}"

        target_file="$SRC_DIR/$rel_file"

        if [[ ! -f "$target_file" ]]; then
            echo -e "${YELLOW}Skipping $rel_file: does not exist in source tree${NC}"
            : $(( failed += 1 ))
            continue
        fi

        if patch --dry-run -p1 --strip=0 "$target_file" < "$patch_path" &> /dev/null; then
            echo -e "${GREEN}Patch $patch_path applies cleanly${NC}"
        else
            echo -e "${RED}Patch $patch_path FAILED to apply${NC}"
            : $(( failed += 1 ))
        fi
    done < <(find patches -type f -name "*.patch")

    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}All checks passed${NC}"
    else
        echo -e "${RED}${failed} checks failed${NC}"
        exit 1
    fi
}

command_install() {
    echo "Installing files to $SRC_DIR..."
    find src -type f | while read -r file_path; do
        rel_file="${file_path#src/}"
        dest="$SRC_DIR/$rel_file"
        echo "  → Copying $rel_file"
        mkdir -p "$(dirname "$dest")"
        cp "src/$rel_file" "$dest"
    done

    echo "Applying patches..."
    find patches -type f -name "*.patch" | while read -r patch_path; do
        rel_file="${patch_path#patches/}"
        rel_file="${rel_file%.patch}"

        target_file="$SRC_DIR/$rel_file"

        echo "  → Applying $patch_path"
        patch -p1 --strip=0 "$target_file" < "$patch_path" &> /dev/null
    done

    echo -e "${GREEN}Installation complete.${NC}"
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
                print_generate_diff_usage
                exit 1
                ;;
        esac
        shift
    done

    if [[ -z "$input_file" ]]; then
        echo -e "${RED}You must specify a file with -i path/to/file${NC}"
        print_generate_diff_usage
        return 1
    fi

    local src_path="$SRC_DIR/$input_file"
    local orig_path="orig/$input_file"
    local patch_path="patches/$input_file.patch"

    mkdir -p "$(dirname "$orig_path")" "$(dirname "$patch_path")"

    echo "Generating diff for: $input_file"

    if [[ -n "$orig_override" ]]; then
        # No Git — use provided original file
        echo "- Using user-provided original: $orig_override"
        cp "$orig_override" "$orig_path"
    elif git -C "$SRC_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
        # In Git repo — use HEAD version
        echo "- Using Git version from HEAD"
        if git -C "$SRC_DIR" cat-file -e "HEAD:$input_file" 2>/dev/null; then
            git -C "$SRC_DIR" show "HEAD:$input_file" > "$orig_path"
        else
            echo -e "${YELLOW}File $input_file is new (not in HEAD)${NC}"
            echo "" > "$orig_path"
        fi
    else
        echo -e "${RED}Not a Git repo, please provide a reference to the original file with --original${NC}"
        return 1
    fi

    # Generate the patch
    if [[ -f "$src_path" ]]; then
        diff -u "$orig_path" "$src_path" > "$patch_path" || true
        echo -e "${GREEN}Patch written to $patch_path${NC}"
    else
        echo -e "${RED}Cannot find $src_path in source tree${NC}"
        return 1
    fi
}

command_update() {
    local input_files=()
    local merge_tool="diff3"
    local all="false"

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--input)
                shift
                input_files+=("$1")
                ;;
            --tool=*)
                merge_tool="${1#*=}"
                ;;
            --tool)
                shift
                merge_tool="$1"
                ;;
            --all)
                all="true"
                ;;
            -h|--help)
                print_update_usage
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                print_update_usage
                return 1
                ;;
        esac
        shift
    done

    if [[ $all == "true" ]]; then
        while read -r patch_path; do
            rel_file="${patch_path#patches/}"
            rel_file="${rel_file%.patch}"

            echo "Refreshing patch for: $rel_file"
            update_patch_for_file "$rel_file" "$merge_tool"
        done < <(find patches -type f -name "*.patch")
    else
        if [[ ${#input_files[@]} -eq 0 ]]; then
            echo "At least one -i or --input must be provided."
            print_update_usage
            return 1
        fi

        for file in "${input_files[@]}"; do
            echo "Refreshing patch for: $file"
            update_patch_for_file "$file" "$merge_tool"
        done
    fi
}

### Entry Point
parse_global_opts "$@"
while [[ "$1" == --* ]]; do shift; done

CMD="$1"; shift || true

case "$CMD" in
    check|c)           command_check "$@";;
    install|i)         command_install "$@";;
    generate-diff|gd)  command_generate_diff "$@";;
    update|u)          command_update "$@";;
    *)                 print_usage; exit 1;;
esac
