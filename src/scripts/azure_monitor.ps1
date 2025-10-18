#!/usr/bin/env pwsh
##################################################################################
#.SYNOPSIS
# Azure Linux VM and Container App Metrics Monitoring
#
#.DESCRIPTION
# Queries Azure Monitor for key performance metrics of all Linux VMs and all
# Container Apps in the current Azure subscription.
# Outputs results in separate tables for each resource type.
#
#.NOTES
# Author: Darcy Sheehan / David
# Versions:
# 2025-OCT-20 0.4 Refactored to fix structural errors and address linter warnings.
##################################################################################

param (
  [string]${SCRIPT_NAME} = "monitor_azure_resources",
  [string]${BASE_DIR} = (Join-Path "data" "powershell"),
  [switch]${_DEBUG} = $false
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
# Functions
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

function Get-MetricSafe {
    param (
        [string]$ResourceId,
        [string]$MetricName,
        [string]$AppName = ""
    )

    try {
        # Suppress warning output and stop the cmdlet from terminating on errors
        $metric = Get-AzMetric -ResourceId $ResourceId -MetricName $MetricName `
                  -WarningAction SilentlyContinue -ErrorAction Stop

        # Return the latest average value if available
        if ($metric -and $metric.Timeseries.Count -gt 0 -and $metric.Timeseries[0].Data.Count -gt 0) {
            return $metric.Timeseries[0].Data[-1].Average
        } else {
            return $null
        }
    }
    catch {
        Write-Logger -LEVEL "WARN" "Skipping metric '$MetricName' for resource '$ResourceId': $_"
        return $null
    }
}

function Invoke-Main {
  [CmdletBinding()]
  param ()
  process {
    try {
      Write-Logger -LEVEL "DBUG" "Begin Invoke-Main()"

      # Login to Azure if needed
      Write-Logger -LEVEL "INFO" "Checking Azure session..."
      if (-not (Get-AzContext)) {
        if ($env:AZURE_CREDENTIALS) {
          Write-Logger -LEVEL "INFO" "Authenticating with AZURE_CREDENTIALS..."

          $creds = $env:AZURE_CREDENTIALS | ConvertFrom-Json

          [SuppressMessage("PSAvoidUsingConvertToSecureStringWithPlainText", Justification = "Secret is managed via CI/CD environment variable")]
          $securePassword = ConvertTo-SecureString $creds.clientSecret -AsPlainText -Force
          $psCred = New-Object System.Management.Automation.PSCredential ($creds.clientId, $securePassword)

          Connect-AzAccount `
            -ServicePrincipal `
            -Credential $psCred `
            -Tenant $creds.tenantId `
            -Subscription $creds.subscriptionId | Out-Null

          Write-Logger -LEVEL "INFO" "Connected to subscription $($creds.subscriptionId)"
        }
        else {
            Write-Logger -LEVEL "WARN" "AZURE_CREDENTIALS not set — falling back to device authentication."
            Connect-AzAccount -UseDeviceAuthentication | Out-Null
        }
      }

      ### # --- Container App Monitoring Section ---
      ### Write-Logger -LEVEL "INFO" "--- Starting Container App Monitoring ---"
      ### $containerApps = Get-AzContainerApp

      ### if (-not $containerApps) {
      ###   Write-Logger -LEVEL "WARN" "No Container Apps found in subscription."
      ### } else {
      ###   $appResults = @()
      ###   $endTime = Get-Date
      ###   $startTime = $endTime.AddMinutes(-15) # Use a smaller, more recent window

      ###   foreach ($app in $containerApps) {
      ###       $cpuValue = Get-MetricSafe -resourceId $app.Id -metricName "CpuUsageNanoCores" -appName $app.Name -startTime $startTime -endTime $endTime
      ###       $memValue = Get-MetricSafe -resourceId $app.Id -metricName "MemoryUsageBytes" -appName $app.Name -startTime $startTime -endTime $endTime
      ###       $reqValue = Get-MetricSafe -resourceId $app.Id -metricName "Requests" -appName $app.Name -startTime $startTime -endTime $endTime

      ###       $appResults += [PSCustomObject]@{
      ###           ContainerApp   = $app.Name
      ###           ResourceGroup  = $app.ResourceGroupName
      ###           CPU_NanoCores  = if ($cpuValue -is [double]) { [math]::Round($cpuValue) } else { "N/A" }
      ###           Memory_Bytes   = if ($memValue -is [double]) { [math]::Round($memValue) } else { "N/A" }
      ###           Requests       = if ($reqValue -is [double]) { [math]::Round($reqValue) } else { "N/A" }
      ###       }
      ###   }

      ###   Write-Logger -LEVEL "INFO" "Container App Monitoring Results:"
      ###   $appResults | Format-Table -AutoSize
      ### }

      # --- VM Monitoring Section ---
      Write-Logger -LEVEL "INFO" "--- Starting Linux VM Monitoring ---"
      $vms = Get-AzVM | Where-Object {$_.StorageProfile.OSDisk.OsType -eq 'Linux'}

      if (-not $vms) {
        Write-Logger -LEVEL "WARN" "No Linux VMs found in subscription."
      }
      else {
        $vmResults = @()
        foreach ($vm in $vms) {
          Write-Logger -LEVEL "INFO" "Querying metrics for VM: $($vm.Name)"
          $cpuMetric = Get-MetricSafe -ResourceId $vm.Id -MetricName "Percentage CPU"
          $cpu = Get-MetricSafe -ResourceId $vm.Id -MetricName "Percentage CPU"
          $cpuStr = if ($cpu) {"{0:N1}%" -f $cpu} else {"N/A"}

          $mem = Get-MetricSafe -ResourceId $vm.Id -MetricName "Available Memory Bytes"
          $memStr = if ($mem) {"{0:N1}MB" -f ($mem/1MB)} else {"N/A"}

          $disk = Get-MetricSafe -ResourceId $vm.Id -MetricName "Logical Disk % Used"
          $diskStr = if ($disk) {"{0:N1}%" -f $disk} else {"N/A"}

          $vmResults += [PSCustomObject]@{
            VM            = $vm.Name
            ResourceGroup = $vm.ResourceGroupName
            CPU           = $cpuStr
            MemoryAvail   = $memStr
            DiskUsedPct   = $diskStr
          }
        }
        Write-Logger -LEVEL "INFO" "Linux VM Monitoring Results:"
        $vmResults | Format-Table -AutoSize
      }

      Write-Logger -LEVEL "DBUG" "End Invoke-Main()"
    }
    catch {
      $PSCmdlet.ThrowTerminatingError($_)
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

  # Module installation logic can be improved, but is functional
  $requiredModules = @("Az.Accounts", "Az.App", "Az.Monitor", "Az.Compute")
  foreach ($mod in $requiredModules) {
      if (-not (Get-Module -ListAvailable -Name $mod)) {
          Write-Logger -LEVEL "INFO" "Module $mod not found — installing..."
          try {
              [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
              Install-Module -Name $mod -Scope CurrentUser -Repository PSGallery -Force -AcceptLicense
          } catch {
              Write-Logger -LEVEL "EROR" ("Failed to install module " + $mod + ": " + $_.Exception.Message)
              throw
          }
      }
  }

  Invoke-Main
  Write-Logger -LEVEL "DBUG" "Completed successfully."
  exit 0
}
catch {
  ${ERROR_MESSAGE} = ${_}.Exception.Message
  Write-Logger -LEVEL "EROR" "Fatal Error: ${ERROR_MESSAGE}"
  exit 1
}
