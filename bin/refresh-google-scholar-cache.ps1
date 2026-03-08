param(
    [string]$ConfigPath = "_config.yml",
    [string]$BibliographyDir = "_bibliography",
    [string]$OutputPath = "_data/google-scholar-citations.yml"
)

$ErrorActionPreference = "Stop"

function Get-ScholarUserId {
    param([string]$Path)

    $match = Select-String -Path $Path -Pattern '^\s*scholar_userid:\s*([^\s#]+)'
    if (-not $match) {
        throw "Could not find scholar_userid in $Path"
    }

    return $match.Matches[0].Groups[1].Value.Trim()
}

function Get-GoogleScholarIds {
    param([string]$Path)

    $ids = [System.Collections.Generic.HashSet[string]]::new()
    Get-ChildItem -Path $Path -Filter *.bib | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        [regex]::Matches($content, 'google_scholar_id\s*=\s*[{"]([^}"]+)[}"]') | ForEach-Object {
            [void]$ids.Add($_.Groups[1].Value.Trim())
        }
    }

    return @($ids) | Sort-Object
}

function Get-CitationCount {
    param(
        [string]$ScholarUserId,
        [string]$ArticleId
    )

    $url = "https://scholar.google.com/citations?view_op=view_citation&hl=en&user=$ScholarUserId&citation_for_view=$ScholarUserId`:$ArticleId"
    $response = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers @{
        "User-Agent"      = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
        "Accept-Language" = "en-US,en;q=0.9"
        "Cache-Control"   = "no-cache"
        "Pragma"          = "no-cache"
    }

    $text = $response.Content
    $match = [regex]::Match($text, 'Cited by (\d[\d,]*)')
    if ($match.Success) {
        return $match.Groups[1].Value.Replace(",", "")
    }

    if ($text -match 'meta name="description"' -or $text -match 'meta property="og:description"') {
        return "0"
    }

    throw "Could not parse citation count for $ArticleId"
}

$scholarUserId = Get-ScholarUserId -Path $ConfigPath
$articleIds = Get-GoogleScholarIds -Path $BibliographyDir
$cache = [ordered]@{}

foreach ($articleId in $articleIds) {
    $cacheKey = "$scholarUserId`:$articleId"
    Write-Host "Fetching $cacheKey"
    $cache[$cacheKey] = Get-CitationCount -ScholarUserId $scholarUserId -ArticleId $articleId
    Start-Sleep -Seconds 2
}

$yamlLines = @("---")
foreach ($key in $cache.Keys) {
    $yamlLines += "`"$key`": `"$($cache[$key])`""
}

Set-Content -Path $OutputPath -Value $yamlLines
Write-Host "Wrote $OutputPath"
