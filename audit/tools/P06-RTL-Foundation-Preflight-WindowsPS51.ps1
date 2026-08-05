<#
.SYNOPSIS
  SAMT P06 Step 1 - RTL Foundation Preflight
  Windows PowerShell 5.1 compatible.

.DESCRIPTION
  Inspects the checked-out repository to identify the exact files that must be
  changed for the P06 RTL foundation. This script does not modify application
  code. It creates only preflight evidence under audit/.

.OUTPUTS
  audit/p06-rtl-foundation-preflight.md
  audit/p06-root-and-style-candidates.csv
  audit/p06-physical-direction-risk.csv
  audit/p06-test-candidates.csv
  audit/tools/P06-RTL-Foundation-Preflight-WindowsPS51.ps1
#>

[CmdletBinding()]
param(
    [string]$RepositoryPath = "C:\Projects\worldmonitor",
    [string]$AuditDirectory = "audit"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-TextSafe {
    param([string]$Path)

    try {
        return [System.IO.File]::ReadAllText(
            $Path,
            [System.Text.Encoding]::UTF8
        )
    }
    catch {
        return $null
    }
}

function Write-CsvSafe {
    param(
        [object[]]$Rows,
        [string[]]$Headers,
        [string]$Path
    )

    if ($Rows.Count -gt 0) {
        $Rows |
            Select-Object $Headers |
            Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
    }
    else {
        ($Headers -join ",") |
            Set-Content -LiteralPath $Path -Encoding UTF8
    }
}

function Join-Limited {
    param(
        [string[]]$Values,
        [int]$Limit = 25
    )

    $items = @(
        $Values |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )

    if ($items.Count -le $Limit) {
        return ($items -join ";")
    }

    return ((@($items | Select-Object -First $Limit) -join ";") +
        ";...+" + ($items.Count - $Limit) + " more")
}

$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
Set-Location $repo

if (-not (Test-Path -LiteralPath (Join-Path $repo ".git"))) {
    throw "No .git directory found at $repo"
}

$packagePath = Join-Path $repo "package.json"
if (-not (Test-Path -LiteralPath $packagePath)) {
    throw "package.json not found at $repo"
}

$audit = Join-Path $repo $AuditDirectory
$tools = Join-Path $audit "tools"

New-Item -ItemType Directory -Path $audit -Force | Out-Null
New-Item -ItemType Directory -Path $tools -Force | Out-Null

$branch = (& git branch --show-current 2>&1 | Out-String).Trim()
$commit = (& git rev-parse HEAD 2>&1 | Out-String).Trim()
$statusBefore = (& git status --short 2>&1 | Out-String).Trim()
$tracked = @(& git ls-files)
$timestamp = Get-Date

if (-not [string]::IsNullOrWhiteSpace($statusBefore)) {
    throw "Working tree is not clean. Commit or restore changes before P06 preflight.`n$statusBefore"
}

$package = Get-Content -LiteralPath $packagePath -Raw |
    ConvertFrom-Json

$scriptNames = @($package.scripts.PSObject.Properties.Name)
$dependencyNames = @()

foreach ($groupName in @(
    "dependencies",
    "devDependencies",
    "peerDependencies",
    "optionalDependencies"
)) {
    $groupProperty = $package.PSObject.Properties[$groupName]

    if ($null -eq $groupProperty -or $null -eq $groupProperty.Value) {
        continue
    }

    $dependencyNames += @(
        $groupProperty.Value.PSObject.Properties.Name
    )
}

$rootRows = @()
$candidateFiles = @(
    $tracked |
        Where-Object {
            $path = $_.Replace("\", "/")
            $extension = [IO.Path]::GetExtension($_).ToLowerInvariant()

            (
                $path -match '(?i)(^|/)(index\.html|main\.(ts|tsx|js|jsx)|app\.(ts|tsx|js|jsx))$' -or
                $path -match '(?i)(^|/)(styles?|css|theme|tokens?|layout|shell|i18n|locale|locales)(/|$)' -or
                $extension -in @(".css", ".scss", ".sass", ".less")
            ) -and
            ($path -notmatch '(?i)(^|/)(audit|dist|build|coverage|node_modules)(/|$)')
        } |
        Sort-Object -Unique
)

foreach ($relative in $candidateFiles) {
    $full = Join-Path $repo $relative
    $content = Read-TextSafe -Path $full

    if ($null -eq $content) {
        continue
    }

    $kind = if ($relative -match '(?i)index\.html$') {
        "HTML root candidate"
    }
    elseif ($relative -match '(?i)(^|/)main\.(ts|tsx|js|jsx)$') {
        "Application entry candidate"
    }
    elseif ($relative -match '(?i)(^|/)app\.(ts|tsx|js|jsx)$') {
        "Application shell candidate"
    }
    elseif ($relative -match '(?i)(styles?|css|theme|tokens?|layout|shell)') {
        "Style or layout candidate"
    }
    elseif ($relative -match '(?i)(i18n|locale|locales)') {
        "Localization candidate"
    }
    else {
        "Candidate"
    }

    $rootRows += [pscustomobject]@{
        filePath = $relative
        candidateType = $kind
        hasArabicLang = (
            [regex]::IsMatch(
                $content,
                '(?i)(lang\s*=\s*["'']ar(?:-AE)?["'']|document\.documentElement\.lang\s*=\s*["'']ar)'
            )
        ).ToString().ToLowerInvariant()
        hasRtlDirection = (
            [regex]::IsMatch(
                $content,
                '(?i)(dir\s*=\s*["'']rtl["'']|document\.documentElement\.dir\s*=\s*["'']rtl|direction\s*:\s*rtl)'
            )
        ).ToString().ToLowerInvariant()
        hasLtrIsolation = (
            [regex]::IsMatch(
                $content,
                '(?i)(<bdi\b|dir\s*=\s*["'']ltr["'']|unicode-bidi\s*:|isolation\s*:\s*isolate)'
            )
        ).ToString().ToLowerInvariant()
        importsCss = (
            [regex]::IsMatch(
                $content,
                '(?im)^\s*import\s+["''][^"'']+\.(css|scss|sass|less)["'']'
            )
        ).ToString().ToLowerInvariant()
        hasLocaleState = (
            [regex]::IsMatch(
                $content,
                '(?i)(locale|language|i18n|setLanguage|currentLanguage)'
            )
        ).ToString().ToLowerInvariant()
        reviewStatus = "Requires manual P06 target confirmation"
    }
}

$styleFiles = @(
    $tracked |
        Where-Object {
            $extension = [IO.Path]::GetExtension($_).ToLowerInvariant()
            $path = $_.Replace("\", "/")

            ($extension -in @(".css", ".scss", ".sass", ".less", ".tsx", ".jsx")) -and
            ($path -notmatch '(?i)(^|/)(audit|dist|build|coverage|node_modules)(/|$)')
        } |
        Sort-Object -Unique
)

$physicalPattern = '(?i)\b(margin-left|margin-right|padding-left|padding-right|border-left|border-right|left\s*:|right\s*:|text-align\s*:\s*(left|right))'
$logicalPattern = '(?i)\b(margin|padding|inset|border)-(inline|block)(?:-start|-end)?\b|\btext-align\s*:\s*(start|end)'
$riskRows = @()

foreach ($relative in $styleFiles) {
    $content = Read-TextSafe -Path (Join-Path $repo $relative)

    if ($null -eq $content) {
        continue
    }

    $physicalCount = [regex]::Matches(
        $content,
        $physicalPattern
    ).Count

    $logicalCount = [regex]::Matches(
        $content,
        $logicalPattern
    ).Count

    if ($physicalCount -eq 0 -and $logicalCount -eq 0) {
        continue
    }

    $riskRows += [pscustomobject]@{
        filePath = $relative
        physicalDirectionCount = $physicalCount
        logicalPropertyCount = $logicalCount
        priority = if ($physicalCount -ge 25) {
            "High"
        }
        elseif ($physicalCount -gt 0) {
            "Medium"
        }
        else {
            "Low"
        }
        action = if ($physicalCount -gt 0) {
            "Review and migrate only where semantic mirroring is correct"
        }
        else {
            "Logical-property evidence found"
        }
    }
}

$testFiles = @(
    $tracked |
        Where-Object {
            $_ -match '(?i)(\.test\.|\.spec\.|(^|/)(test|tests|e2e|playwright)(/|$))'
        } |
        Sort-Object -Unique
)

$testRows = @()

foreach ($relative in $testFiles) {
    $content = Read-TextSafe -Path (Join-Path $repo $relative)

    if ($null -eq $content) {
        continue
    }

    $testRows += [pscustomobject]@{
        filePath = $relative
        hasRtlTestEvidence = (
            [regex]::IsMatch(
                $content,
                '(?i)(\brtl\b|dir\s*=\s*["'']rtl|direction\s*:\s*rtl)'
            )
        ).ToString().ToLowerInvariant()
        hasArabicTestEvidence = (
            [regex]::IsMatch(
                $content,
                '[\u0600-\u06FF]|\bar-AE\b'
            )
        ).ToString().ToLowerInvariant()
        hasBidirectionalTestEvidence = (
            [regex]::IsMatch(
                $content,
                '(?i)(<bdi\b|dir\s*=\s*["'']ltr|unicode-bidi|isolation)'
            )
        ).ToString().ToLowerInvariant()
        suggestedUse = "Assess for extension or add bounded P06 RTL tests"
    }
}

$rootPath = Join-Path $audit "p06-root-and-style-candidates.csv"
$riskPath = Join-Path $audit "p06-physical-direction-risk.csv"
$testPath = Join-Path $audit "p06-test-candidates.csv"
$reportPath = Join-Path $audit "p06-rtl-foundation-preflight.md"

Write-CsvSafe `
    -Rows $rootRows `
    -Headers @(
        "filePath","candidateType","hasArabicLang","hasRtlDirection",
        "hasLtrIsolation","importsCss","hasLocaleState","reviewStatus"
    ) `
    -Path $rootPath

Write-CsvSafe `
    -Rows $riskRows `
    -Headers @(
        "filePath","physicalDirectionCount","logicalPropertyCount",
        "priority","action"
    ) `
    -Path $riskPath

Write-CsvSafe `
    -Rows $testRows `
    -Headers @(
        "filePath","hasRtlTestEvidence","hasArabicTestEvidence",
        "hasBidirectionalTestEvidence","suggestedUse"
    ) `
    -Path $testPath

$rtlDependencies = @(
    $dependencyNames |
        Where-Object {
            $_ -match '(?i)(i18n|intl|locale|rtl|arabic|formatjs|lingui|react-intl)'
        } |
        Sort-Object -Unique
)

$relevantScripts = @(
    $scriptNames |
        Where-Object {
            $_ -match '(?i)(test|typecheck|build|lint|e2e|visual|dom)'
        } |
        Sort-Object -Unique
)

$highRiskFiles = @(
    $riskRows |
        Sort-Object `
            @{ Expression = { [int]$_.physicalDirectionCount }; Descending = $true } |
        Select-Object -First 20
)

$dependencySection = if ($rtlDependencies.Count -gt 0) {
    "- " + ($rtlDependencies -join "`n- ")
}
else {
    "- No explicit RTL/i18n dependency name detected in package.json."
}

$scriptSection = if ($relevantScripts.Count -gt 0) {
    "- " + ($relevantScripts -join "`n- ")
}
else {
    "- No relevant script names detected."
}

$report = @(
    "# P06 RTL Foundation Preflight"
    ""
    "## Metadata"
    ""
    "- Timestamp: $($timestamp.ToString('o'))"
    "- Branch: $branch"
    "- Commit: $commit"
    "- Working tree clean at start: True"
    "- Method: deterministic local repository inspection"
    ""
    "## Purpose"
    ""
    "Identify the exact application root, layout, style, localization, and test files for a bounded P06 implementation."
    "This preflight does not modify application code."
    ""
    "## Counts"
    ""
    "- Root/style/localization candidates: $($rootRows.Count)"
    "- Files with physical or logical direction evidence: $($riskRows.Count)"
    "- Existing test candidates: $($testRows.Count)"
    ""
    "## Relevant Dependencies"
    ""
    $dependencySection
    ""
    "## Relevant Package Scripts"
    ""
    $scriptSection
    ""
    "## Highest Physical-Direction Risk Files"
    ""
)

foreach ($row in $highRiskFiles) {
    $report += (
        "- " + $row.filePath +
        " — physical=" + $row.physicalDirectionCount +
        ", logical=" + $row.logicalPropertyCount
    )
}

$report += @(
    "",
    "## P06 Implementation Boundary",
    "",
    "The implementation should remain limited to:",
    "",
    "- Arabic application-root language and RTL direction behavior.",
    "- Reusable direction and bidirectional-isolation primitives.",
    "- Logical layout foundations where safe.",
    "- A bounded set of representative components.",
    "- RTL and mixed-direction automated tests.",
    "",
    "Do not redesign information architecture, replace the map shell, remove capabilities, or translate every interface string in P06.",
    "",
    "## Required Next Action",
    "",
    "Review the three generated CSV files and identify the actual production root, global styles, representative components, and test framework before applying the P06 code patch."
)

$report |
    Set-Content -LiteralPath $reportPath -Encoding UTF8

$currentScript = $MyInvocation.MyCommand.Path

if ($currentScript -and (Test-Path -LiteralPath $currentScript)) {
    Copy-Item `
        -LiteralPath $currentScript `
        -Destination (
            Join-Path $tools "P06-RTL-Foundation-Preflight-WindowsPS51.ps1"
        ) `
        -Force
}

Write-Host ""
Write-Host "P06 RTL foundation preflight complete."
Write-Host "Branch: $branch"
Write-Host "Commit: $commit"
Write-Host ""
Write-Host "Root/style/localization candidates: $($rootRows.Count)"
Write-Host "Direction-risk files: $($riskRows.Count)"
Write-Host "Test candidates: $($testRows.Count)"
Write-Host ""
Write-Host "Created four preflight files and retained the script."
Write-Host "No application code was modified."
