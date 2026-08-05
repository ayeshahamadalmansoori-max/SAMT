[CmdletBinding()]
param(
    [string]$RepositoryPath = (Get-Location).Path,
    [string]$AuditDirectory = "audit"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-TextSafe {
    param([string]$Path)
    try { Get-Content -LiteralPath $Path -Raw -ErrorAction Stop }
    catch { $null }
}

function Join-Limited {
    param([string[]]$Values,[int]$Limit = 25)
    $items = @($Values | Where-Object { $_ } | Sort-Object -Unique)
    if ($items.Count -le $Limit) { return ($items -join ";") }
    return ((@($items | Select-Object -First $Limit) -join ";") + ";...+" + ($items.Count - $Limit) + " more")
}

function Write-CsvSafe {
    param([object[]]$Rows,[string[]]$Headers,[string]$Path)
    if ($Rows.Count -gt 0) {
        $Rows | Select-Object $Headers | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
    } else {
        ($Headers -join ",") | Set-Content -LiteralPath $Path -Encoding UTF8
    }
}

$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
Set-Location $repo

if (-not (Test-Path (Join-Path $repo ".git"))) { throw "No .git directory found." }
if (-not (Test-Path (Join-Path $repo "package.json"))) { throw "package.json not found." }

$audit = Join-Path $repo $AuditDirectory
New-Item -ItemType Directory -Path $audit -Force | Out-Null

$branch = (& git branch --show-current 2>&1 | Out-String).Trim()
$commit = (& git rev-parse HEAD 2>&1 | Out-String).Trim()
$statusBefore = (& git status --short 2>&1 | Out-String).Trim()
$tracked = @(& git ls-files)
$timestamp = Get-Date

$textExtensions = @(".ts",".tsx",".js",".jsx",".mjs",".cjs",".css",".scss",".sass",".less",".html",".json",".yaml",".yml",".md")
$scanFiles = @($tracked | Where-Object {
    $relativePath = [string]$_
    if ([string]::IsNullOrWhiteSpace($relativePath)) { return $false }

    $p = $relativePath.Replace("\","/").ToLowerInvariant()
    $extensionValue = [System.IO.Path]::GetExtension($relativePath)
    $ext = if ($null -eq $extensionValue) { "" } else { ([string]$extensionValue).ToLowerInvariant() }

    ($textExtensions -contains $ext) -and
    ($p -notmatch '(^|/)(audit|dist|build|coverage|node_modules)(/|$)') -and
    ($p -notmatch '(^|/)\.env') -and
    ($p -notmatch '(secret|credential|private[-_]?key|password)')
})

$componentFiles = @($tracked | Where-Object {
    $relativePath = [string]$_
    if ([string]::IsNullOrWhiteSpace($relativePath)) { return $false }

    $p = $relativePath.Replace("\","/")
    $extensionValue = [System.IO.Path]::GetExtension($relativePath)
    $ext = if ($null -eq $extensionValue) { "" } else { ([string]$extensionValue).ToLowerInvariant() }

    ($ext -in @(".tsx",".jsx",".vue",".svelte",".html")) -and
    ($p -match '(?i)(^|/)(components?|ui|views?|pages?|layouts?|panels?|widgets?)(/|$)') -and
    ($p -notmatch '(?i)(^|/)(test|tests|e2e|playwright|fixtures?|mocks?)(/|$)')
} | Sort-Object -Unique)

$componentRows = @()
foreach ($rel in $componentFiles) {
    $content = Read-TextSafe (Join-Path $repo $rel)
    if ($null -eq $content) { continue }

    $componentRows += [pscustomobject]@{
        component = [IO.Path]::GetFileNameWithoutExtension($rel)
        filePath = $rel
        hasArabicText = ([regex]::IsMatch($content,'[\u0600-\u06FF]')).ToString().ToLowerInvariant()
        hasAria = ([regex]::IsMatch($content,'(?i)\baria-[a-z-]+\s*=')).ToString().ToLowerInvariant()
        hasRole = ([regex]::IsMatch($content,'(?i)\brole\s*=')).ToString().ToLowerInvariant()
        hasKeyboardHandler = ([regex]::IsMatch($content,'(?i)(onKeyDown|onKeyUp|onKeyPress|keydown|keyup)')).ToString().ToLowerInvariant()
        hasDirAttribute = ([regex]::IsMatch($content,'(?i)\bdir\s*=\s*["''](?:rtl|ltr|auto)["'']')).ToString().ToLowerInvariant()
        hasLangAttribute = ([regex]::IsMatch($content,'(?i)\blang\s*=\s*["''](?:ar|ar-AE|en)["'']')).ToString().ToLowerInvariant()
        hasBdiOrIsolation = ([regex]::IsMatch($content,'(?i)(<bdi\b|unicode-bidi|isolation:\s*isolate|dir\s*=\s*["'']ltr["''])')).ToString().ToLowerInvariant()
        reviewStatus = "Requires manual component and visual review"
    }
}

$tokenRows = @()
$tokenSeen = @{}
foreach ($rel in $scanFiles) {
    $extensionValue = [System.IO.Path]::GetExtension([string]$rel)
    $ext = if ($null -eq $extensionValue) { "" } else { ([string]$extensionValue).ToLowerInvariant() }
    if ($ext -notin @(".css",".scss",".sass",".less",".ts",".tsx",".js",".jsx",".html")) { continue }
    $content = Read-TextSafe (Join-Path $repo $rel)
    if ($null -eq $content) { continue }

    $defs = @(
        @{type="CSS custom property";rx='(?m)(--[A-Za-z0-9_-]+)\s*:'},
        @{type="Font family declaration";rx='(?im)font-family\s*:\s*([^;\r\n]+)'},
        @{type="Hex colour";rx='(?i)(#[0-9a-f]{3,8})\b'},
        @{type="Border radius";rx='(?im)border-radius\s*:\s*([^;\r\n]+)'}
    )

    foreach ($d in $defs) {
        foreach ($m in [regex]::Matches($content,$d.rx)) {
            $value = $m.Groups[1].Value.Trim()
            if (-not $value) { continue }
            $key = ([string]($d.type + "|" + $value + "|" + $rel)).ToLowerInvariant()
            if ($tokenSeen.ContainsKey($key)) { continue }
            $tokenSeen[$key] = $true

            $tokenRows += [pscustomobject]@{
                tokenOrValue = $value
                tokenType = $d.type
                filePath = $rel
                officialMappingStatus = "Not yet mapped to approved UAE Design System token"
                rtlImpact = if ($value -match '(?i)(left|right)') { "Physical-direction value; review for RTL" } else { "Requires review" }
                notes = "Static extraction only"
            }
        }
    }
}

$checks = @(
    @{area="Arabic application root";pattern='(?i)(lang\s*=\s*["'']ar(?:-AE)?["'']|document\.documentElement\.lang\s*=\s*["'']ar)';expected="Arabic root language declaration"},
    @{area="RTL application root";pattern='(?i)(dir\s*=\s*["'']rtl["'']|document\.documentElement\.dir\s*=\s*["'']rtl|direction\s*:\s*rtl)';expected="RTL root or layout direction"},
    @{area="Bidirectional isolation";pattern='(?i)(<bdi\b|unicode-bidi\s*:|isolation\s*:\s*isolate|dir\s*=\s*["'']ltr["''])';expected="LTR isolation for mixed-direction values"},
    @{area="Logical CSS properties";pattern='(?i)\b(margin|padding|inset|border)-(inline|block)(?:-start|-end)?\b|\btext-align\s*:\s*(start|end)';expected="Logical layout properties"},
    @{area="Physical left/right CSS";pattern='(?i)\b(margin-left|margin-right|padding-left|padding-right|left\s*:|right\s*:|border-left|border-right|text-align\s*:\s*(left|right))';expected="Potential RTL migration risk"},
    @{area="Arabic locale formatting";pattern='(?i)(ar-AE|Intl\.(DateTimeFormat|NumberFormat)\s*\(\s*["'']ar|toLocale(Date|Time|String)\s*\(\s*["'']ar)';expected="Arabic locale-aware formatting"},
    @{area="Dubai timezone";pattern='(?i)Asia/Dubai';expected="Operational timezone indicator"},
    @{area="Reduced motion";pattern='(?i)(prefers-reduced-motion|useReducedMotion)';expected="Reduced-motion support"},
    @{area="Visible focus";pattern='(?i)(:focus-visible|focus-visible)';expected="Visible keyboard focus support"},
    @{area="Responsive media queries";pattern='(?i)@media\s*\(';expected="Responsive behavior"},
    @{area="Accessible labels";pattern='(?i)(aria-label|aria-labelledby|aria-describedby|<label\b)';expected="Accessible names and labels"}
)

$rtlRows = @()
$evidenceRows = @()

foreach ($check in $checks) {
    $matching = @()
    $count = 0

    foreach ($rel in $scanFiles) {
        $content = Read-TextSafe (Join-Path $repo $rel)
        if ($null -eq $content) { continue }
        $matches = [regex]::Matches($content,$check.pattern)
        if ($matches.Count -gt 0) {
            $matching += $rel
            $count += $matches.Count
        }
    }

    $status = if ($matching.Count -gt 0) {
        "Static evidence found; requires manual and runtime verification"
    } else {
        "No evidence found in static scan"
    }

    $rtlRows += [pscustomobject]@{
        area = $check.area
        expectedEvidence = $check.expected
        status = $status
        occurrenceCount = $count
        filePaths = Join-Limited $matching 30
        limitation = "Static text scan does not prove correct rendered behavior."
    }

    $evidenceRows += [pscustomobject]@{
        area = $check.area
        claim = if ($matching.Count -gt 0) { "Static evidence found." } else { "No matching static evidence found." }
        status = $status
        filePath = Join-Limited $matching 25
        symbolOrSection = $check.expected
        verificationMethod = "Deterministic scan of tracked text files"
        limitation = "Visual, keyboard, screen-reader, and bidirectional correctness require runtime testing."
    }
}

Write-CsvSafe $componentRows @(
    "component","filePath","hasArabicText","hasAria","hasRole","hasKeyboardHandler",
    "hasDirAttribute","hasLangAttribute","hasBdiOrIsolation","reviewStatus"
) (Join-Path $audit "p04-component-inventory.csv")

Write-CsvSafe $tokenRows @(
    "tokenOrValue","tokenType","filePath","officialMappingStatus","rtlImpact","notes"
) (Join-Path $audit "p04-token-and-theme-inventory.csv")

Write-CsvSafe $rtlRows @(
    "area","expectedEvidence","status","occurrenceCount","filePaths","limitation"
) (Join-Path $audit "p04-rtl-readiness-matrix.csv")

Write-CsvSafe $evidenceRows @(
    "area","claim","status","filePath","symbolOrSection","verificationMethod","limitation"
) (Join-Path $audit "p04-evidence-index.csv")

@(
    "# P04 UAE Design System and RTL Readiness Audit",
    "",
    "## Metadata",
    "",
    "- Timestamp: $($timestamp.ToString('o'))",
    "- Branch: $branch",
    "- Commit: $commit",
    "- Working tree clean at start: $([string]::IsNullOrWhiteSpace($statusBefore))",
    "- Method: deterministic static repository audit",
    "",
    "## Counts",
    "",
    "- Candidate UI components: $($componentRows.Count)",
    "- Token and theme evidence rows: $($tokenRows.Count)",
    "- RTL/accessibility readiness checks: $($rtlRows.Count)",
    "",
    "## Audit Boundary",
    "",
    "This work unit does not modify UI code and does not claim visual, RTL, accessibility, responsive, or official design-system compliance.",
    "",
    "## Required Manual Verification",
    "",
    "- Confirm approved UAE Design System package, version, licence, and component compatibility.",
    "- Map current colours, typography, spacing, radii, focus, and interaction tokens to approved equivalents.",
    "- Verify Arabic root language and RTL behavior in the real application.",
    "- Verify LTR isolation for identifiers and technical values.",
    "- Test widths 1920, 1440, 1024, 768, and 390 pixels.",
    "- Test keyboard, focus, screen readers, reduced motion, charts, and map alternatives.",
    "- Keep official identity assets as placeholders until authorization and supplied files exist.",
    "",
    "## Build and Test Status",
    "",
    "No build, visual, accessibility, browser, or runtime test was executed by this script."
) | Set-Content (Join-Path $audit "p04-uae-design-system-audit.md") -Encoding UTF8

@(
    "# P04 Gaps and Extension Rules",
    "",
    "## Gaps",
    "",
    "1. Official UAE Design System package and version require verification.",
    "2. Existing tokens are not yet mapped to approved UAE Design System tokens.",
    "3. Arabic-first and RTL behavior require rendered application testing.",
    "4. Physical left/right CSS declarations require review.",
    "5. Mixed-direction identifiers require explicit isolation.",
    "6. Accessibility cannot be inferred from static attributes alone.",
    "7. Official identity assets must remain placeholders until authorization.",
    "",
    "## Extension Rules",
    "",
    "- Extend approved components only when intelligence requirements are not covered.",
    "- Map extensions to approved tokens.",
    "- Preserve provenance, freshness, confidence, source health, permissions, and limitations.",
    "- Do not communicate status through colour alone.",
    "- Avoid blocking modals over the operational map.",
    "- Use contextual drawers on desktop and bottom sheets on mobile.",
    "- Provide accessible non-map alternatives.",
    "- Do not introduce decorative controls without working behavior."
) | Set-Content (Join-Path $audit "p04-gaps-and-extension-rules.md") -Encoding UTF8

$toolDir = Join-Path $audit "tools"
New-Item -ItemType Directory -Path $toolDir -Force | Out-Null
$currentScript = $MyInvocation.MyCommand.Path
if ($currentScript -and (Test-Path $currentScript)) {
    Copy-Item $currentScript (Join-Path $toolDir "P04-Local-UAE-Design-System-RTL-Audit-WindowsPS51.ps1") -Force
}

Write-Host ""
Write-Host "P04 local audit complete."
Write-Host "Branch: $branch"
Write-Host "Commit: $commit"
Write-Host "Candidate UI components: $($componentRows.Count)"
Write-Host "Token/theme evidence rows: $($tokenRows.Count)"
Write-Host "RTL/accessibility checks: $($rtlRows.Count)"
Write-Host "Created six P04 audit files and retained the script."
Write-Host "No application code or secret values were modified."
