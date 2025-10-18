#!/usr/bin/env pwsh
##################################################################################
#.SYNOPSIS
# skeleton.ps1
#
#.DESCRIPTION
# Minimal powershell script boilerplate
#
#.PARAMETER BASE_DIR
# temp/script_name unless overwritten
#
#.PARAMETER MESSAGE
# Hello world output message
#
#.PARAMETER _DEBUG
# Specifies if script should log output
#
#.INPUTS
#
#.OUTPUTS
# If not set _DEBUG, will write log messages to STDOUT.
#
#.EXAMPLE
# skeleton.ps1 -MESSAGE "Hi there!"
#
#.NOTES
# Author: Darcy Sheehan
# Versions:
# 2025-OCT-19 0.1 Initial
##################################################################################

#########################################
# Output without writing to stdout for verbosity, through stderr, when run in container
#########################################
#function Out-Stderr ([string] ${s}) {
#    ${host}.ui.WriteErrorLine(${s})
#}

param (
  [string]${SCRIPT_NAME} = "interactive",
  [string]${BASE_DIR} = (Join-Path "data" "powershell"),
  [switch]${_DEBUG} = $false,
  [string]${MESSAGE} = "Hello, World."
)

#########################################
# Globals
#########################################
if (-not ${PSBoundParameters}.ContainsKey('SCRIPT_NAME')) {
    ${SCRIPT_NAME} = (Get-Item -LiteralPath ${PSCommandPath}).BaseName
}
${FILE_DATE} = Get-Date -Format "yyyyMMdd"
${FILE_TIME} = Get-Date -Format "HHmmss"
${LOG_DIR} = Join-Path ${BASE_DIR} ${SCRIPT_NAME}
${LOG_FILE} = Join-Path ${LOG_DIR} "${SCRIPT_NAME}.${FILE_DATE}-${FILE_TIME}.log"

#########################################
# Function: Write-Logger
#########################################
function Write-Logger {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]
    [string]${MESSAGE},

    [ValidateSet("DBUG","INFO","WARN","EROR")]
    [string]${LEVEL} = "INFO",

    [switch]${_DEBUG}
  )

  process {
    try {
      ${DATE_TIME} = (Get-Date).ToString("yyyy-MM-dd'T'HH:mm:ssK")
      ${LOG_LINE} = "${LEVEL}: ${DATE_TIME} ${MESSAGE}"

      if ((${LEVEL} -ne 'DBUG') -or ${_DEBUG}) {
        Write-Output ${LOG_LINE}
      }

      if (${LOG_FILE}) {
        ${LOG_LINE} | Out-File -FilePath ${LOG_FILE} -Encoding utf8 -Append
      }
    }
    catch {
      ${PSCmdlet}.ThrowTerminatingError(${_})
    }
  }
}

##################################################################################
#.SYNOPSIS
# Do-Main
#
#.DESCRIPTION
# This is the main calling routine.
#
#.EXAMPLE
# Do-Main
#
#.NOTES
#
##################################################################################
function Invoke-Main {
  [CmdletBinding()]
  param ()
  process {
    try {
      Write-Logger -LEVEL "DBUG" "Begin Invoke-Main()"
      Write-Logger "Message: ${MESSAGE}"
      Write-Logger -LEVEL "DBUG" "End Invoke-Main()"
    }
    catch {
      ${PSCmdlet}.ThrowTerminatingError(${_})
    }
  }
}

#########################################
# Invoke the main event
#########################################
try {
  if (-not (Test-Path ${LOG_DIR})) {
    New-Item -ItemType Directory -Path ${LOG_DIR} | Out-Null
  }

  Write-Logger -LEVEL "DBUG" "Starting ${SCRIPT_NAME}"
  Invoke-Main
  Write-Logger -LEVEL "DBUG" "Completed successfully."
  exit 0
}
catch {
  ${ERROR_MESSAGE} = ${_}.Exception.Message
  Write-Logger "Fatal Error: ${ERROR_MESSAGE}"
  exit 1
}
