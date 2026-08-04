<#
.SYNOPSIS
  SAMT S05 - Local Source and Capability Extraction
  Windows PowerShell 5.1 compatible.

.DESCRIPTION
  Consolidates the committed P02 and P03 audit artifacts into deterministic,
  machine-readable source, credential, capability, feature-state, and
  deprecation inventories.

  It does not read secret values and does not modify application code.

.OUTPUTS
  audit/s05-source-capability-inventory.json
  audit/s05-source-summary.csv
  audit/s05-capability-summary.csv
  audit/s05-credential-summary.csv
  audit/s05-feature-state-summary.csv
  audit/s05-summary.md
  audit/tools/S05-Local-Source-Capability-Extraction-WindowsPS51.ps1
#>

[CmdletBinding()]
param(
    [string]$RepositoryPath = (Get-Location).Path,
    [string]$AuditDirectory = "audit"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Require-File {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required input file is missing: $Path"
    }

    if ((Get-Item -LiteralPath $Path).Length -eq 0) {
        throw "Required input file is empty: $Path"
    }
}

function Get-PropertyValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$DefaultValue = ""
    )

    $property = $Object.PSObject.Properties[$Name]

    if ($null -eq $property -or $null -eq $property.Value) {
        return $DefaultValue
    }

    return [string]$property.Value
}

function Normalize-BooleanText {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return "unknown"
    }

    switch -Regex ($Value.Trim().ToLowerInvariant()) {
        '^(true|yes|1)$' { return "true" }
        '^(false|no|0)$' { return "false" }
        default { return $Value.Trim() }
    }
}

$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
Set-Location $repo

if (-not (Test-Path -LiteralPath (Join-Path $repo ".git"))) {
    throw "No .git directory found."
}

$audit = Join-Path $repo $AuditDirectory
New-Item -ItemType Directory -Path $audit -Force | Out-Null

$inputPaths = [ordered]@{
    sourceInventory = Join-Path $audit "p02-source-inventory.csv"
    credentialMatrix = Join-Path $audit "p02-credential-name-matrix.csv"
    sourceEvidence = Join-Path $audit "p02-evidence-index.csv"
    capabilityInventory = Join-Path $audit "p03-capability-inventory.csv"
    featureMatrix = Join-Path $audit "p03-feature-flag-and-entitlement-matrix.csv"
    deprecatedMatrix = Join-Path $audit "p03-deprecated-and-sunset.csv"
    capabilityEvidence = Join-Path $audit "p03-evidence-index.csv"
}

foreach ($path in $inputPaths.Values) {
    Require-File -Path $path
}

$branch = (& git branch --show-current 2>&1 | Out-String).Trim()
$commit = (& git rev-parse HEAD 2>&1 | Out-String).Trim()
$statusBefore = (& git status --short 2>&1 | Out-String).Trim()
$timestamp = Get-Date

$sources = @(Import-Csv -LiteralPath $inputPaths.sourceInventory)
$credentials = @(Import-Csv -LiteralPath $inputPaths.credentialMatrix)
$sourceEvidence = @(Import-Csv -LiteralPath $inputPaths.sourceEvidence)
$capabilities = @(Import-Csv -LiteralPath $inputPaths.capabilityInventory)
$features = @(Import-Csv -LiteralPath $inputPaths.featureMatrix)
$deprecated = @(Import-Csv -LiteralPath $inputPaths.deprecatedMatrix)
$capabilityEvidence = @(Import-Csv -LiteralPath $inputPaths.capabilityEvidence)

$normalizedSources = @(
    foreach ($row in $sources) {
        [ordered]@{
            sourceId = Get-PropertyValue -Object $row -Name "sourceId" -DefaultValue "unknown"
            nameOriginal = Get-PropertyValue -Object $row -Name "nameOriginal" -DefaultValue "unknown"
            domainCodes = Get-PropertyValue -Object $row -Name "domainCodes" -DefaultValue "unknown"
            collectionMethod = Get-PropertyValue -Object $row -Name "collectionMethod" -DefaultValue "unknown"
            authentication = Get-PropertyValue -Object $row -Name "authentication" -DefaultValue "unknown"
            environmentVariable = Get-PropertyValue -Object $row -Name "environmentVariable" -DefaultValue ""
            licence = Get-PropertyValue -Object $row -Name "licence" -DefaultValue "unknown"
            status = Get-PropertyValue -Object $row -Name "status" -DefaultValue "Requires runtime verification"
            dataNature = Get-PropertyValue -Object $row -Name "dataNature" -DefaultValue "unknown"
            fallbackSourceId = Get-PropertyValue -Object $row -Name "fallbackSourceId" -DefaultValue ""
            surfaces = Get-PropertyValue -Object $row -Name "surfaces" -DefaultValue ""
            sourceFiles = Get-PropertyValue -Object $row -Name "sourceFiles" -DefaultValue ""
            registrations = Get-PropertyValue -Object $row -Name "registrations" -DefaultValue ""
            limitations = Get-PropertyValue -Object $row -Name "limitations" -DefaultValue ""
            runtimeVerificationRequired = Normalize-BooleanText (
                Get-PropertyValue -Object $row -Name "runtimeVerificationRequired" -DefaultValue "unknown"
            )
        }
    }
)

$normalizedCredentials = @(
    foreach ($row in $credentials) {
        [ordered]@{
            environmentVariable = Get-PropertyValue -Object $row -Name "environmentVariable" -DefaultValue "unknown"
            serverOrClientBoundary = Get-PropertyValue -Object $row -Name "serverOrClientBoundary" -DefaultValue "unknown"
            requiredOrOptional = Get-PropertyValue -Object $row -Name "requiredOrOptional" -DefaultValue "unknown"
            affectedSourceOrCapability = Get-PropertyValue -Object $row -Name "affectedSourceOrCapability" -DefaultValue ""
            declaredIn = Get-PropertyValue -Object $row -Name "declaredIn" -DefaultValue ""
            referencedBy = Get-PropertyValue -Object $row -Name "referencedBy" -DefaultValue ""
            missingBehavior = Get-PropertyValue -Object $row -Name "missingBehavior" -DefaultValue "unknown"
            notes = Get-PropertyValue -Object $row -Name "notes" -DefaultValue ""
        }
    }
)

$normalizedCapabilities = @(
    foreach ($row in $capabilities) {
        [ordered]@{
            capabilityId = Get-PropertyValue -Object $row -Name "capabilityId" -DefaultValue "unknown"
            name = Get-PropertyValue -Object $row -Name "name" -DefaultValue "unknown"
            domainCode = Get-PropertyValue -Object $row -Name "domainCode" -DefaultValue "unknown"
            purpose = Get-PropertyValue -Object $row -Name "purpose" -DefaultValue ""
            status = Get-PropertyValue -Object $row -Name "status" -DefaultValue "Requires runtime verification"
            sourceFiles = Get-PropertyValue -Object $row -Name "sourceFiles" -DefaultValue ""
            registrations = Get-PropertyValue -Object $row -Name "registrations" -DefaultValue ""
            callers = Get-PropertyValue -Object $row -Name "callers" -DefaultValue ""
            frontendComponent = Get-PropertyValue -Object $row -Name "frontendComponent" -DefaultValue ""
            backendService = Get-PropertyValue -Object $row -Name "backendService" -DefaultValue ""
            apiContract = Get-PropertyValue -Object $row -Name "apiContract" -DefaultValue ""
            sourceDependencies = Get-PropertyValue -Object $row -Name "sourceDependencies" -DefaultValue ""
            renderer = Get-PropertyValue -Object $row -Name "renderer" -DefaultValue "unknown"
            featureFlags = Get-PropertyValue -Object $row -Name "featureFlags" -DefaultValue ""
            permissionKeys = Get-PropertyValue -Object $row -Name "permissionKeys" -DefaultValue ""
            entitlement = Get-PropertyValue -Object $row -Name "entitlement" -DefaultValue ""
            dataNature = Get-PropertyValue -Object $row -Name "dataNature" -DefaultValue "unknown"
            tests = Get-PropertyValue -Object $row -Name "tests" -DefaultValue ""
            limitations = Get-PropertyValue -Object $row -Name "limitations" -DefaultValue ""
            runtimeVerificationRequired = Normalize-BooleanText (
                Get-PropertyValue -Object $row -Name "runtimeVerificationRequired" -DefaultValue "unknown"
            )
        }
    }
)

$normalizedFeatures = @(
    foreach ($row in $features) {
        [ordered]@{
            flagOrEntitlement = Get-PropertyValue -Object $row -Name "flagOrEntitlement" -DefaultValue "unknown"
            type = Get-PropertyValue -Object $row -Name "type" -DefaultValue "unknown"
            defaultState = Get-PropertyValue -Object $row -Name "defaultState" -DefaultValue "unknown"
            affectedCapability = Get-PropertyValue -Object $row -Name "affectedCapability" -DefaultValue ""
            definedIn = Get-PropertyValue -Object $row -Name "definedIn" -DefaultValue ""
            checkedIn = Get-PropertyValue -Object $row -Name "checkedIn" -DefaultValue ""
            userVisibleEffect = Get-PropertyValue -Object $row -Name "userVisibleEffect" -DefaultValue ""
            runtimeVerificationRequired = Normalize-BooleanText (
                Get-PropertyValue -Object $row -Name "runtimeVerificationRequired" -DefaultValue "unknown"
            )
        }
    }
)

$normalizedDeprecated = @(
    foreach ($row in $deprecated) {
        [ordered]@{
            capabilityId = Get-PropertyValue -Object $row -Name "capabilityId" -DefaultValue "UNRESOLVED"
            name = Get-PropertyValue -Object $row -Name "name" -DefaultValue "Requires manual identification"
            status = Get-PropertyValue -Object $row -Name "status" -DefaultValue "Requires review"
            evidence = Get-PropertyValue -Object $row -Name "evidence" -DefaultValue ""
            filePath = Get-PropertyValue -Object $row -Name "filePath" -DefaultValue ""
            replacement = Get-PropertyValue -Object $row -Name "replacement" -DefaultValue "unknown"
            reactivationPolicy = Get-PropertyValue -Object $row -Name "reactivationPolicy" -DefaultValue ""
            notes = Get-PropertyValue -Object $row -Name "notes" -DefaultValue ""
        }
    }
)

$sourceStatusSummary = @(
    $normalizedSources |
        Group-Object status |
        Sort-Object Count -Descending |
        ForEach-Object {
            [pscustomobject]@{
                dimension = "status"
                value = $_.Name
                count = $_.Count
            }
        }
)

$sourceMethodSummary = @(
    $normalizedSources |
        Group-Object collectionMethod |
        Sort-Object Count -Descending |
        ForEach-Object {
            [pscustomobject]@{
                dimension = "collectionMethod"
                value = $_.Name
                count = $_.Count
            }
        }
)

$sourceSummary = @($sourceStatusSummary + $sourceMethodSummary)

$capabilitySummary = @(
    $normalizedCapabilities |
        Group-Object status |
        Sort-Object Count -Descending |
        ForEach-Object {
            [pscustomobject]@{
                dimension = "status"
                value = $_.Name
                count = $_.Count
            }
        }
)

$credentialSummary = @(
    $normalizedCredentials |
        Group-Object serverOrClientBoundary |
        Sort-Object Count -Descending |
        ForEach-Object {
            [pscustomobject]@{
                dimension = "serverOrClientBoundary"
                value = $_.Name
                count = $_.Count
            }
        }
)

$featureSummary = @(
    $normalizedFeatures |
        Group-Object type |
        Sort-Object Count -Descending |
        ForEach-Object {
            [pscustomobject]@{
                dimension = "type"
                value = $_.Name
                count = $_.Count
            }
        }
)

$inventoryObject = [ordered]@{
    schemaVersion = "1.0"
    workUnit = "S05"
    generatedAt = $timestamp.ToString("o")
    repository = [ordered]@{
        path = $repo
        branch = $branch
        commit = $commit
        workingTreeCleanAtStart = [string]::IsNullOrWhiteSpace($statusBefore)
        statusShortAtStart = $statusBefore
    }
    counts = [ordered]@{
        sources = $normalizedSources.Count
        credentials = $normalizedCredentials.Count
        capabilities = $normalizedCapabilities.Count
        featureFlagsAndEntitlements = $normalizedFeatures.Count
        deprecatedAndSunsetEvidence = $normalizedDeprecated.Count
        sourceEvidenceRows = $sourceEvidence.Count
        capabilityEvidenceRows = $capabilityEvidence.Count
    }
    sources = $normalizedSources
    credentials = $normalizedCredentials
    capabilities = $normalizedCapabilities
    featureFlagsAndEntitlements = $normalizedFeatures
    deprecatedAndSunset = $normalizedDeprecated
    summaries = [ordered]@{
        sources = $sourceSummary
        capabilities = $capabilitySummary
        credentials = $credentialSummary
        featureStates = $featureSummary
    }
    limitations = @(
        "S05 consolidates P02 and P03 evidence; it does not independently prove runtime availability.",
        "Static registrations, file paths, flags, or endpoint strings are not sufficient proof of operational state.",
        "No credential values were read or written.",
        "Manual and runtime verification remain required where identified."
    )
}

$jsonPath = Join-Path $audit "s05-source-capability-inventory.json"
$sourceSummaryPath = Join-Path $audit "s05-source-summary.csv"
$capabilitySummaryPath = Join-Path $audit "s05-capability-summary.csv"
$credentialSummaryPath = Join-Path $audit "s05-credential-summary.csv"
$featureSummaryPath = Join-Path $audit "s05-feature-state-summary.csv"
$summaryPath = Join-Path $audit "s05-summary.md"

$inventoryObject |
    ConvertTo-Json -Depth 12 |
    Set-Content -LiteralPath $jsonPath -Encoding UTF8

$sourceSummary |
    Export-Csv -LiteralPath $sourceSummaryPath -NoTypeInformation -Encoding UTF8

$capabilitySummary |
    Export-Csv -LiteralPath $capabilitySummaryPath -NoTypeInformation -Encoding UTF8

$credentialSummary |
    Export-Csv -LiteralPath $credentialSummaryPath -NoTypeInformation -Encoding UTF8

$featureSummary |
    Export-Csv -LiteralPath $featureSummaryPath -NoTypeInformation -Encoding UTF8

$summary = @(
    "# S05 Source and Capability Extraction",
    "",
    "## Metadata",
    "",
    "- Timestamp: $($timestamp.ToString('o'))",
    "- Branch: $branch",
    "- Commit: $commit",
    "- Working tree clean at start: $([string]::IsNullOrWhiteSpace($statusBefore))",
    "",
    "## Consolidated Counts",
    "",
    "- Sources: $($normalizedSources.Count)",
    "- Credential records: $($normalizedCredentials.Count)",
    "- Capability records: $($normalizedCapabilities.Count)",
    "- Feature flags and entitlements: $($normalizedFeatures.Count)",
    "- Deprecated and sunset evidence rows: $($normalizedDeprecated.Count)",
    "",
    "## Validation Boundary",
    "",
    "This work unit consolidates P02 and P03 audit evidence into machine-readable outputs.",
    "It does not claim runtime source availability, credential availability, renderer compatibility, entitlement activation, or successful provider access.",
    "",
    "## Security",
    "",
    "- Credential names only were processed.",
    "- No secret values were read, printed, or stored.",
    "- No application code, contracts, sources, flags, permissions, or UI files were modified.",
    "",
    "## Outputs",
    "",
    "- audit/s05-source-capability-inventory.json",
    "- audit/s05-source-summary.csv",
    "- audit/s05-capability-summary.csv",
    "- audit/s05-credential-summary.csv",
    "- audit/s05-feature-state-summary.csv",
    "- audit/s05-summary.md",
    "- audit/tools/S05-Local-Source-Capability-Extraction-WindowsPS51.ps1"
)

$summary |
    Set-Content -LiteralPath $summaryPath -Encoding UTF8

$toolDirectory = Join-Path $audit "tools"
New-Item -ItemType Directory -Path $toolDirectory -Force | Out-Null

$currentScriptPath = $MyInvocation.MyCommand.Path
if (-not [string]::IsNullOrWhiteSpace($currentScriptPath) -and
    (Test-Path -LiteralPath $currentScriptPath)) {
    Copy-Item `
        -LiteralPath $currentScriptPath `
        -Destination (Join-Path $toolDirectory "S05-Local-Source-Capability-Extraction-WindowsPS51.ps1") `
        -Force
}

Write-Host ""
Write-Host "S05 local extraction complete."
Write-Host "Branch: $branch"
Write-Host "Commit: $commit"
Write-Host ""
Write-Host "Sources: $($normalizedSources.Count)"
Write-Host "Credentials: $($normalizedCredentials.Count)"
Write-Host "Capabilities: $($normalizedCapabilities.Count)"
Write-Host "Feature flags and entitlements: $($normalizedFeatures.Count)"
Write-Host "Deprecated and sunset evidence rows: $($normalizedDeprecated.Count)"
Write-Host ""
Write-Host "Created S05 JSON, CSV, Markdown, and retained-script outputs."
Write-Host "No application code or secret values were modified."
