#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function devdock_cli_main () {
  # Ensure the PATH variable is initialized properly:
  [ ! -f "$HOME"/.profile ] \
    || </dev/null source -- "$HOME"/.profile || return $?

  local COMPOSE_FILE='cache/composed.gen.yaml'
  export COMPOSE_FILE

  # Now with profile loaded, find the DevDock dir:
  local DD_DIR="$DEVDOCK_DIR"
  case "$DD_DIR" in
    '' ) DD_DIR="$HOME/.config/docker/devdock";;
    '~' | '~/'* ) DD_DIR="$HOME${DD_DIR:1}";;
  esac
  cd -- "$DD_DIR" || return $?

  local DD_PROJ="$(devdock_detect_project_name)"
  [ -n "$DD_PROJ" ] || DD_PROJ="devdock_p$$"
  export COMPOSE_PROJECT_NAME="$DD_PROJ"
  echo "D: project '$DD_PROJ' @ $DD_DIR"

  local TASK="$1"; shift
  local TASK_OPT=()
  case "$TASK" in
    '' ) TASK='up'; TASK_OPT=( --force-recreate );;
    bgup ) TASK='up'; TASK_OPT=( --force-recreate --detach );;
    recompose | \
    terminalize ) devdock_"$TASK" "$@"; return $?;;
    dddebug ) "$@"; return $?;;
  esac

  ps -C dockerd &>/dev/null || sudo service docker restart || return $?

  case "$TASK" in
    up )
      if [ -f "$COMPOSE_FILE" ]; then
        echo D: "before 'up', 'down' potential old container:"
        docompose down || return $?$(echo E: "docompose failed, rv=$?" >&2)
      fi
      devdock_recompose || return $?$(
        echo E: "Flinching: Failed to recompose." >&2)
      ;;
  esac

  echo "D: docompose $TASK ${TASK_OPT[*]} $*"
  docompose "$TASK" "${TASK_OPT[@]}" "$@"
  return $?
}


return 0
