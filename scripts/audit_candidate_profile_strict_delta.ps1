$ErrorActionPreference = "Stop"
Set-Location "d:\Ravi\Project\india-election-compass"

$base = "https://ljbewpsksaetftwuaqaz.supabase.co/rest/v1"
$key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxqYmV3cHNrc2FldGZ0d3VhcWF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MTkzMTAsImV4cCI6MjA4OTQ5NTMxMH0.uX-cnXxHFXXBUed-B9j-02qQriYRuYihiOgiU9E_-CM"
$headers = @{ 'apikey' = $key; 'Authorization' = "Bearer $key" }

function Normalize-Text([string]$text) {
    return (([string]$text).ToLowerInvariant() -replace '[^a-z0-9\s]', ' ' -replace '\s+', ' ').Trim()
}

function Get-PartyCodeFromAlias([string]$alias) {
    $a = [string]$alias
    if ($a -match '^cand-([a-z0-9()\-]+)$') {
        $code = $Matches[1].ToUpperInvariant()
        if ($code -eq 'ADMK') { return 'AIADMK' }
        return $code
    }
    switch ($a.ToLowerInvariant()) {
        'dmk-alliance' { 'DMK' }
        'aiadmk-alliance' { 'AIADMK' }
        'bjp-alliance' { 'BJP' }
        'tvk' { 'TVK' }
        default { '' }
    }
}

function Normalize-PartyCodeFromSource([string]$partyRaw) {
    $p = ([string]$partyRaw).Trim().ToUpperInvariant()
    if (-not $p) { return '' }
    if ($p -match '^AIADMK|ALL INDIA ANNA') { return 'AIADMK' }
    if ($p -eq 'ADMK') { return 'AIADMK' }
    if ($p -match '^DMK|DRAVIDA MUNNETRA') { return 'DMK' }
    if ($p -match '^BJP|BHARATIYA JANATA') { return 'BJP' }
    if ($p -match '^TVK|TAMILAGA VETRI') { return 'TVK' }
    if ($p -match '^PMK|PATTALI') { return 'PMK' }
    if ($p -match '^DMDK|DESIYA MURPOKKU') { return 'DMDK' }
    if ($p -match '^INC|INDIAN NATIONAL CONGRESS|CONGRESS') { return 'INC' }
    if ($p -match '^CPI\(M\)|CPM|COMMUNIST PARTY OF INDIA \(MARXIST\)') { return 'CPM' }
    if ($p -match '^CPI|COMMUNIST PARTY OF INDIA$') { return 'CPI' }
    if ($p -match '^VCK|VIDUTHALAI') { return 'VCK' }
    if ($p -match '^MDMK|MARUMALARCHI') { return 'MDMK' }
    if ($p -match '^NTK|NAAM TAM') { return 'NTK' }
    if ($p -match '^AMMK|AMMA MAKKAL') { return 'AMMK' }
    if ($p -match '^IND|INDEPENDENT') { return 'IND' }
    return $p
}

function Get-PartyCodeFromPartyObject($party) {
    $fromAlias = Get-PartyCodeFromAlias ([string]$party.alias)
    if ($fromAlias) { return $fromAlias }

    $nameEn = ''
    if ($party.name -and $party.name.en) { $nameEn = [string]$party.name.en }
    if (-not $nameEn -and $party.short -and $party.short.en) { $nameEn = [string]$party.short.en }
    if ($nameEn -match '\(([^\)]+)\)') {
        return Normalize-PartyCodeFromSource $Matches[1]
    }
    return ''
}

function Get-CandidateNameFromPartyObject($party) {
    $display = ''
    if ($party.name -and $party.name.en) { $display = [string]$party.name.en }
    elseif ($party.short -and $party.short.en) { $display = [string]$party.short.en }
    else { $display = [string]$party.alias }

    if ($display -match '^(.*?)\s*\(([^\)]+)\)\s*$') {
        return ($Matches[1].Trim())
    }
    if ($display -match '^(.*?)\s*/\s*([A-Za-z()]+)\s*$') {
        return ($Matches[1].Trim())
    }
    return $display.Trim()
}

function Get-MatchResult($party, $seatCandidates, [bool]$strictMode) {
    $alias = [string]$party.alias
    $isMalformedAlias = ($alias -match '^cand-$' -or -not $alias)
    if ($strictMode -and $isMalformedAlias) {
        return $null
    }

    $partyCode = Get-PartyCodeFromPartyObject $party
    $candidateName = Get-CandidateNameFromPartyObject $party
    $candidateNorm = Normalize-Text $candidateName

    $best = $null
    $bestScore = -1

    foreach ($row in $seatCandidates) {
        $nameNorm = Normalize-Text ([string]$row.name)
        if (-not $nameNorm) { continue }

        $score = 0
        $exactName = $false
        $looseName = $false
        if ($nameNorm -eq $candidateNorm) { $score += 7; $exactName = $true }
        elseif ($nameNorm -like "*$candidateNorm*" -or $candidateNorm -like "*$nameNorm*") { $score += 3; $looseName = $true }

        $rowParty = Normalize-PartyCodeFromSource ([string]$row.party)
        if ($partyCode -and $rowParty) {
            if ($partyCode -eq $rowParty) { $score += 5 }
            else { continue }
        }

        $yr = [int]$row.election_year
        $score += [Math]::Max(0, ($yr - 2000)) / 100.0
        if ($row.is_winner -eq $true) { $score += 0.5 }
        if ($row.is_incumbent -eq $true) { $score += 0.5 }

        if ($strictMode) {
            if (-not $exactName) {
                $hasPartyMatch = ($partyCode -and $rowParty -and $partyCode -eq $rowParty)
                if (-not ($looseName -and $hasPartyMatch)) { continue }
            }
        }

        if ($score -gt $bestScore) {
            $bestScore = $score
            $best = $row
        }
    }

    $threshold = if ($strictMode) { 7 } else { 6 }
    if ($best -and $bestScore -ge $threshold -and $best.affidavit_url) {
        return [pscustomobject]@{
            url = [string]$best.affidavit_url
            score = $bestScore
        }
    }
    return $null
}

# Constituency number mapping
$meta = Get-Content "elections/tn/constituencies/constituencies.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$noBySlug = @{}
foreach ($c in $meta.constituencies) { $noBySlug[[string]$c.slug] = [int]$c.no }

# Source constituency mapping
$sourceConstituencies = Invoke-RestMethod -Uri "$base/constituencies?select=id,constituency_number,name&limit=1000" -Headers $headers -Method Get
$sourceConstIdByNo = @{}
foreach ($c in $sourceConstituencies) {
    $no = [int]$c.constituency_number
    if ($no -gt 0) { $sourceConstIdByNo[$no] = [int]$c.id }
}

# Source candidates
$candidates = @()
$offset = 0
$batch = 1000
while ($true) {
    $uri = "$base/candidates?select=name,party,constituency_id,election_year,affidavit_url,is_winner,is_incumbent&limit=$batch&offset=$offset"
    $rows = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    if (-not $rows -or @($rows).Count -eq 0) { break }
    $candidates += @($rows)
    if (@($rows).Count -lt $batch) { break }
    $offset += $batch
}

$byConst = @{}
foreach ($r in $candidates) {
    $cid = [int]$r.constituency_id
    if ($cid -le 0) { continue }
    if (-not $byConst.ContainsKey($cid)) { $byConst[$cid] = @() }
    $byConst[$cid] += $r
}

$gained = New-Object System.Collections.Generic.List[string]
$lost = New-Object System.Collections.Generic.List[string]

$configFiles = Get-ChildItem "elections/tn/constituencies" -Recurse -Filter "config.json"
foreach ($file in $configFiles) {
    $slug = Split-Path (Split-Path $file.DirectoryName -Leaf) -Leaf
    if (-not $noBySlug.ContainsKey($slug)) { continue }
    $no = [int]$noBySlug[$slug]
    if (-not $sourceConstIdByNo.ContainsKey($no)) { continue }
    $sourceCid = [int]$sourceConstIdByNo[$no]
    $seatCandidates = if ($byConst.ContainsKey($sourceCid)) { @($byConst[$sourceCid]) } else { @() }

    $o = Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $o.parties) { continue }

    $broadAssigned = $false
    $strictAssigned = $false

    foreach ($party in $o.parties) {
        $broadMatch = Get-MatchResult -party $party -seatCandidates $seatCandidates -strictMode:$false
        $strictMatch = Get-MatchResult -party $party -seatCandidates $seatCandidates -strictMode:$true
        if ($broadMatch) { $broadAssigned = $true }
        if ($strictMatch) { $strictAssigned = $true }
    }

    if ($strictAssigned -and -not $broadAssigned) {
        $gained.Add("$no | $slug")
    } elseif ($broadAssigned -and -not $strictAssigned) {
        $lost.Add("$no | $slug")
    }
}

$gainedSorted = @($gained | Sort-Object)
$lostSorted = @($lost | Sort-Object)

$reportPath = "scripts/candidate_profile_strict_rerun_audit.md"
$lines = @()
$lines += "# Candidate Profile Strict Rerun Audit"
$lines += ""
$lines += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$lines += ""
$lines += "Comparison baseline: simulated broad matcher (threshold >= 6, no malformed-alias strict skip)"
$lines += "Comparison target: strict matcher (threshold >= 7 + malformed-alias skip + high-confidence guard)"
$lines += ""
$lines += "Summary"
$lines += "- Constituencies gained in strict rerun: $($gainedSorted.Count)"
$lines += "- Constituencies lost in strict rerun: $($lostSorted.Count)"
$lines += ""
$lines += "## Gained"
if ($gainedSorted.Count -eq 0) {
    $lines += "- None"
} else {
    foreach ($entry in $gainedSorted) { $lines += "- $entry" }
}
$lines += ""
$lines += "## Lost"
if ($lostSorted.Count -eq 0) {
    $lines += "- None"
} else {
    foreach ($entry in $lostSorted) { $lines += "- $entry" }
}

[System.IO.File]::WriteAllLines($reportPath, $lines, (New-Object System.Text.UTF8Encoding($false)))

Write-Output "audit_report=$reportPath gained=$($gainedSorted.Count) lost=$($lostSorted.Count)"