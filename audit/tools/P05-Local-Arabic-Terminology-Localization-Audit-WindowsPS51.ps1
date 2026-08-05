<#
.SYNOPSIS
  SAMT P05 - Arabic Terminology and Localization Audit
  Windows PowerShell 5.1 compatible.

.DESCRIPTION
  Audits the checked-out repository against the controlled SAMT Arabic
  terminology reference. It inventories locale files, measures glossary
  coverage, identifies untranslated/duplicate-label risks, records
  mixed-direction requirements, and inspects date/time/number formatting.

  This is an audit-only work unit:
  - No application code is modified.
  - No locale file is rewritten.
  - No machine translation is introduced.
  - No build, visual, accessibility, or runtime claim is made.

.OUTPUTS
  audit/p05-arabic-terminology-localization-audit.md
  audit/p05-glossary-coverage.csv
  audit/p05-locale-file-inventory.csv
  audit/p05-untranslated-and-duplicate-labels.csv
  audit/p05-mixed-direction-risk.csv
  audit/p05-date-time-number-formatting.csv
  audit/p05-evidence-index.csv
  audit/reference/p05-samt-arabic-terminology.json
  audit/tools/P05-Local-Arabic-Terminology-Localization-Audit-WindowsPS51.ps1
#>

[CmdletBinding()]
param(
    [string]$RepositoryPath = "C:\Projects\worldmonitor",

    [Parameter(Mandatory = $true)]
    [string]$GlossaryJsonPath,

    [string]$AuditDirectory = "audit"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Windows PowerShell 5.1 console and pipeline encoding.
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)

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

function Normalize-Text {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    $normalized = $Value.Normalize([Text.NormalizationForm]::FormKC).ToLowerInvariant()
    $normalized = [regex]::Replace($normalized, '[^\p{L}\p{Nd}]+', '')
    return $normalized
}

function Join-Limited {
    param(
        [string[]]$Values,
        [int]$Limit = 30
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

function Get-LocaleFromPath {
    param([string]$RelativePath)

    $path = $RelativePath.Replace("\", "/")
    $base = [IO.Path]::GetFileNameWithoutExtension($path)

    if ($base -match '^(?i)(ar|ar-AE|ar_AE)$') {
        return "ar"
    }

    if ($base -match '^(?i)(en|en-US|en_GB|en-GB|en_US)$') {
        return "en"
    }

    if ($path -match '(?i)(^|/)(ar|ar-AE|ar_AE)(/|$)') {
        return "ar"
    }

    if ($path -match '(?i)(^|/)(en|en-US|en_GB|en-GB|en_US)(/|$)') {
        return "en"
    }

    return "unknown"
}

function Add-FlatJsonEntries {
    param(
        $Value,
        [string]$KeyPath,
        [string]$SourceFile,
        [string]$Locale,
        [System.Collections.ArrayList]$Target
    )

    if ($null -eq $Value) {
        return
    }

    if ($Value -is [string] -or
        $Value -is [ValueType]) {
        [void]$Target.Add([pscustomobject]@{
            locale = $Locale
            keyPath = $KeyPath
            value = [string]$Value
            sourceFile = $SourceFile
        })
        return
    }

    if ($Value -is [System.Collections.IEnumerable] -and
        -not ($Value -is [string]) -and
        $Value.GetType().IsArray) {
        $index = 0
        foreach ($item in $Value) {
            $childPath = if ([string]::IsNullOrWhiteSpace($KeyPath)) {
                "[$index]"
            }
            else {
                "$KeyPath[$index]"
            }

            Add-FlatJsonEntries `
                -Value $item `
                -KeyPath $childPath `
                -SourceFile $SourceFile `
                -Locale $Locale `
                -Target $Target

            $index += 1
        }

        return
    }

    $properties = @($Value.PSObject.Properties)

    if ($properties.Count -eq 0) {
        [void]$Target.Add([pscustomobject]@{
            locale = $Locale
            keyPath = $KeyPath
            value = [string]$Value
            sourceFile = $SourceFile
        })
        return
    }

    foreach ($property in $properties) {
        $childPath = if ([string]::IsNullOrWhiteSpace($KeyPath)) {
            $property.Name
        }
        else {
            "$KeyPath.$($property.Name)"
        }

        Add-FlatJsonEntries `
            -Value $property.Value `
            -KeyPath $childPath `
            -SourceFile $SourceFile `
            -Locale $Locale `
            -Target $Target
    }
}

function Get-FileMatches {
    param(
        [string[]]$Paths,
        [string]$Pattern
    )

    $matched = @()

    foreach ($relative in $Paths) {
        $content = Read-TextSafe -Path (Join-Path $script:RepoRoot $relative)

        if ($null -eq $content) {
            continue
        }

        if ([regex]::IsMatch($content, $Pattern)) {
            $matched += $relative
        }
    }

    return @($matched | Sort-Object -Unique)
}

$script:RepoRoot = (Resolve-Path -LiteralPath $RepositoryPath).Path
$glossaryResolved = (Resolve-Path -LiteralPath $GlossaryJsonPath).Path

Set-Location $script:RepoRoot

if (-not (Test-Path -LiteralPath (Join-Path $script:RepoRoot ".git"))) {
    throw "No .git directory found at $script:RepoRoot"
}

if (-not (Test-Path -LiteralPath $glossaryResolved)) {
    throw "Glossary JSON not found: $GlossaryJsonPath"
}

$audit = Join-Path $script:RepoRoot $AuditDirectory
$referenceDirectory = Join-Path $audit "reference"
$toolsDirectory = Join-Path $audit "tools"

New-Item -ItemType Directory -Path $audit -Force | Out-Null
New-Item -ItemType Directory -Path $referenceDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $toolsDirectory -Force | Out-Null

$branch = (& git branch --show-current 2>&1 | Out-String).Trim()
$commit = (& git rev-parse HEAD 2>&1 | Out-String).Trim()
$statusBefore = (& git status --short 2>&1 | Out-String).Trim()
$timestamp = Get-Date
$tracked = @(& git ls-files)

$glossaryText = [System.IO.File]::ReadAllText(
    $glossaryResolved,
    [System.Text.Encoding]::UTF8
)

$glossary = $glossaryText | ConvertFrom-Json

$terminology = @($glossary.terminology)
$statusLabels = @($glossary.statusLabels)
$uiLabels = @($glossary.uiLabels)
$domains = @($glossary.domains)
$guidance = @($glossary.guidance)

$localeCandidates = @(
    $tracked |
        Where-Object {
            $path = $_.Replace("\", "/")
            $extension = [IO.Path]::GetExtension($_).ToLowerInvariant()
            $base = [IO.Path]::GetFileNameWithoutExtension($_)

            ($extension -in @(".json", ".ts", ".tsx", ".js", ".jsx", ".yaml", ".yml")) -and
            (
                $path -match '(?i)(^|/)(locales?|i18n|translations?|lang|l10n)(/|$)' -or
                $base -match '^(?i)(ar|ar-AE|ar_AE|en|en-US|en_GB|en-GB|en_US)$'
            )
        } |
        Sort-Object -Unique
)

$flatEntries = New-Object System.Collections.ArrayList
$localeRows = @()

foreach ($relative in $localeCandidates) {
    $full = Join-Path $script:RepoRoot $relative
    $locale = Get-LocaleFromPath -RelativePath $relative
    $extension = [IO.Path]::GetExtension($relative).ToLowerInvariant()
    $content = Read-TextSafe -Path $full
    $parseStatus = "Not parsed"
    $keyCount = 0
    $arabicCharacters = 0
    $latinCharacters = 0
    $hasDirEvidence = $false
    $hasLangEvidence = $false

    if ($null -ne $content) {
        $arabicCharacters = [regex]::Matches($content, '[\u0600-\u06FF]').Count
        $latinCharacters = [regex]::Matches($content, '[A-Za-z]').Count
        $hasDirEvidence = [regex]::IsMatch(
            $content,
            '(?i)\bdir\s*[:=]\s*["'']?(rtl|ltr|auto)'
        )
        $hasLangEvidence = [regex]::IsMatch(
            $content,
            '(?i)\blang\s*[:=]\s*["'']?(ar|ar-AE|en)'
        )
    }

    if ($extension -eq ".json" -and $null -ne $content) {
        try {
            $object = $content | ConvertFrom-Json
            $beforeCount = $flatEntries.Count

            Add-FlatJsonEntries `
                -Value $object `
                -KeyPath "" `
                -SourceFile $relative `
                -Locale $locale `
                -Target $flatEntries

            $keyCount = $flatEntries.Count - $beforeCount
            $parseStatus = "Parsed"
        }
        catch {
            $parseStatus = "JSON parse failed"
        }
    }

    $localeRows += [pscustomobject]@{
        filePath = $relative
        detectedLocale = $locale
        extension = $extension
        parseStatus = $parseStatus
        flattenedKeyCount = $keyCount
        arabicCharacterCount = $arabicCharacters
        latinCharacterCount = $latinCharacters
        hasDirectionEvidence = [string]$hasDirEvidence
        hasLanguageEvidence = [string]$hasLangEvidence
        reviewStatus = "Requires manual localization review"
    }
}

$allLocaleText = @(
    $flatEntries |
        ForEach-Object {
            [pscustomobject]@{
                locale = $_.locale
                keyPath = $_.keyPath
                value = $_.value
                normalizedValue = Normalize-Text -Value $_.value
                sourceFile = $_.sourceFile
            }
        }
)

$englishEntries = @($allLocaleText | Where-Object { $_.locale -eq "en" })
$arabicEntries = @($allLocaleText | Where-Object { $_.locale -eq "ar" })

$referenceTerms = @()

foreach ($row in $terminology) {
    $referenceTerms += [pscustomobject]@{
        referenceType = "Terminology"
        referenceId = [string]$row.ID
        domainOrGroup = [string]$row.'Domain Code'
        english = [string]$row.'English Term'
        preferredArabic = [string]$row.'Preferred Arabic'
        alternateArabic = [string]$row.'Avoid / Alternate'
        direction = [string]$row.Direction
        notes = [string]$row.'UI Usage Guidance'
    }
}

$index = 1
foreach ($row in $statusLabels) {
    $referenceTerms += [pscustomobject]@{
        referenceType = "Status Label"
        referenceId = ("STATUS-{0:D3}" -f $index)
        domainOrGroup = [string]$row.Category
        english = [string]$row.'English Label'
        preferredArabic = [string]$row.'Arabic Label'
        alternateArabic = ""
        direction = "RTL"
        notes = [string]$row.'Definition / Use'
    }

    $index += 1
}

$index = 1
foreach ($row in $uiLabels) {
    $referenceTerms += [pscustomobject]@{
        referenceType = "UI Label"
        referenceId = ("UI-{0:D3}" -f $index)
        domainOrGroup = [string]$row.Group
        english = [string]$row.'English Label'
        preferredArabic = [string]$row.'Preferred Arabic'
        alternateArabic = ""
        direction = "RTL"
        notes = [string]$row.Notes
    }

    $index += 1
}

$coverageRows = @()

foreach ($reference in $referenceTerms) {
    $englishNormalized = Normalize-Text -Value $reference.english
    $preferredNormalized = Normalize-Text -Value $reference.preferredArabic
    $alternateNormalized = Normalize-Text -Value $reference.alternateArabic

    $englishMatches = @(
        $englishEntries |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($englishNormalized) -and
                $_.normalizedValue -eq $englishNormalized
            }
    )

    $preferredMatches = @(
        $arabicEntries |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($preferredNormalized) -and
                $_.normalizedValue -eq $preferredNormalized
            }
    )

    $alternateMatches = @()

    if (-not [string]::IsNullOrWhiteSpace($alternateNormalized)) {
        $alternateMatches = @(
            $arabicEntries |
                Where-Object {
                    $_.normalizedValue -eq $alternateNormalized
                }
        )
    }

    $coverageStatus = if ($preferredMatches.Count -gt 0) {
        "Preferred Arabic found"
    }
    elseif ($alternateMatches.Count -gt 0) {
        "Alternate or avoided Arabic found"
    }
    elseif ($englishMatches.Count -gt 0) {
        "English found; preferred Arabic not found"
    }
    else {
        "No exact locale match found"
    }

    $coverageRows += [pscustomobject]@{
        referenceType = $reference.referenceType
        referenceId = $reference.referenceId
        domainOrGroup = $reference.domainOrGroup
        english = $reference.english
        preferredArabic = $reference.preferredArabic
        alternateArabic = $reference.alternateArabic
        direction = $reference.direction
        englishExactMatchCount = $englishMatches.Count
        preferredArabicExactMatchCount = $preferredMatches.Count
        alternateArabicExactMatchCount = $alternateMatches.Count
        englishFiles = Join-Limited -Values @($englishMatches | ForEach-Object { $_.sourceFile }) -Limit 15
        preferredArabicFiles = Join-Limited -Values @($preferredMatches | ForEach-Object { $_.sourceFile }) -Limit 15
        alternateArabicFiles = Join-Limited -Values @($alternateMatches | ForEach-Object { $_.sourceFile }) -Limit 15
        coverageStatus = $coverageStatus
        notes = $reference.notes
    }
}

$riskRows = @()

foreach ($entry in $arabicEntries) {
    $hasArabic = [regex]::IsMatch($entry.value, '[\u0600-\u06FF]')
    $hasLatin = [regex]::IsMatch($entry.value, '[A-Za-z]')
    $riskType = ""

    if (-not $hasArabic -and $hasLatin) {
        $riskType = "Arabic locale value contains Latin text but no Arabic characters"
    }
    elseif ([string]::IsNullOrWhiteSpace($entry.value)) {
        $riskType = "Empty Arabic locale value"
    }

    if ($riskType) {
        $riskRows += [pscustomobject]@{
            riskType = $riskType
            locale = $entry.locale
            keyPath = $entry.keyPath
            value = $entry.value
            sourceFile = $entry.sourceFile
            relatedKeyOrCount = ""
            reviewStatus = "Requires manual review"
        }
    }
}

$arabicDuplicates = @(
    $arabicEntries |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.normalizedValue)
        } |
        Group-Object normalizedValue |
        Where-Object {
            $_.Count -gt 1
        }
)

foreach ($group in $arabicDuplicates) {
    $distinctKeys = @($group.Group | ForEach-Object { $_.keyPath } | Sort-Object -Unique)

    if ($distinctKeys.Count -le 1) {
        continue
    }

    $riskRows += [pscustomobject]@{
        riskType = "Same Arabic value used by multiple keys"
        locale = "ar"
        keyPath = Join-Limited -Values $distinctKeys -Limit 20
        value = [string]$group.Group[0].value
        sourceFile = Join-Limited -Values @($group.Group | ForEach-Object { $_.sourceFile }) -Limit 15
        relatedKeyOrCount = [string]$distinctKeys.Count
        reviewStatus = "May be valid; requires terminology consistency review"
    }
}

$englishByKey = @{}
foreach ($entry in $englishEntries) {
    if (-not $englishByKey.ContainsKey($entry.keyPath)) {
        $englishByKey[$entry.keyPath] = $entry
    }
}

foreach ($entry in $arabicEntries) {
    if (-not $englishByKey.ContainsKey($entry.keyPath)) {
        continue
    }

    $englishEntry = $englishByKey[$entry.keyPath]

    if (-not [string]::IsNullOrWhiteSpace($entry.normalizedValue) -and
        $entry.normalizedValue -eq $englishEntry.normalizedValue) {
        $riskRows += [pscustomobject]@{
            riskType = "Arabic value equals English value for the same key"
            locale = "ar"
            keyPath = $entry.keyPath
            value = $entry.value
            sourceFile = $entry.sourceFile
            relatedKeyOrCount = $englishEntry.sourceFile
            reviewStatus = "Check whether this is an intentional technical identifier"
        }
    }
}

$textScanExtensions = @(
    ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
    ".json", ".css", ".scss", ".html", ".md"
)

$textScanFiles = @(
    $tracked |
        Where-Object {
            $path = $_.Replace("\", "/").ToLowerInvariant()
            $extension = [IO.Path]::GetExtension($_).ToLowerInvariant()

            ($textScanExtensions -contains $extension) -and
            ($path -notmatch '(^|/)(audit|dist|build|coverage|node_modules)(/|$)') -and
            ($path -notmatch '(^|/)\.env') -and
            ($path -notmatch '(secret|credential|private[-_]?key|password)')
        }
)

$isolationFiles = Get-FileMatches `
    -Paths $textScanFiles `
    -Pattern '(?i)(<bdi\b|dir\s*=\s*["'']ltr["'']|unicode-bidi\s*:|isolation\s*:\s*isolate)'

$mixedDirectionRows = @()

foreach ($reference in $referenceTerms) {
    if ($reference.direction -notmatch '(?i)(ltr|mixed)') {
        continue
    }

    $arabicMatches = @(
        $arabicEntries |
            Where-Object {
                $_.normalizedValue -eq (
                    Normalize-Text -Value $reference.preferredArabic
                )
            }
    )

    $mixedDirectionRows += [pscustomobject]@{
        referenceType = $reference.referenceType
        referenceId = $reference.referenceId
        english = $reference.english
        preferredArabic = $reference.preferredArabic
        directionRequirement = $reference.direction
        localeMatchCount = $arabicMatches.Count
        localeFiles = Join-Limited -Values @($arabicMatches | ForEach-Object { $_.sourceFile }) -Limit 15
        repositoryIsolationEvidenceFiles = Join-Limited -Values $isolationFiles -Limit 30
        status = if ($isolationFiles.Count -gt 0) {
            "Repository has general isolation evidence; item-level verification required"
        }
        else {
            "No static isolation evidence found"
        }
        limitation = "Global isolation evidence does not prove each identifier is rendered correctly."
    }
}

$formatChecks = @(
    @{
        area = "Arabic locale identifier"
        pattern = '(?i)\bar-AE\b|["'']ar["'']'
        expected = "Arabic locale selection"
    },
    @{
        area = "Dubai operational timezone"
        pattern = '(?i)\bAsia/Dubai\b'
        expected = "Asia/Dubai default timezone"
    },
    @{
        area = "UTC option or conversion"
        pattern = '(?i)\bUTC\b|timeZone\s*:\s*["'']UTC["'']'
        expected = "UTC display or conversion"
    },
    @{
        area = "Intl date formatting"
        pattern = '(?i)Intl\.DateTimeFormat'
        expected = "Locale-aware date and time formatting"
    },
    @{
        area = "Intl number formatting"
        pattern = '(?i)Intl\.NumberFormat'
        expected = "Locale-aware number formatting"
    },
    @{
        area = "Locale formatting methods"
        pattern = '(?i)toLocale(DateString|TimeString|String)'
        expected = "Locale-aware formatting methods"
    },
    @{
        area = "Hard-coded date display risk"
        pattern = '(?i)(MM/DD/YYYY|DD/MM/YYYY|YYYY-MM-DD|moment\(|dayjs\()'
        expected = "Manual review of fixed formats and date libraries"
    }
)

$formatRows = @()
$evidenceRows = @()

foreach ($check in $formatChecks) {
    $files = Get-FileMatches `
        -Paths $textScanFiles `
        -Pattern $check.pattern

    $status = if ($files.Count -gt 0) {
        "Static evidence found; implementation review required"
    }
    else {
        "No static evidence found"
    }

    $formatRows += [pscustomobject]@{
        area = $check.area
        expectedEvidence = $check.expected
        status = $status
        filePaths = Join-Limited -Values $files -Limit 30
        runtimeVerificationRequired = "true"
        limitation = "Static text evidence does not prove correct Arabic rendering."
    }

    $evidenceRows += [pscustomobject]@{
        area = $check.area
        claim = $status
        status = $status
        filePath = Join-Limited -Values $files -Limit 25
        symbolOrSection = $check.expected
        verificationMethod = "Deterministic pattern scan of tracked text files"
        limitation = "Runtime and visual verification remain required."
    }
}

$evidenceRows += [pscustomobject]@{
    area = "Controlled terminology reference"
    claim = ("Loaded " + $terminology.Count +
        " terminology rows, " + $statusLabels.Count +
        " status labels, and " + $uiLabels.Count + " UI labels.")
    status = "Loaded successfully"
    filePath = "audit/reference/p05-samt-arabic-terminology.json"
    symbolOrSection = "Controlled SAMT terminology"
    verificationMethod = "JSON extraction from supplied terminology workbook"
    limitation = "Specialist review remains required for high-impact terminology."
}

$coveragePath = Join-Path $audit "p05-glossary-coverage.csv"
$localePath = Join-Path $audit "p05-locale-file-inventory.csv"
$riskPath = Join-Path $audit "p05-untranslated-and-duplicate-labels.csv"
$mixedPath = Join-Path $audit "p05-mixed-direction-risk.csv"
$formatPath = Join-Path $audit "p05-date-time-number-formatting.csv"
$evidencePath = Join-Path $audit "p05-evidence-index.csv"
$reportPath = Join-Path $audit "p05-arabic-terminology-localization-audit.md"

Write-CsvSafe `
    -Rows $coverageRows `
    -Headers @(
        "referenceType","referenceId","domainOrGroup","english",
        "preferredArabic","alternateArabic","direction",
        "englishExactMatchCount","preferredArabicExactMatchCount",
        "alternateArabicExactMatchCount","englishFiles",
        "preferredArabicFiles","alternateArabicFiles",
        "coverageStatus","notes"
    ) `
    -Path $coveragePath

Write-CsvSafe `
    -Rows $localeRows `
    -Headers @(
        "filePath","detectedLocale","extension","parseStatus",
        "flattenedKeyCount","arabicCharacterCount","latinCharacterCount",
        "hasDirectionEvidence","hasLanguageEvidence","reviewStatus"
    ) `
    -Path $localePath

Write-CsvSafe `
    -Rows $riskRows `
    -Headers @(
        "riskType","locale","keyPath","value","sourceFile",
        "relatedKeyOrCount","reviewStatus"
    ) `
    -Path $riskPath

Write-CsvSafe `
    -Rows $mixedDirectionRows `
    -Headers @(
        "referenceType","referenceId","english","preferredArabic",
        "directionRequirement","localeMatchCount","localeFiles",
        "repositoryIsolationEvidenceFiles","status","limitation"
    ) `
    -Path $mixedPath

Write-CsvSafe `
    -Rows $formatRows `
    -Headers @(
        "area","expectedEvidence","status","filePaths",
        "runtimeVerificationRequired","limitation"
    ) `
    -Path $formatPath

Write-CsvSafe `
    -Rows $evidenceRows `
    -Headers @(
        "area","claim","status","filePath","symbolOrSection",
        "verificationMethod","limitation"
    ) `
    -Path $evidencePath

$preferredFound = @(
    $coverageRows |
        Where-Object {
            $_.coverageStatus -eq "Preferred Arabic found"
        }
).Count

$alternateFound = @(
    $coverageRows |
        Where-Object {
            $_.coverageStatus -eq "Alternate or avoided Arabic found"
        }
).Count

$englishOnly = @(
    $coverageRows |
        Where-Object {
            $_.coverageStatus -eq "English found; preferred Arabic not found"
        }
).Count

$noMatch = @(
    $coverageRows |
        Where-Object {
            $_.coverageStatus -eq "No exact locale match found"
        }
).Count

$report = @(
    "# P05 Arabic Terminology and Localization Audit",
    "",
    "## Metadata",
    "",
    "- Timestamp: $($timestamp.ToString('o'))",
    "- Branch: $branch",
    "- Commit: $commit",
    "- Working tree clean at start: $([string]::IsNullOrWhiteSpace($statusBefore))",
    "- Method: controlled glossary comparison and deterministic static repository scan",
    "",
    "## Controlled Reference",
    "",
    "- Terminology rows: $($terminology.Count)",
    "- Status labels: $($statusLabels.Count)",
    "- UI labels: $($uiLabels.Count)",
    "- Domain labels: $($domains.Count)",
    "- Guidance rules: $($guidance.Count)",
    "",
    "## Repository Localization Inventory",
    "",
    "- Locale candidate files: $($localeRows.Count)",
    "- Flattened English locale values: $($englishEntries.Count)",
    "- Flattened Arabic locale values: $($arabicEntries.Count)",
    "",
    "## Exact Glossary Coverage",
    "",
    "- Preferred Arabic found: $preferredFound",
    "- Alternate or avoided Arabic found: $alternateFound",
    "- English found without preferred Arabic: $englishOnly",
    "- No exact locale match found: $noMatch",
    "",
    "Exact string matching is conservative. Missing an exact match does not prove that a concept is absent; contextual and key-level review remains required.",
    "",
    "## Risks",
    "",
    "- Untranslated and duplicate-label risk rows: $($riskRows.Count)",
    "- Mixed/LTR direction reference rows: $($mixedDirectionRows.Count)",
    "- Formatting checks: $($formatRows.Count)",
    "",
    "## Audit Boundary",
    "",
    "No locale file, user-facing string, application component, or runtime configuration was modified.",
    "No machine translation was introduced.",
    "No build, visual, accessibility, screen-reader, or RTL runtime test was executed.",
    "",
    "## Required Manual Review",
    "",
    "- Approve one Arabic term per concept across navigation, tooltips, alerts, briefs, and reports.",
    "- Review every alternate or avoided Arabic match.",
    "- Isolate URLs, source IDs, airport codes, callsigns, registrations, vessel identifiers, stock tickers, coordinates, and technical identifiers.",
    "- Verify Arabic date, time, number, plural, and timezone behavior.",
    "- Preserve original source names and evidence text where required.",
    "- Obtain specialist review for military, legal, health, and financial terminology.",
    "",
    "## Next Work Unit",
    "",
    "After P05 review, commit and phase backup, proceed to P06 RTL foundation."
)

$report |
    Set-Content -LiteralPath $reportPath -Encoding UTF8

$referenceDestination = Join-Path $referenceDirectory "p05-samt-arabic-terminology.json"

Copy-Item `
    -LiteralPath $glossaryResolved `
    -Destination $referenceDestination `
    -Force

$currentScript = $MyInvocation.MyCommand.Path

if (-not [string]::IsNullOrWhiteSpace($currentScript) -and
    (Test-Path -LiteralPath $currentScript)) {
    Copy-Item `
        -LiteralPath $currentScript `
        -Destination (
            Join-Path $toolsDirectory `
                "P05-Local-Arabic-Terminology-Localization-Audit-WindowsPS51.ps1"
        ) `
        -Force
}

Write-Host ""
Write-Host "P05 local audit complete."
Write-Host "Branch: $branch"
Write-Host "Commit: $commit"
Write-Host ""
Write-Host "Locale candidate files: $($localeRows.Count)"
Write-Host "English locale values: $($englishEntries.Count)"
Write-Host "Arabic locale values: $($arabicEntries.Count)"
Write-Host "Glossary reference rows: $($coverageRows.Count)"
Write-Host "Preferred Arabic exact matches: $preferredFound"
Write-Host "Alternate/avoided exact matches: $alternateFound"
Write-Host "Untranslated/duplicate risk rows: $($riskRows.Count)"
Write-Host "Mixed-direction rows: $($mixedDirectionRows.Count)"
Write-Host ""
Write-Host "Created seven P05 audit outputs, retained the glossary JSON, and retained the script."
Write-Host "No application code or user-facing locale file was modified."
