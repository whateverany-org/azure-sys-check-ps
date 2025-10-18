#!/bin/sh
# shellcheck shell=ash
#set -x
# =------------------------------------------------------------------------= #
#
# /_functions.sh
# Common functions used in project container scripts
#
# _DEBUG can be turned on by:
#   touch /var/tmp/_entrypoint.sh_DEBUG
#
# =------------------------------------------------------------------------= #
########
# start logging
########
_ARGS="${*}"
_SCRIPT="$(basename "${0}")"
_SCRIPT_MSG="${_SCRIPT}"
case "${_SCRIPT_MSG}" in
*.*)
  _SCRIPT_MSG="${_SCRIPT_MSG%.*}"
  ;;
esac
_SCRIPT_MSG="$(printf "%s" "${_SCRIPT}" | cut -c1-8)"
_LOG_DIR="${OCI_DATA_DIR}"
_LOG_FILE_BASE="${OCI_DATA_DIR}/${_SCRIPT}"
_LOG_FILE="${_LOG_FILE_BASE}.out"
_LOG_PIPE="${_LOG_FILE_BASE}_${$}"
_LOCK_FILE="${OCI_DATA_DIR}/.${_SCRIPT}.lock"

_DEBUG_FLAG_FILE="${_LOG_FILE_BASE}_DEBUG"
if [ -e "${_DEBUG_FLAG_FILE}" ]; then
  _DEBUG="true"
fi

########
# logger
########
_log() {
  if [ "${_DEBUG}" ]; then
    case "$1" in
    EROR | WARN | INFO | DBUG)
      _LEVEL="${1}"
      shift
      _MSG="${*}"
      ;;
    *)
      _LEVEL="INFO"
      _MSG="${*}"
      ;;
    esac
    echo "${_LEVEL}: $(date -u -Iseconds) ${_SCRIPT_MSG} ${_MSG}"
  fi
}

########
# exit trap
########
# shellcheck disable=SC2120
_exit() {
  if [ "$#" -le 1 ]; then
    _RC=0
    _LEVEL="INFO"
    _MSG=""
  else
    _RC="$1"
    shift
    _LEVEL="EROR"
    _MSG="$*"
  fi
  if [ -e "${_LOG_PIPE}" ]; then
    rm -f "${_LOG_PIPE}"
  fi
  _log "${_LEVEL}" "END ${_MSG} _RC=${_RC}"
  if [ "${_RC}" = "0" ]; then
    _log "Running _ARGS=${_ARGS}"
    exec ${_ARGS}
  else
    exit "${_RC}"
  fi
}

#if [ -n "${_DEBUG}" ]; then
#  mkfifo "${_LOG_PIPE}"
#  tee -a "${_LOG_FILE}" <"${_LOG_PIPE}" &
#  exec >"${_LOG_PIPE}" 2>&1
#fi

trap "_exit" QUIT INT TERM

# =------------------------------------------------------------------------= #
#
# _init_incus
#
# =------------------------------------------------------------------------= #
_init_incus() (
  _FUNCTION="${1}"
  shift
  _log "BEGIN _FUNCTION=${_FUNCTION} *=${*}"
  #
  # Incus client certs
  #
  _INCUS_CLIENT_DIR="${HOME}/.config/incus"
  _INCUS_SERVER_DIR="${_INCUS_CLIENT_DIR}/servercerts"
  _INCUS_CLIENT_CRT_FILE="${_INCUS_CLIENT_DIR}/client.crt"
  _INCUS_CLIENT_KEY_FILE="${_INCUS_CLIENT_DIR}/client.key"
  _INCUS_SERVER_CRT_FILE="${_INCUS_SERVER_DIR}/server.crt"
  # shellcheck disable=SC2174
  mkdir -m u=rwx,og= -p "${_INCUS_SERVER_DIR}"

  if [ ! -f "${_INCUS_CLIENT_CRT_FILE}" ]; then
    if [ -n "${INCUS_CLIENT_CRT}" ]; then
      printf "%b\n" "${INCUS_CLIENT_CRT}" >"${_INCUS_CLIENT_CRT_FILE}"
    fi
  fi
  if [ ! -f "${_INCUS_CLIENT_KEY_FILE}" ]; then
    if [ -n "${INCUS_CLIENT_KEY}" ]; then
      touch "${_INCUS_CLIENT_KEY_FILE}"
      chmod u=rw,og= "${_INCUS_CLIENT_KEY_FILE}"
      printf "%b\n" "${INCUS_CLIENT_KEY}" >"${_INCUS_CLIENT_KEY_FILE}"
    fi
  fi
  if [ ! -f "${_INCUS_SERVER_CRT_FILE}" ]; then
    if [ -n "${INCUS_SERVER_CRT}" ]; then
      printf "%b\n" "${INCUS_SERVER_CRT}" >"${_INCUS_SERVER_CRT_FILE}"
    fi
  fi
  _log "END _FUNCTION=${_FUNCTION}"
)

# =------------------------------------------------------------------------= #
#
# _init_ssh
#
# =------------------------------------------------------------------------= #
_init_ssh() (
  _FUNCTION="${1}"
  shift
  _log "BEGIN _FUNCTION=${_FUNCTION} *=${*}"
  _SSH_DIR="${HOME}/.ssh"

  _SSH_AUTHORIZED_KEYS_FILE="${_SSH_DIR}/authorized_keys"
  _SSH_ID_FILE="${_SSH_DIR}/id_ed25519"
  _SSH_ID_PUB_FILE="${_SSH_DIR}/id_ed25519.pub"
  _SSH_KNOWN_HOSTS_FILE="${_SSH_DIR}/known_hosts"
  _SSH_AUTH_SOCK="${_SSH_DIR}/ssh-agent.sock"

  if [ ! -d "${_SSH_DIR}" ]; then
    install -d -m u=rwx,og= "${_SSH_DIR}"
  fi

  (
    umask 077
    eval "$(ssh-agent -t 12h -s -a "${_SSH_AUTH_SOCK}")"
  )

  if [ -n "${SSH_ID_PUB}" ]; then
    if [ ! -f "${_SSH_ID_PUB_FILE}" ]; then
      printf "%b\n" "${SSH_KNOWN_HOSTS}" | install -D -m u=rw,og= /dev/stdin "${_SSH_ID_PUB_FILE}"
    fi
    if [ ! -f "${_SSH_AUTHORIZED_KEYS_FILE}" ]; then
      printf "%b\n" "${SSH_ID_PUB}" | install -D -m u=rw,og= /dev/stdin "${_SSH_AUTHORIZED_KEYS_FILE}"
    fi
  fi

  if [ -n "${SSH_KNOWN_HOSTS}" ]; then
    if [ ! -f "${_SSH_KNOWN_HOSTS_FILE}" ]; then
      printf "%b\n" "${SSH_KNOWN_HOSTS}" | install -D -m u=rw,og= /dev/stdin "${_SSH_KNOWN_HOSTS_FILE}"
    fi
  fi

  if [ -n "${SSH_ID}" ]; then
    if [ ! -f "${_SSH_ID_FILE}" ]; then
      printf "%b\n" "${SSH_ID}" | install -D -m u=rw,og= /dev/stdin "${_SSH_ID_FILE}"
    fi
  fi

  if ! ssh-add -l 2>/dev/null | grep -q -e "${SSH_ID}"; then
    ssh-add "${_SSH_ID_FILE}"
  fi

  _log "END _FUNCTION=${_FUNCTION}"
)
