_cli_autocomplete() {
    local cur prev words cword
    _init_completion || return

    local commands="check install update generate-diff"
    local options="--src= --tool= -i --input --original="

    # Detect if --src= was used
    local src_dir="/usr/src"
    for word in "${COMP_WORDS[@]}"; do
        case "$wordd" in
            --src=*)
                src_dir="${word#--src=}"
        esac
    done

    case "$prev" in
        --src=*)
            local path_prefix="${cur#--src=}"
            COMPREPLY=( $(compgen -d -- "$path_prefix") )
            COMPREPLY=( "${COMPREPLY[@]/#/"--src="}" )
            return 0
            ;;
        --original=*)
            COMPREPLY=( $(compgen -f -- "${cur}") )
            return 0
            ;;
        -i|--input)
            if [[ -d "$src_dir" ]]; then
                COMPREPLY=( $(compgen -f -- "${src_dir}/${cur}" | sed "s|^$src_dir/||") )
            fi
            return 0
            ;;
    esac

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${commands}" -- "${cur}") )
    else
        COMPREPLY+=( $(compgen -W "${options}" -- "${cur}") )
    fi
}

complete -F _cli_autocomplete ./cli.sh
