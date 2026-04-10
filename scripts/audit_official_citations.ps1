$ErrorActionPreference = "Stop"
Set-Location "d:\Ravi\Project\india-election-compass"

$officialHostPattern = '(^|\.)eci\.gov\.in$|(^|\.)ceotamilnadu\.nic\.in$|(^|\.)myneta\.info$|(^|\.)affidavitarchive\.myneta\.info$|(^|\.)tnsec\.tn\.gov\.in$'

function Get-HostSafe([string]$url) {
    try {
        return ([uri]$url).Host.ToLowerInvariant()
    } catch {
        return ''
    }
}

function Get-UrlListFromText([string]$text) {
    $matches = [regex]::Matches($text, 'https?://[^\s"\'']+')
    $urls = New-Object System.Collections.Generic.HashSet[string]
    foreach ($m in $matches) {
        $u = $m.Value.TrimEnd('.', ',', ')', ']')
        if ($u) { [void]$urls.Add($u) }
    }
    return @($urls)
}

$configFiles = Get-ChildItem "elections/tn/constituencies" -Recurse -Filter "config.json"
$lacking = New-Object System.Collections.Generic.List[object]
$withOfficial = 0
$hostCounts = @{}

foreach ($f in $configFiles) {
    $raw = Get-Content $f.FullName -Raw -Encoding UTF8
    $urls = Get-UrlListFromText $raw

    $officialUrls = @()
    $nonOfficialUrls = @()

    foreach ($u in $urls) {
        $urlHost = Get-HostSafe $u
        if (-not $urlHost) { continue }
        if ($urlHost -match $officialHostPattern) {
            $officialUrls += $u
        } else {
            $nonOfficialUrls += $u
            if (-not $hostCounts.ContainsKey($urlHost)) { $hostCounts[$urlHost] = 0 }
            $hostCounts[$urlHost] += 1
        }
    }

    $slug = Split-Path (Split-Path $f.DirectoryName -Leaf) -Leaf

    if ($officialUrls.Count -gt 0) {
        $withOfficial++
        continue
    }

    $sampleHosts = @($nonOfficialUrls | ForEach-Object { Get-HostSafe $_ } | Where-Object { $_ } | Sort-Object -Unique)
    $lacking.Add([pscustomobject]@{
        slug = $slug
        path = $f.FullName
        urlCount = $urls.Count
        sampleHosts = ($sampleHosts -join ', ')
    })
}

$total = $configFiles.Count
$lackingSorted = @($lacking | Sort-Object slug)
$topHosts = @($hostCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10)

$reportPath = "scripts/official_citation_audit.md"
$lines = @()
$lines += "# Official Citation Audit"
$lines += ""
$lines += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$lines += ""
$lines += "Official hosts considered: eci.gov.in, ceotamilnadu.nic.in, tnsec.tn.gov.in, myneta.info"
$lines += ""
$lines += "Summary"
$lines += "- Total constituency config files scanned: $total"
$lines += "- Constituencies with at least one official citation URL: $withOfficial"
$lines += "- Constituencies lacking any official citation URL: $($lackingSorted.Count)"
$lines += ""
$lines += "Top non-official hosts (by URL occurrences in scanned files)"
if ($topHosts.Count -eq 0) {
    $lines += "- None"
} else {
    foreach ($h in $topHosts) {
        $lines += "- $($h.Key): $($h.Value)"
    }
}
$lines += ""
$lines += "## Constituencies Lacking Official Citations"
if ($lackingSorted.Count -eq 0) {
    $lines += "- None"
} else {
    foreach ($row in $lackingSorted) {
        $relPath = $row.path.Replace((Get-Location).Path + '\\', '').Replace('\\', '/')
        $lines += "- $($row.slug) | urls=$($row.urlCount) | hosts=$($row.sampleHosts) | path=$relPath"
    }
}

[System.IO.File]::WriteAllLines($reportPath, $lines, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "audit_report=$reportPath total=$total with_official=$withOfficial lacking=$($lackingSorted.Count)"