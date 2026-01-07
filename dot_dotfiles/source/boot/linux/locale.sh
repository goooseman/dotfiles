available_locales=""
if command -v locale >/dev/null 2>&1; then
  available_locales=$(locale -a 2>/dev/null || true)
fi

current_locale="${LC_ALL:-${LANG:-}}"
if [[ -n "$current_locale" && -n "$available_locales" ]]; then
  if printf '%s\n' "$available_locales" | grep -Fxq "$current_locale"; then
    export LC_ALL="$current_locale"
    export LANG="${LANG:-$current_locale}"
  else
    if [[ "${LC_ALL:-}" == "$current_locale" ]]; then
      unset LC_ALL
    fi
    if [[ "${LANG:-}" == "$current_locale" ]]; then
      unset LANG
    fi
    unset current_locale
  fi
fi

if [[ -z "${LC_ALL:-}" ]]; then
  preferred_locales=(
    en_US.UTF-8
    en_US.utf8
    C.UTF-8
    C.utf8
  )

  if [[ -n "$available_locales" ]]; then
    for preferred_locale in "${preferred_locales[@]}"; do
      if printf '%s\n' "$available_locales" | grep -Fxq "$preferred_locale"; then
        export LC_ALL="$preferred_locale"
        export LANG="$preferred_locale"
        break
      fi
    done
  fi
fi

if [[ -z "${LC_ALL:-}" ]]; then
  export LC_ALL=C
fi

if [[ -z "${LANG:-}" ]]; then
  export LANG="$LC_ALL"
fi

unset available_locales current_locale preferred_locale preferred_locales
