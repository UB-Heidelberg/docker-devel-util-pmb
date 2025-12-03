#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function devdock_recompose__cleanup_and_lint_doco_section () {
  local SECT_TRACE="$1"; shift
  local CLEANUP='
    s~\s+$~~
    '
  local TEXT="$(sed -rf <(echo "$CLEANUP"))"

  while [[ "$TEXT" == $'\n'* ]]; do TEXT="${TEXT#$'\n'}"; done
  while [[ "$TEXT" == *$'\n' ]]; do TEXT="${TEXT%$'\n'}"; done

  local LINT="$(devdock_lint_sect "$CUR_SECT" <<<"$TEXT")"
  [ -z "$LINT" ] || return 5$(
    echo "E: Found lint in section $SECT_TRACE:" >&2
    echo "$LINT" >&2)

  echo "  # >>> $SECT_TRACE >>> templated parts >>>"
  echo "$TEXT"
  echo "  # >>> $SECT_TRACE >>> generic additions by DevDock >>>"

  if ! grep -qPe '^\s+logging:\s*(#|$)' <(echo "$TEXT"); then
    echo "    logging:"
    echo "      driver: 'local'" \
      '# `local` has safer default options than `json-file`,' \
      'but consider configuring values tailored to your use case!'
  fi

  echo "  # <<< $SECT_TRACE <<<"
}


return 0
