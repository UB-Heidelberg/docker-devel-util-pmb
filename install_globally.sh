#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function install_globally () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local REPO_DIR="$(readlink -m -- "$BASH_SOURCE"/..)"
  cd -- "$REPO_DIR" || return $?
  local QUOT='"' # help buggy syntax highlighters that end strings at EOL
  local PKG_NAME='"name":\s*"[\w\-]+(?=")'
  PKG_NAME="$(LANG=C grep -m 1 -oPe "$PKG_NAME" -- package.json |
    head --lines=1 | # grep -m only limits lines matched, not total matches
    cut -d "$QUOT" -sf 4)"
  [ -n "$PKG_NAME" ] || return 4$(echo E: 'Cannot find package name!' >&2)

  if [ "$1" == --skip-mv ]; then
    shift
  else
    echo "Taking ownership:"
    chown --recursive root:root . || return $?

    local ULD="/usr/local/lib/$PKG_NAME"
    echo -n "Move repo directory to $ULD: "
    if [ "$REPO_DIR" -ef "$ULD" ]; then
      echo 'skip: no action required.'
    else
      mv --no-target-directory -- "$REPO_DIR" "$ULD" || return $?
      echo 'done.'
    fi

    echo
    cd -- "$ULD" || return $?
  fi

  echo "Installing global CLI commands:"
  local LINK= DEST=
  while IFS= read -rs DEST; do
    case "$DEST" in
      [a-z]*' <- '[a-z]*.sh ) LINK="${DEST%% <- *}"; DEST="${DEST#* <- }";;
      * ) continue;;
    esac
    echo -n '    '
    LINK="/usr/local/bin/$LINK"
    [ ! -L "$LINK" ] || rm -- "$LINK"
    ln --verbose --symbolic --relative --no-target-directory \
      -- "$DEST" "$LINK" || return $?
  done <binlinks.cfg

  echo
  echo "Ok! Seems like all is well and $PKG_NAME should be ready for use."
}










install_globally "$@"; exit $?
