#!/bin/bash
set -x
set -o errexit
BEGIN_DATETIME="$(date '+%Y%m%d-%H%M%S')"
LOGFILE="/tmp/$(basename "${0}").${BEGIN_DATETIME}.log"
exec > >(/usr/bin/tee -a "${LOGFILE}")
exec 2>&1
echo "INFO: BEGIN ${0} '${*}'"

AZURE_CONTAINER_APP="${AZURE_CONTAINER_APP:-sleepy}"
AZURE_CONTAINER_IMAGE="${AZURE_CONTAINER_IMAGE:-whateverany.azurecr.io/busybox:latest}"
AZURE_CONTAINER_INSTANCES="${AZURE_CONTAINER_INSTANCES:-2}"
AZURE_CONTAINER_TIMEOUT="${AZURE_CONTAINER_TIMEOUT:-300}"
AZURE_LOCATION="${AZURE_LOCATION:-eastus}"
AZURE_RG="${AZURE_RG:-undefined}"
RUN_TIMEOUT="${RUN_TIMEOUT:-120}"

AZURE_ENV="${AZURE_ENV:-${AZURE_RG}-${AZURE_CONTAINER_APP}}"
AZURE_WORKSPACE="${AZURE_WORKSPACE:-workspace-${AZURE_RG}}"

AZ_CMD=(
  "timeout"
  "${RUN_TIMEOUT}"
  "az"
)
AZ_CLEANUP_CMD=(
  "$(dirname "${0}")/azure_cleanup.sh"
)

_log() {
  local LEVEL="${1:-INFO}"
  shift
  echo "$(date '+%Y-%m-%d %H:%M:%S') ${LEVEL} $*"
}

_exit() {
  _log EROR "caught ERR QUIT INT TERM, or triggerd by RUN_TIMEOUT=${RUN_TIMEOUT}"
  "${AZ_CLEANUP_CMD[@]}"
  "${AZ_CMD[@]}" logout
  exit 1
}

trap "_exit" ERR QUIT INT TERM

_init() {
  _XTRACE_STATE="off"
  case "$(set +o)" in
  *xtrace*) _XTRACE_STATE='on' ;;
  esac
  [[ "${_XTRACE_STATE}" == 'on' ]] && set +x

  jq -r '.clientSecret' <<<"$AZURE_CREDENTIALS" | "${AZ_CMD[@]}" login --service-principal \
    --username "$(jq -r '.clientId' <<<"$AZURE_CREDENTIALS")" \
    --password @- \
    --tenant "$(jq -r '.tenantId' <<<"$AZURE_CREDENTIALS")"

  # Set subscription
  "${AZ_CMD[@]}" account set --subscription "$(jq -r '.subscriptionId' <<<"$AZURE_CREDENTIALS")"

  # Unset credentials immediately after use
  unset AZURE_CREDENTIALS

  [[ "${_XTRACE_STATE}" == 'on' ]] && set -x
}

_main() {
  # Register providers
  "${AZ_CMD[@]}" provider register -n Microsoft.App --wait
  "${AZ_CMD[@]}" provider register -n Microsoft.OperationalInsights --wait

  # Create resource group if missing
  "${AZ_CMD[@]}" group show --name "${AZURE_RG}" &>/dev/null ||
    "${AZ_CMD[@]}" group create --name "${AZURE_RG}" --location "${AZURE_LOCATION}"

  # Create Log Analytics workspace if missing
  "${AZ_CMD[@]}" monitor log-analytics workspace show \
    --resource-group "${AZURE_RG}" \
    --workspace-name "${AZURE_WORKSPACE}" &>/dev/null ||
    "${AZ_CMD[@]}" monitor log-analytics workspace create \
      --resource-group "${AZURE_RG}" \
      --workspace-name "${AZURE_WORKSPACE}" \
      --location "${AZURE_LOCATION}"

  AZURE_WORKSPACE_ID=$("${AZ_CMD[@]}" monitor log-analytics workspace show \
    --resource-group "${AZURE_RG}" \
    --workspace-name "${AZURE_WORKSPACE}" -o json | jq -r '.customerId')

  AZURE_WORKSPACE_KEY=$("${AZ_CMD[@]}" monitor log-analytics workspace get-shared-keys \
    --resource-group "${AZURE_RG}" \
    --workspace-name "${AZURE_WORKSPACE}" -o json | jq -r '.primarySharedKey')

  ENV_JSON=$("${AZ_CMD[@]}" containerapp env show \
    --name "${AZURE_ENV}" \
    --resource-group "${AZURE_RG}" 2>&1) || ENV_RC=$?

  _log INFO "RC=${ENV_RC:-0}"
  _log INFO "ENV_JSON=${ENV_JSON}"

  if [[ "${ENV_RC:-0}" -eq 0 ]]; then
    echo INFO "Reusing existing Container App Environment '${AZURE_ENV}'"
  elif grep -q "ResourceNotFound" <<<"${ENV_JSON}"; then
    _log INFO "Creating Container App Environment '${AZURE_ENV}'"
    "${AZ_CMD[@]}" containerapp env create \
      --name "${AZURE_ENV}" \
      --resource-group "${AZURE_RG}" \
      --location "${AZURE_LOCATION}" \
      --logs-workspace-id "${AZURE_WORKSPACE_ID}" \
      --logs-workspace-key "${AZURE_WORKSPACE_KEY}"
  else
    echo EROR "Unexpected failure showing Container App Environment"
    echo "${ENV_JSON}"
    exit 1
  fi

  # Create container app or redeploy
  if ! "${AZ_CMD[@]}" containerapp show \
    --name "${AZURE_CONTAINER_APP}" \
    --resource-group "${AZURE_RG}" &>/dev/null; then
    "${AZ_CMD[@]}" containerapp create \
      --name "${AZURE_CONTAINER_APP}" \
      --resource-group "${AZURE_RG}" \
      --environment "${AZURE_ENV}" \
      --image "${AZURE_CONTAINER_IMAGE}" \
      --cpu 0.25 --memory 0.5Gi \
      --min-replicas "${AZURE_CONTAINER_INSTANCES}" \
      --max-replicas "${AZURE_CONTAINER_INSTANCES}" \
      --command "sleep" \
      --args "${AZURE_CONTAINER_TIMEOUT}" \
      --no-wait
    #
    AZURE_CONTAINER_APP_PID="${!}"
    _log INFO "backgrounded AZURE_CONTAINER_APP_PID=${AZURE_CONTAINER_APP_PID}"
  else
    _log INFO "Container App '${AZURE_CONTAINER_APP}' already exists. Consider updating or redeploying if needed."
  fi
}

_init
_main

END_DATETIME=$(date '+%Y%m%d-%H%M%S')
_log INFO "END_DATETIME=${END_DATETIME}"
_log INFO "END ${0} '${*}'"
