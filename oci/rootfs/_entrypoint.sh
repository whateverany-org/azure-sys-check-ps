#!/bin/sh
# shellcheck shell=ash
#set -x
# shellcheck disable=SC1091
. /_functions.sh

# =------------------------------------------------------------------------= #
#
# /_entrypoint.sh
# Common entrypoint wrapper used in all project container builds
#
# Can source optional /__entrypoint.sh for container specific entry
# (FROM oci/<container>/rootfs/__entrypoint.sh)
#
# Can source  optional /a/test/___entrypoint.sh for local testing entry
# (test/___entrypoint.sh)
#
# _DEBUG can be turned on by:
#   touch /var/tmp/_entrypoint.sh_DEBUG
# OR setting _DEBUG
#
# =------------------------------------------------------------------------= #

# =------------------------------------------------------------------------= #
#
# _entrypoint
#
# =------------------------------------------------------------------------= #
_entrypoint() (
  _FUNCTION="${1}"
  shift
  _log "BEGIN _FUNCTION=${_FUNCTION} *=${*}"

  #
  # Run additional entrypoint if it exists
  #
  if [ -e "/__entrypoint.sh" ]; then
    /__entrypoint.sh "${@}"
  fi

  #
  # For custom workarounds /data/__entrypoint.sh
  #
  if [ -e "${OCI_DATA_DIR}/__entrypoint.sh" ]; then
    "${OCI_DATA_DIR}/__entrypoint.sh"
  fi

  #
  # For local testing only. /test/__entrypoint.sh should be in .gitignore
  #
  if [ -e "${OCI_DATA_DIR}/test/__entrypoint.sh" ]; then
    "${OCI_DATA_DIR}/test/__entrypoint.sh"
  fi

  _log "END _FUNCTION=${_FUNCTION}"
)

#_LOG_PIPE="${_LOG_FILE_BASE}_${$}"
#if [ -n "${_DEBUG}" ]; then
#  mkfifo "${_LOG_PIPE}"
#  tee -a "${_LOG_FILE}" <"${_LOG_PIPE}" &
#  exec >"${_LOG_PIPE}" 2>&1
#else
#  exec 2>&1
#fi
#
#trap "_exit" QUIT INT TERM

_entrypoint "_entrypoint" "${@}"
exec "${@}"
