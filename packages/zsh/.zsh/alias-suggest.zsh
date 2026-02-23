# Alias suggest: preexec hook that suggests shorter aliases for typed commands.
# Disable with: export ALIAS_SUGGEST_DISABLE=1

[[ -n "$ALIAS_SUGGEST_DISABLE" ]] && return

autoload -Uz add-zsh-hook

# Build lookup table: alias_value -> alias_name (shortest wins)
typeset -gA _alias_suggest_table

_alias_suggest_build() {
  _alias_suggest_table=()
  local name value
  while IFS= read -r line; do
    # alias -L outputs: alias name='value'
    name="${line#alias }"
    name="${name%%=*}"
    value="${line#*=\'}"
    value="${value%\'}"

    # Skip override aliases (value starts with the alias name, e.g. rm='rm -i')
    [[ "$value" == "$name" || "$value" == "$name "* ]] && continue
    # Skip dynamic aliases containing $(
    [[ "$value" == *'$('* ]] && continue

    # Shortest alias name wins
    local existing="${_alias_suggest_table[$value]}"
    if [[ -z "$existing" || ${#name} -lt ${#existing} ]]; then
      _alias_suggest_table[$value]="$name"
    fi
  done < <(alias -L)
}

_alias_suggest_build

# Preexec hook: suggest aliases for the typed command
_alias_suggest_preexec() {
  local typed="$1"
  [[ -n "$ALIAS_SUGGEST_DISABLE" ]] && return

  # Extract first command segment: stop at pipe, &&, ||, ;
  local -a words
  words=("${(z)typed}")
  local segment=""
  local word
  for word in "${words[@]}"; do
    case "$word" in
      '|'|'&&'|'||'|';') break ;;
      *) segment="${segment:+$segment }$word" ;;
    esac
  done
  [[ -z "$segment" ]] && return

  # Strip leading env assignments (FOO=bar cmd ...)
  local -a parts
  parts=("${(z)segment}")
  while (( ${#parts} )) && [[ "${parts[1]}" == *=* ]]; do
    shift parts
  done
  segment="${parts[*]}"
  [[ -z "$segment" ]] && return

  # Skip if typed text is already an alias name
  [[ -n "${aliases[$segment]}" ]] && return
  # Skip if first word is already an alias
  local first_word="${parts[1]}"
  [[ -n "${aliases[$first_word]}" ]] && return

  local exact_match="" super_match="" super_name="" prefix_match="" prefix_name="" prefix_extra=""

  # Tier 1: Exact match (O(1) hash lookup)
  exact_match="${_alias_suggest_table[$segment]}"

  # Tier 2: Superset -- alias value is a prefix of typed (longest match wins)
  # Tier 3: Prefix -- typed is a prefix of alias value (shortest name wins, 2+ words)
  local alias_val alias_nm
  for alias_val alias_nm in "${(@kv)_alias_suggest_table}"; do
    # Tier 2: alias value is prefix of typed, and typed has more after it
    if [[ -z "$exact_match" && "$segment" == "$alias_val "* ]]; then
      if [[ -z "$super_match" || ${#alias_val} -gt ${#super_match} ]]; then
        super_match="$alias_val"
        super_name="$alias_nm"
      fi
    fi
    # Tier 3: typed is prefix of alias value (require 2+ words in typed)
    if [[ "${#parts[@]}" -ge 2 && "$alias_val" == "$segment "* ]]; then
      if [[ -z "$prefix_name" || ${#alias_nm} -lt ${#prefix_name} ]]; then
        prefix_match="$alias_val"
        prefix_name="$alias_nm"
        prefix_extra="${alias_val#$segment }"
      fi
    fi
  done

  # Output suggestion
  if [[ -n "$exact_match" ]]; then
    print -P "%F{green}Alias: $exact_match%f"
  elif [[ -n "$super_name" && -n "$prefix_name" ]]; then
    # Cross-tier: pick shorter suggestion
    local super_suggestion="$super_name ${segment#$super_match }"
    if [[ ${#super_suggestion} -le ${#prefix_name} ]]; then
      print -P "%F{cyan}Alias: $super_suggestion%f"
    else
      print -P "%F{8}Also: $prefix_name (adds $prefix_extra)%f"
    fi
  elif [[ -n "$super_name" ]]; then
    local remainder="${segment#$super_match }"
    print -P "%F{cyan}Alias: $super_name $remainder%f"
  elif [[ -n "$prefix_name" ]]; then
    print -P "%F{8}Also: $prefix_name (adds $prefix_extra)%f"
  fi
}

add-zsh-hook preexec _alias_suggest_preexec
