<#
.SYNOPSIS
  SAMT P06 - Generate RTL Foundation Implementation Targets
  Windows PowerShell 5.1 compatible.

.DESCRIPTION
  Reads the completed P06 preflight CSV files and writes a concise
  implementation-target report. No application code is modified.

.OUTPUTS
  audit/p06-implementation-targets.txt
  audit/tools/P06-Generate-Implementation-Targets-WindowsPS51.ps1
#>

[CmdletBinding()]
param(
    [string]$RepositoryPath = "C:\Projects\worldmonitor",
    [string]$AuditDirectory = "audit"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
Set-Location $repo

if (-not (Test-Path -LiteralPath (Join-Path $repo ".git"))) {
    throw "No .git directory found at $repo"
}

$audit = Join-Path $repo $AuditDirectory

$rootsPath = Join-Path $audit "p06-root-and-style-candidates.csv"
$risksPath = Join-Path $audit "p06-physical-direction-risk.csv"
$testsPath = Join-Path $audit "p06-test-candidates.csv"
$packagePath = Join-Path $repo "package.json"
$reportPath = Join-Path $audit "p06-implementation-targets.txt"
$toolsPath = Join-Path $audit "tools"

foreach ($requiredPath in @(
    $rootsPath,
    $risksPath,
    $testsPath,
    $packagePath
)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required file is missing: $requiredPath"
    }
}

New-Item -ItemType Directory -Path $toolsPath -Force | Out-Null

$roots = @(Import-Csv -LiteralPath $rootsPath)
$risks = @(Import-Csv -LiteralPath $risksPath)
$tests = @(Import-Csv -LiteralPath $testsPath)
$package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json

$excludePaths = "(?i)(^|/)(audit|blog-site|docs?|pro-test|test|tests|e2e|playwright|examples?|fixtures?|mocks?)(/|$)"

$entryPoints = @(
    $roots |
        Where-Object {
            $_.candidateType -match "HTML root|Application entry|Application shell" -and
            $_.filePath -notmatch $excludePaths
        } |
        Sort-Object candidateType, filePath
)

$globalStyles = @(
    $roots |
        Where-Object {
            $_.candidateType -match "Style or layout" -and
            $_.filePath -notmatch $excludePaths -and
            $_.filePath -match "(?i)(global|main|index|app|theme|root|layout|base)"
        } |
        Sort-Object filePath
)

$directionRisks = @(
    $risks |
        Where-Object {
            $_.filePath -notmatch $excludePaths
        } |
        Sort-Object @{
            Expression = { [int]$_.physicalDirectionCount }
            Descending = $true
        }
)

$rtlTests = @(
    $tests |
        Where-Object {
            (
                $_.hasRtlTestEvidence -eq "true" -or
                $_.hasArabicTestEvidence -eq "true" -or
                $_.hasBidirectionalTestEvidence -eq "true"
            ) -and
            $_.filePath -notmatch "(?i)(blog-site|docs?|pro-test)"
        } |
        Sort-Object filePath
)

$relevantScripts = @(
    $package.scripts.PSObject.Properties |
        Where-Object {
            $_.Name -match "(?i)(build|typecheck|test|dom|e2e|visual|lint)"
        } |
        Sort-Object Name
)

$report = New-Object System.Collections.Generic.List[string]

$report.Add("P06 RTL FOUNDATION IMPLEMENTATION TARGETS")
$report.Add("Generated: $((Get-Date).ToString('o'))")
$report.Add("Repository: $repo")
$report.Add("Branch: $((& git branch --show-current 2>&1 | Out-String).Trim())")
$report.Add("Commit: $((& git rev-parse HEAD 2>&1 | Out-String).Trim())")
$report.Add("")

$report.Add("=== COUNTS ===")
$report.Add("Production entry points: $($entryPoints.Count)")
$report.Add("Likely global style files: $($globalStyles.Count)")
$report.Add("Direction-risk files: $($directionRisks.Count)")
$report.Add("Relevant RTL/Arabic tests: $($rtlTests.Count)")
$report.Add("Relevant package scripts: $($relevantScripts.Count)")
$report.Add("")

$report.Add("=== PRODUCTION ENTRY POINTS ===")
$report.Add((
    $entryPoints |
        Format-Table `
            filePath,
            candidateType,
            hasArabicLang,
            hasRtlDirection,
            hasLtrIsolation,
            importsCss,
            hasLocaleState `
            -AutoSize |
        Out-String
).TrimEnd())
$report.Add("")

$report.Add("=== LIKELY GLOBAL STYLE FILES ===")
$report.Add((
    $globalStyles |
        Format-Table `
            filePath,
            hasRtlDirection,
            hasLtrIsolation,
            importsCss `
            -AutoSize |
        Out-String
).TrimEnd())
$report.Add("")

$report.Add("=== DIRECTION-RISK FILES ===")
$report.Add((
    $directionRisks |
        Format-Table `
            filePath,
            physicalDirectionCount,
            logicalPropertyCount,
            priority `
            -AutoSize |
        Out-String
).TrimEnd())
$report.Add("")

$report.Add("=== EXISTING RTL / ARABIC TEST EVIDENCE ===")
$report.Add((
    $rtlTests |
        Format-Table `
            filePath,
            hasRtlTestEvidence,
            hasArabicTestEvidence,
            hasBidirectionalTestEvidence `
            -AutoSize |
        Out-String
).TrimEnd())
$report.Add("")

$report.Add("=== RELEVANT PACKAGE SCRIPTS ===")
$report.Add((
    $relevantScripts |
        Select-Object Name, Value |
        Format-Table -AutoSize |
        Out-String
).TrimEnd())
$report.Add("")

$report.Add("=== IMPLEMENTATION CONSTRAINTS ===")
$report.Add("- Do not redesign or replace the existing operational map shell.")
$report.Add("- Set Arabic language and RTL direction only at the confirmed production root.")
$report.Add("- Add reusable LTR isolation for technical identifiers.")
$report.Add("- Migrate physical CSS only where semantic mirroring is correct.")
$report.Add("- Preserve map, chart, coordinate, and directional behaviors that are intentionally physical.")
$report.Add("- Add bounded automated RTL and bidirectional tests.")
$report.Add("- Keep the preflight artifacts with the final P06 implementation commit.")

[System.IO.File]::WriteAllLines(
    $reportPath,
    $report,
    (New-Object System.Text.UTF8Encoding($false))
)

$currentScript = $MyInvocation.MyCommand.Path

if ($currentScript -and (Test-Path -LiteralPath $currentScript)) {
    Copy-Item `
        -LiteralPath $currentScript `
        -Destination (
            Join-Path $toolsPath "P06-Generate-Implementation-Targets-WindowsPS51.ps1"
        ) `
        -Force
}

Write-Host ""
Write-Host "P06 implementation-target report created."
Write-Host "Report: $reportPath"
Write-Host ""
Write-Host "Production entry points: $($entryPoints.Count)"
Write-Host "Likely global style files: $($globalStyles.Count)"
Write-Host "Direction-risk files: $($directionRisks.Count)"
Write-Host "Relevant RTL/Arabic tests: $($rtlTests.Count)"
Write-Host "Relevant package scripts: $($relevantScripts.Count)"
Write-Host ""
Write-Host "No application code was modified."
