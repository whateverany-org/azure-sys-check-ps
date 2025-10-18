#!/bin/bash
set -x
set -o errexit
BEGIN_DATETIME="$(date '+%Y%m%d-%H%M%S')"
LOGFILE="/tmp/$(basename "${0}").${BEGIN_DATETIME}.log"
exec > >(/usr/bin/tee -a "${LOGFILE}")
exec 2>&1
echo "INFO: BEGIN ${0} '${*}'"

AZURE_CONTAINER_APP="${AZURE_CONTAINER_APP:-sleepy}"
AZURE_RG="${AZURE_RG:-undefined}"
RUN_TIMEOUT="${RUN_TIMEOUT:-120}"

AZURE_ENV="${AZURE_ENV:-${AZURE_RG}-${AZURE_CONTAINER_APP}}"

_log() {
  local LEVEL="${1:-INFO}"
  shift
  echo "$(date '+%Y-%m-%d %H:%M:%S') ${LEVEL} $*"
}

_cleanup() {
  # Ensure providers are registered
  timeout "${RUN_TIMEOUT}" az provider register -n Microsoft.App --wait || true
  timeout "${RUN_TIMEOUT}" az provider register -n Microsoft.OperationalInsights --wait || true

  # Delete container apps first
  for app in ${AZURE_CONTAINER_APP}; do
    timeout "${RUN_TIMEOUT}" az containerapp delete \
      --name "${app}" \
      --resource-group "${AZURE_RG}" \
      --yes || true
  done

  # Delete container app environment
  if timeout "${RUN_TIMEOUT}" az containerapp env show \
    --name "${AZURE_ENV}" \
    --resource-group "${AZURE_RG}" &>/dev/null; then
    timeout "${RUN_TIMEOUT}" az containerapp env delete \
      --name "${AZURE_ENV}" \
      --resource-group "${AZURE_RG}" \
      --yes || true

    # Wait until the environment is fully gone
    echo "Waiting for container app environment deletion..."
    until ! az containerapp env show --name "${AZURE_ENV}" --resource-group "${AZURE_RG}" &>/dev/null; do
      sleep 5
    done
  fi

  # Delete Log Analytics workspace if it exists
  if timeout "${RUN_TIMEOUT}" az monitor log-analytics workspace show \
    --resource-group "${AZURE_RG}" \
    --workspace-name "${AZURE_WORKSPACE}" &>/dev/null; then
    timeout "${RUN_TIMEOUT}" az monitor log-analytics workspace delete \
      --resource-group "${AZURE_RG}" \
      --workspace-name "${AZURE_WORKSPACE}" \
      --yes || true
  fi

  # Finally, delete the resource group
  timeout "${RUN_TIMEOUT}" az group delete \
    --name "${AZURE_RG}" \
    --yes \
    --no-wait || true

  # Optional: poll until RG is gone
  while [[ "$(az group exists --name "${AZURE_RG}")" == "true" ]]; do
    echo "Waiting for resource group deletion..."
    sleep 5
  done

  sync
}

_cleanup

END_DATETIME=$(date '+%Y%m%d-%H%M%S')
_log INFO "END_DATETIME=${END_DATETIME}"
_log INFO "END ${0} '${*}'"
