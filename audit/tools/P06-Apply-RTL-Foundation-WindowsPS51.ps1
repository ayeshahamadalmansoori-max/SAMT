<#
.SYNOPSIS
  SAMT P06 - Apply bounded RTL foundation (v3)
  Windows PowerShell 5.1 compatible.

.DESCRIPTION
  Applies an Arabic-first and RTL foundation using the repository's existing
  i18next architecture. This version also cleans the governed partial changes
  created by earlier P06 script attempts.

  Changes:
  - Arabic UAE / RTL first paint in index.html
  - Arabic default detector while preserving URL and explicit user choices
  - Arabic UAE locale mapping
  - Reusable bidirectional helpers
  - Bounded LTR-isolation CSS
  - Focused DOM tests
  - P06 implementation evidence

  It does not redesign the application or globally mirror maps and icons.
#>

[CmdletBinding()]
param(
    [string]$RepositoryPath = "C:\Projects\worldmonitor",
    [string]$AuditDirectory = "audit",
    [switch]$SkipQualityGate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-Utf8 {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.File]::ReadAllText(
        $Path,
        [System.Text.Encoding]::UTF8
    )
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Assert-File {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required file is missing: $Path"
    }
}

function Invoke-NpmGate {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    Write-Host ""
    Write-Host "Running quality gate: $Name"

    & npm.cmd @Arguments
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        throw "Quality gate failed: $Name (exit code $exitCode)"
    }

    Write-Host "Passed: $Name"
}

function Set-HtmlRootArabicRtl {
    param([Parameter(Mandatory = $true)][string]$Html)

    $match = [regex]::Match($Html, '<html\b[^>]*>', 'IgnoreCase')

    if (-not $match.Success) {
        throw "Could not find the html root element in index.html."
    }

    $tag = $match.Value

    if ($tag -match '\blang\s*=') {
        $tag = [regex]::Replace(
            $tag,
            '\blang\s*=\s*["''][^"'']*["'']',
            'lang="ar-AE"',
            'IgnoreCase'
        )
    }
    else {
        $tag = $tag.Insert($tag.Length - 1, ' lang="ar-AE"')
    }

    if ($tag -match '\bdir\s*=') {
        $tag = [regex]::Replace(
            $tag,
            '\bdir\s*=\s*["''][^"'']*["'']',
            'dir="rtl"',
            'IgnoreCase'
        )
    }
    else {
        $tag = $tag.Insert($tag.Length - 1, ' dir="rtl"')
    }

    return $Html.Substring(0, $match.Index) +
        $tag +
        $Html.Substring($match.Index + $match.Length)
}

$repo = (Resolve-Path -LiteralPath $RepositoryPath).Path
Set-Location $repo

if (-not (Test-Path -LiteralPath (Join-Path $repo ".git"))) {
    throw "No .git directory found at $repo"
}

$branch = (& git branch --show-current 2>&1 | Out-String).Trim()
$commitBefore = (& git rev-parse HEAD 2>&1 | Out-String).Trim()
$statusLines = @(& git status --porcelain=v1 --untracked-files=all)

$allowedPathPattern = '^(index\.html|src/main\.ts|src/services/i18n\.ts|src/styles/rtl-overrides\.css|src/bootstrap/samt-rtl\.ts|src/utils/samt-rtl\.ts|tests/dom/samt-rtl-foundation\.test\.mts|audit/p06-|audit/tools/P06-)'

$disallowed = @()

foreach ($lineObject in $statusLines) {
    $line = [string]$lineObject

    if ($line.Length -lt 4) {
        continue
    }

    $path = $line.Substring(3).Replace("\", "/")

    if ($path -notmatch $allowedPathPattern) {
        $disallowed += $line
    }
}

if ($disallowed.Count -gt 0) {
    throw (
        "Working tree contains changes outside the governed P06 scope.`n" +
        ($disallowed -join "`n")
    )
}

$indexPath = Join-Path $repo "index.html"
$mainPath = Join-Path $repo "src\main.ts"
$i18nPath = Join-Path $repo "src\services\i18n.ts"
$rtlCssPath = Join-Path $repo "src\styles\rtl-overrides.css"
$utilityDirectory = Join-Path $repo "src\utils"
$utilityPath = Join-Path $utilityDirectory "samt-rtl.ts"
$oldBootstrapPath = Join-Path $repo "src\bootstrap\samt-rtl.ts"
$testDirectory = Join-Path $repo "tests\dom"
$testPath = Join-Path $testDirectory "samt-rtl-foundation.test.mts"
$audit = Join-Path $repo $AuditDirectory
$tools = Join-Path $audit "tools"
$summaryPath = Join-Path $audit "p06-rtl-foundation-implementation.md"

foreach ($requiredPath in @(
    $indexPath,
    $mainPath,
    $i18nPath,
    $rtlCssPath,
    (Join-Path $repo "package.json")
)) {
    Assert-File -Path $requiredPath
}

New-Item -ItemType Directory -Path $utilityDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $testDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $audit -Force | Out-Null
New-Item -ItemType Directory -Path $tools -Force | Out-Null

$changedFiles = New-Object System.Collections.Generic.List[string]

# ---------------------------------------------------------------------------
# 0. Clean only the governed partial artifacts from earlier P06 attempts.
# ---------------------------------------------------------------------------
$main = Read-Utf8 -Path $mainPath
$cleanMain = $main

$cleanMain = [regex]::Replace(
    $cleanMain,
    '(?m)^\s*import\s+\{\s*initializeSamtRtlFoundation\s*\}\s+from\s+[''"]@/bootstrap/samt-rtl[''"];\s*\r?\n',
    ''
)

$cleanMain = [regex]::Replace(
    $cleanMain,
    '(?m)^\s*initializeSamtRtlFoundation\(\);\s*\r?\n',
    ''
)

if ($cleanMain -ne $main) {
    Write-Utf8NoBom -Path $mainPath -Content $cleanMain
    $changedFiles.Add("src/main.ts (removed obsolete partial P06 wiring)")
}

if (Test-Path -LiteralPath $oldBootstrapPath) {
    $oldBootstrap = Read-Utf8 -Path $oldBootstrapPath

    if ($oldBootstrap -notmatch 'SAMT Arabic-first and bidirectional foundation') {
        throw "src/bootstrap/samt-rtl.ts exists but is not the governed partial P06 file."
    }

    Remove-Item -LiteralPath $oldBootstrapPath -Force
    $changedFiles.Add("src/bootstrap/samt-rtl.ts (removed obsolete partial file)")
}

# ---------------------------------------------------------------------------
# 1. Arabic/RTL first paint.
# ---------------------------------------------------------------------------
$index = Read-Utf8 -Path $indexPath
$updatedIndex = Set-HtmlRootArabicRtl -Html $index

if ($updatedIndex -ne $index) {
    Write-Utf8NoBom -Path $indexPath -Content $updatedIndex
    $changedFiles.Add("index.html")
}

# ---------------------------------------------------------------------------
# 2. Reusable RTL and bidirectional utility.
# ---------------------------------------------------------------------------
$utilityContent = @'
/**
 * SAMT Arabic-first and bidirectional helpers.
 *
 * URLs, source IDs, callsigns, registrations, tickers, airport codes,
 * coordinates, and technical designations must remain LTR.
 */

export const SAMT_DEFAULT_LANGUAGE = 'ar';

const RTL_LANGUAGES = new Set(['ar', 'fa']);

export function normalizeSamtLanguage(language: string | null | undefined): string {
  const normalized = (language || SAMT_DEFAULT_LANGUAGE)
    .trim()
    .split('-')[0]
    ?.toLowerCase();

  return normalized || SAMT_DEFAULT_LANGUAGE;
}

export function applySamtDocumentDirection(language: string): string {
  const normalized = normalizeSamtLanguage(language);
  const isRtl = RTL_LANGUAGES.has(normalized);

  document.documentElement.lang =
    normalized === 'ar' ? 'ar-AE' : normalized === 'zh' ? 'zh-CN' : normalized;

  if (isRtl) {
    document.documentElement.dir = 'rtl';
  } else {
    document.documentElement.removeAttribute('dir');
  }

  document.documentElement.dataset.samtLocale = normalized;
  document.documentElement.dataset.samtDirection = isRtl ? 'rtl' : 'ltr';

  return normalized;
}

export function applyLtrIsolation(element: HTMLElement): HTMLElement {
  element.dir = 'ltr';
  element.dataset.bidi = 'ltr';
  element.classList.add('wm-bidi-ltr');
  return element;
}

export function createLtrIsolate(
  text: string,
  tagName: keyof HTMLElementTagNameMap = 'span',
): HTMLElement {
  const element = document.createElement(tagName);
  element.textContent = text;
  return applyLtrIsolation(element);
}
'@

if (Test-Path -LiteralPath $utilityPath) {
    $existingUtility = Read-Utf8 -Path $utilityPath

    if ($existingUtility -notmatch 'SAMT Arabic-first and bidirectional helpers') {
        throw "src/utils/samt-rtl.ts already exists but is not the governed P06 utility."
    }
}

Write-Utf8NoBom -Path $utilityPath -Content ($utilityContent + "`n")
$changedFiles.Add("src/utils/samt-rtl.ts")

# ---------------------------------------------------------------------------
# 3. Integrate Arabic default into the existing i18next architecture.
# ---------------------------------------------------------------------------
$i18n = Read-Utf8 -Path $i18nPath
$updatedI18n = $i18n

$utilityImport = "import { applySamtDocumentDirection } from '@/utils/samt-rtl';"

if ($updatedI18n -notmatch [regex]::Escape($utilityImport)) {
    $importAnchorPattern = "(?m)^(import\s+\{\s*readQueryLanguage,\s*stripQueryLanguage\s*\}\s+from\s+['""]@/utils/i18n-url['""];)\s*$"
    $importMatch = [regex]::Match($updatedI18n, $importAnchorPattern)

    if (-not $importMatch.Success) {
        throw "Could not find the i18n URL import anchor in src/services/i18n.ts."
    }

    $replacement = $importMatch.Groups[1].Value + "`n" + $utilityImport
    $updatedI18n = $updatedI18n.Remove($importMatch.Index, $importMatch.Length).Insert(
        $importMatch.Index,
        $replacement
    )
}

$directionFunctionPattern = '(?s)function\s+applyDocumentDirection\(lang:\s*string\):\s*void\s*\{.*?\}\s*(?=async\s+function\s+ensureLanguageLoaded)'

$directionReplacement = @'
function applyDocumentDirection(lang: string): void {
  applySamtDocumentDirection(lang);
}

'@

if ($updatedI18n -notmatch 'applySamtDocumentDirection\(lang\);') {
    $directionMatch = [regex]::Match($updatedI18n, $directionFunctionPattern)

    if (-not $directionMatch.Success) {
        throw "Could not find applyDocumentDirection() in src/services/i18n.ts."
    }

    $updatedI18n = $updatedI18n.Remove(
        $directionMatch.Index,
        $directionMatch.Length
    ).Insert(
        $directionMatch.Index,
        $directionReplacement
    )
}

if ($updatedI18n -notmatch "name:\s*'wmDefault'") {
    $awaitAnchor = "  await i18next"

    $anchorIndex = $updatedI18n.IndexOf($awaitAnchor)

    if ($anchorIndex -lt 0) {
        throw "Could not find the i18next initialization anchor."
    }

    $defaultDetector = @'
  detector.addDetector({
    name: 'wmDefault',
    lookup: () => 'ar',
    cacheUserLanguage: () => { /* Arabic-first fallback is not an explicit user choice */ },
  });

'@

    $updatedI18n = $updatedI18n.Insert($anchorIndex, $defaultDetector)
}

$detectionOrderPattern = "order:\s*\[[^\]]*\]"

if ($updatedI18n -notmatch "order:\s*\['wmQuery',\s*'wmExplicit',\s*'wmDefault'\]") {
    $orderMatch = [regex]::Match($updatedI18n, $detectionOrderPattern)

    if (-not $orderMatch.Success) {
        throw "Could not find the language detector order."
    }

    $updatedI18n = $updatedI18n.Remove(
        $orderMatch.Index,
        $orderMatch.Length
    ).Insert(
        $orderMatch.Index,
        "order: ['wmQuery', 'wmExplicit', 'wmDefault']"
    )
}

if ($updatedI18n -notmatch "ar:\s*'ar-AE'") {
    $mapPattern = "const\s+map:\s*Record<string,\s*string>\s*=\s*\{"
    $mapMatch = [regex]::Match($updatedI18n, $mapPattern)

    if (-not $mapMatch.Success) {
        throw "Could not find getLocale() locale map in src/services/i18n.ts."
    }

    $insertPosition = $mapMatch.Index + $mapMatch.Length
    $updatedI18n = $updatedI18n.Insert($insertPosition, " ar: 'ar-AE',")
}

if ($updatedI18n -ne $i18n) {
    Write-Utf8NoBom -Path $i18nPath -Content $updatedI18n
    $changedFiles.Add("src/services/i18n.ts")
}

# ---------------------------------------------------------------------------
# 4. Bounded LTR-isolation CSS in the existing RTL stylesheet.
# ---------------------------------------------------------------------------
$rtlCss = Read-Utf8 -Path $rtlCssPath
$cssMarker = "/* SAMT P06 BIDIRECTIONAL ISOLATION */"

if ($rtlCss -notmatch [regex]::Escape($cssMarker)) {
    $cssBlock = @'

/* SAMT P06 BIDIRECTIONAL ISOLATION */
/*
 * Apply to non-translatable technical identifiers inside RTL content.
 * Directional icons and map controls are intentionally not mirrored globally.
 */
.wm-bidi-ltr,
[data-bidi='ltr'] {
  direction: ltr;
  unicode-bidi: isolate;
  text-align: start;
}

.wm-bidi-auto,
[data-bidi='auto'] {
  direction: auto;
  unicode-bidi: plaintext;
  text-align: start;
}

/* Opt-in mirroring only for controls whose meaning truly reverses in RTL. */
[dir='rtl'] .wm-mirror-in-rtl {
  transform: scaleX(-1);
}
'@

    Write-Utf8NoBom -Path $rtlCssPath -Content ($rtlCss.TrimEnd() + "`n" + $cssBlock + "`n")
    $changedFiles.Add("src/styles/rtl-overrides.css")
}

# ---------------------------------------------------------------------------
# 5. Focused DOM tests.
# ---------------------------------------------------------------------------
$testContent = @'
import { beforeEach, describe, expect, it } from 'vitest';

import {
  applyLtrIsolation,
  applySamtDocumentDirection,
  createLtrIsolate,
  normalizeSamtLanguage,
} from '../../src/utils/samt-rtl';

describe('SAMT RTL foundation', () => {
  beforeEach(() => {
    document.documentElement.removeAttribute('lang');
    document.documentElement.removeAttribute('dir');
    delete document.documentElement.dataset.samtLocale;
    delete document.documentElement.dataset.samtDirection;
  });

  it('normalizes Arabic regional codes', () => {
    expect(normalizeSamtLanguage('ar-AE')).toBe('ar');
  });

  it('applies Arabic UAE language and RTL direction', () => {
    const language = applySamtDocumentDirection('ar');

    expect(language).toBe('ar');
    expect(document.documentElement.lang).toBe('ar-AE');
    expect(document.documentElement.dir).toBe('rtl');
    expect(document.documentElement.dataset.samtDirection).toBe('rtl');
  });

  it('removes RTL direction for English', () => {
    applySamtDocumentDirection('ar');
    applySamtDocumentDirection('en');

    expect(document.documentElement.lang).toBe('en');
    expect(document.documentElement.hasAttribute('dir')).toBe(false);
    expect(document.documentElement.dataset.samtDirection).toBe('ltr');
  });

  it('isolates technical identifiers as LTR', () => {
    const element = applyLtrIsolation(document.createElement('span'));

    expect(element.dir).toBe('ltr');
    expect(element.dataset.bidi).toBe('ltr');
    expect(element.classList.contains('wm-bidi-ltr')).toBe(true);
  });

  it('preserves an identifier without translation or reordering', () => {
    const value = 'A6-EWB / 25.2048, 55.2708';
    const element = createLtrIsolate(value, 'code');

    expect(element.tagName).toBe('CODE');
    expect(element.textContent).toBe(value);
    expect(element.dir).toBe('ltr');
  });
});
'@

if (Test-Path -LiteralPath $testPath) {
    $existingTest = Read-Utf8 -Path $testPath

    if ($existingTest -notmatch "describe\('SAMT RTL foundation'") {
        throw "tests/dom/samt-rtl-foundation.test.mts already exists but is not the governed P06 test."
    }
}

Write-Utf8NoBom -Path $testPath -Content ($testContent + "`n")
$changedFiles.Add("tests/dom/samt-rtl-foundation.test.mts")

# ---------------------------------------------------------------------------
# 6. Quality gates.
# ---------------------------------------------------------------------------
$qualityResults = New-Object System.Collections.Generic.List[string]

if ($SkipQualityGate) {
    $qualityResults.Add("Skipped by operator")
}
else {
    Invoke-NpmGate -Name "typecheck" -Arguments @("run", "typecheck")
    $qualityResults.Add("npm run typecheck: passed")

    Invoke-NpmGate -Name "targeted DOM RTL test" -Arguments @(
        "run",
        "test:dom",
        "--",
        "tests/dom/samt-rtl-foundation.test.mts"
    )
    $qualityResults.Add("targeted DOM RTL test: passed")

    Invoke-NpmGate -Name "DOM test typecheck" -Arguments @(
        "run",
        "typecheck:dom-tests"
    )
    $qualityResults.Add("npm run typecheck:dom-tests: passed")
}

# ---------------------------------------------------------------------------
# 7. Implementation evidence.
# ---------------------------------------------------------------------------
$summaryLines = New-Object System.Collections.Generic.List[string]
$summaryLines.Add("# P06 RTL Foundation Implementation")
$summaryLines.Add("")
$summaryLines.Add("## Metadata")
$summaryLines.Add("")
$summaryLines.Add("- Timestamp: $((Get-Date).ToString('o'))")
$summaryLines.Add("- Branch: $branch")
$summaryLines.Add("- Base commit: $commitBefore")
$summaryLines.Add("")
$summaryLines.Add("## Implemented")
$summaryLines.Add("")
$summaryLines.Add("- Arabic UAE and RTL attributes for initial document paint.")
$summaryLines.Add("- Arabic-first default through the existing i18next detector chain.")
$summaryLines.Add("- Preservation of explicit user-selected and URL-selected languages.")
$summaryLines.Add("- Reusable LTR isolation for technical identifiers.")
$summaryLines.Add("- Bounded RTL CSS with opt-in icon mirroring.")
$summaryLines.Add("- Arabic UAE locale mapping.")
$summaryLines.Add("- Focused DOM tests for direction and bidirectional isolation.")
$summaryLines.Add("")
$summaryLines.Add("## Quality Gates")
$summaryLines.Add("")

foreach ($qualityResult in $qualityResults) {
    $summaryLines.Add("- $qualityResult")
}

$summaryLines.Add("")
$summaryLines.Add("## Scope Boundary")
$summaryLines.Add("")
$summaryLines.Add("P06 does not redesign the dashboard, translate every label, replace map behavior, or mechanically mirror every physical left/right declaration.")
$summaryLines.Add("")
$summaryLines.Add("## Rollback")
$summaryLines.Add("")
$summaryLines.Add('```powershell')
$summaryLines.Add("git restore -- index.html src/main.ts src/services/i18n.ts src/styles/rtl-overrides.css")
$summaryLines.Add("Remove-Item src/utils/samt-rtl.ts -Force")
$summaryLines.Add("Remove-Item tests/dom/samt-rtl-foundation.test.mts -Force")
$summaryLines.Add("Remove-Item audit/p06-rtl-foundation-implementation.md -Force")
$summaryLines.Add('```')

Write-Utf8NoBom -Path $summaryPath -Content (($summaryLines -join "`n") + "`n")

$currentScript = $MyInvocation.MyCommand.Path

if ($currentScript -and (Test-Path -LiteralPath $currentScript)) {
    Copy-Item `
        -LiteralPath $currentScript `
        -Destination (Join-Path $tools "P06-Apply-RTL-Foundation-WindowsPS51.ps1") `
        -Force
}

Write-Host ""
Write-Host "P06 RTL foundation implementation applied." -ForegroundColor Green
Write-Host "Branch: $branch"
Write-Host "Base commit: $commitBefore"
Write-Host ""
Write-Host "Quality gates:"
foreach ($qualityResult in $qualityResults) {
    Write-Host "  $qualityResult"
}
Write-Host ""
Write-Host "Do not commit until git diff and localhost are reviewed."
