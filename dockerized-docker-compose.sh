#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function do_in_func () { "$@"; }


function dockerized_docker_compose () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local DBGLV="${DEBUGLEVEL:-0}"
  local APP_NAME="${FUNCNAME//_/-}"
  local SOK='/var/run/docker.sock'
  [ -w "$SOK" ] || return 4$(
    echo "E: No write access to $SOK – is user '$USER' in group docker?" >&2)

  local D_PRE_TASK_OPT=()
  while true; do case "$1" in
    --profile | \
    ___pre_task_1_arg___ )
      D_PRE_TASK_OPT+=( "$1" "$2" )
      shift; shift;; # `shift 2` would fail if we only have 1 arg.
    * ) break;;
  esac; done
  local D_TASK="$1"; shift
  local D_EARLY_OPT=()
  local STERN_WARNINGS=

  local COMPOSE_FILE="$COMPOSE_FILE"
  [ -n "$COMPOSE_FILE" ] || case "$D_TASK" in
    version | --version ) COMPOSE_FILE='/dev/null';;
  esac
  [ -n "$COMPOSE_FILE" ] || for COMPOSE_FILE in docker-compose.y{a,}ml ''; do
    [ -f "$COMPOSE_FILE" ] && break
  done

  local -A CFG=(
    [inside_prefix]="$COMPOSE_INSIDE_PREFIX"
    [project_name]="$COMPOSE_PROJECT_NAME"
    )
  doco_advise_on_compose_file_version || return $?
  local PROXY_OPT=()
  doco_gen_proxy_opt || return $?

  local ITEM=
  for ITEM in "$FUNCNAME".rc; do
    [ -f "$ITEM" ] || continue
    do_in_func source -- "$ITEM" --rc || return $?$(
      echo "E: $FUNCNAME: Failed to source $ITEM" >&2)
  done

  [ -n "${CFG[project_name]}" ] || CFG[project_name]="$(basename -- "$PWD")"
  [ -n "${CFG[inside_prefix]}" ] \
    || CFG[inside_prefix]="/code/${CFG[project_name]}"

  local TTY_OPT=()
  tty --silent && TTY_OPT+=( --interactive --tty )

  case "$D_TASK" in
    build | \
    rebuild | \
    rebup | \
    up ) CFG[pre-task:down]="$D_TASK";;
  esac

  case "$D_TASK" in
    rebuild ) CFG[pre-task:rebuild]=+; D_TASK='SKIP';;
    rebup )   CFG[pre-task:rebuild]=+; D_TASK='up';;
  esac

  case "$D_TASK" in
    lint-config )
      D_TASK='config'
      COMPOSE_FILE="${1:-$COMPOSE_FILE}"; shift
      ;;

    build )
      doco_build_maybe_add_proxy_build_args || return $?
      ;;

    run )
      D_EARLY_OPT+=( "${PROXY_OPT[@]}" )
      ;;
  esac

  local OUTER_RUN=(
    docker
    run
    --volume="$SOK:$SOK:rw"
    --volume="${PWD:-/proc/E/err_no_pwd}:${CFG[inside_prefix]}:rw"
    --env COMPOSE_PROJECT_NAME="${CFG[project_name]}"
    "${PROXY_OPT[@]}"
    "${TTY_OPT[@]}"
    --rm
    --name "${CFG[project_name]}_compose_$$"
    --workdir "${CFG[inside_prefix]}"
    )
  doco_cfg_compo_file__insert_inside_prefix || return $?
  OUTER_RUN+=(
    docker/compose:latest
    )

  doco_fallible_actually_do_stuff "$@"; local D_RV=$?

  [ -z "$STERN_WARNINGS" ] || echo "W: $APP_NAME:" \
    "In case there was a lot of output above," \
    "you may have missed these earlier warnings:" \
    "${STERN_WARNINGS//$'\n'/$'\n  • '}" >&2

  return "$D_RV"
}


function sternly_warn () {
  STERN_WARNINGS+=$'\n'"$*"
  echo "W: $APP_NAME: $*" >&2
}


function doco_fallible_actually_do_stuff () {
  if [ -n "${CFG[pre-task:down]}" ]; then
    printf -- 'D: %s: Auto-"down" before "%s":\n' \
      "$APP_NAME" "${CFG[pre-task:down]}"
    "${OUTER_RUN[@]}" down || return $?
  fi

  if [ -n "${CFG[pre-task:rebuild]}" ]; then
    echo "D: $APP_NAME: Rebuilding project."
    "${OUTER_RUN[@]}" build --no-cache --force-rm || return $?
  fi

  if [ "$D_TASK" == SKIP ]; then
    [ "$DBGLV" -lt 6 ] || echo 'D: Skipping D_TASK as requested.' >&2
    return 0
  fi

  local D_CMD=(
    "${OUTER_RUN[@]}"
    "${D_PRE_TASK_OPT[@]}"
    "$D_TASK"
    "${D_EARLY_OPT[@]}"
    "$@"
    )
  [ "$DBGLV" -lt 2 ] || echo D: "${D_CMD[*]}" >&2
  "${D_CMD[@]}" || return $?$(echo W: "failed (rv=$?) to ${D_CMD[*]}" >&2)
}


function doco_cfg_compo_file__insert_inside_prefix () {
  local SPEC="$COMPOSE_FILE"
  [ -n "$SPEC" ] || return 0
  SPEC=":$SPEC"
  SPEC="${SPEC//:/:"${CFG[inside_prefix]}/"}"
  SPEC="${SPEC#:}"
  OUTER_RUN+=( --env COMPOSE_FILE="$SPEC" )
}


function doco_gen_proxy_opt () {
  PROXY_OPT=() # <- in case one of the rc files wants to re-render them
  local KEY= VAL=
  for KEY in http{s,}_proxy; do
    VAL=
    eval 'VAL="$'"$KEY"'"'
    case "$VAL" in
      '' ) continue;;
      [a-z]*://* ) ;;
      * )
        echo "E: $APP_NAME: Unsupported proxy syntax in $KEY: '$VAL'" >&2
        return 8;;
    esac
    PROXY_OPT+=( --env "$KEY=$VAL" )
    PROXY_OPT+=( --env "${KEY^^}=$VAL" )
    # ^-- DoCo wants the proxy variables in uppercase
  done
}


function doco_advise_on_compose_file_version () {
  case "$COMPOSE_FILE" in
    /dev/null ) return 0;;
  esac
  local CF_VER="$(sed -nre 's~^version:~~p' -- "$COMPOSE_FILE")"
  CF_VER="${CF_VER//[$'\x22\x27 \t']/}"
  local ERR=
  case "$CF_VER" in
    '' ) ERR='none';;
    *$'\n'* ) ERR='too many';;
  esac
  [ -z "$ERR" ] || return 5$( echo "E: $APP_NAME:" >&2 \
    "Unable to detect compose file format version: Found $ERR.")

  case "$CF_VER" in
    1 | 1.* | 2 | 2.0 ) ERR='%dc and %ba';;
    2.1 ) ERR='%ba';;
    2.* ) CFG[can_use_global_build_arg]=+;;
    3 | 3.0 | 3.[1-8] ) CFG[can_use_global_build_arg]=+; ERR='%dc';;
    * )
      echo "E: $APP_NAME:" >&2 \
        "Your compose file format version was detected as '$CF_VER'" \
        'which seems incompatible with `docker-compose`.' \
        "You should probably use docker's internal compose command" \
        '(`docker compose` without hyphen) instead.'
      return 5;;
  esac
  ERR="${ERR//%dc/dependency conditions}"
  ERR="${ERR//%ba/global --build-arg}"
  [ -z "$ERR" ] || sternly_warn \
    "Your compose file format version was detected as '$CF_VER'" \
    "which lacks $ERR" '(see `compose_file_versions.md`).' \
    'You may want to consider using version 2.2 or 3.9.'
}


function doco_build_maybe_add_proxy_build_args () {
  [ -n "${PROXY_OPT[0]}" ] || return 0
  [ -n "${CFG[can_use_global_build_arg]}" ] || return 0$(
    echo "W: $APP_NAME:" >&2 \
      'Flinching from adding proxy settings as --build-arg options!')
  D_EARLY_OPT+=( "${PROXY_OPT[@]/#--env/--build-arg}" )
  local WARN= ITEM=
  for ITEM in "${PROXY_OPT[@]}"; do case "$ITEM" in
    --* ) ;;
    *=* ) ITEM="${ITEM%%=*}"; [ -z "$ITEM" ] || WARN+="$ITEM=…, ";;
  esac; done
  [ -n "$WARN" ] || return 4$(echo "E: $FUNCNAME: Empty proxy options?" \
    "This has to be a bug, probably about control flow failure." >&2)
  sternly_warn "Passing proxy settings (${WARN%, }) via --build-arg." \
    'Anyone with access to the built image will be able to see them.'
}










dockerized_docker_compose "$@"; exit $?
