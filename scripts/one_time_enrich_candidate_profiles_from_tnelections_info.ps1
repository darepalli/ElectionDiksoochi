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

function Get-CandidateNameFromPartyObject($party, [string]$lang) {
    $display = ''
    if ($party.name -and $party.name.$lang) { $display = [string]$party.name.$lang }
    elseif ($party.name -and $party.name.en) { $display = [string]$party.name.en }
    elseif ($party.short -and $party.short.$lang) { $display = [string]$party.short.$lang }
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

function Get-PartyProfileUrl([string]$partyCode) {
    switch (([string]$partyCode).ToUpperInvariant()) {
        'DMK' { 'https://www.tnelections.info/parties#dmk' }
        'AIADMK' { 'https://www.tnelections.info/parties#aiadmk' }
        'BJP' { 'https://www.tnelections.info/parties#bjp' }
        'TVK' { 'https://www.tnelections.info/parties#tvk' }
        'NTK' { 'https://www.tnelections.info/parties#ntk' }
        default { '' }
    }
}

# Constituency mapping: local number -> source constituency_id
$sourceConstituencies = Invoke-RestMethod -Uri "$base/constituencies?select=id,constituency_number,name&limit=1000" -Headers $headers -Method Get
$sourceConstIdByNo = @{}
foreach ($c in $sourceConstituencies) {
    $no = [int]$c.constituency_number
    if ($no -gt 0) { $sourceConstIdByNo[$no] = [int]$c.id }
}

# Fetch source candidates with pagination
$candidates = @()
$offset = 0
$batch = 1000
while ($true) {
    $uri = "$base/candidates?select=name,party,constituency_id,election_year,affidavit_url,is_winner,is_incumbent,assembly_attendance_pct,questions_asked,debates_count&limit=$batch&offset=$offset"
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

$meta = Get-Content "elections/tn/constituencies/constituencies.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$noBySlug = @{}
foreach ($c in $meta.constituencies) { $noBySlug[[string]$c.slug] = [int]$c.no }

$configFiles = Get-ChildItem "elections/tn/constituencies" -Recurse -Filter "config.json"
$updatedFiles = 0
$updatedCandidateProfiles = 0
$updatedPartyProfiles = 0

foreach ($file in $configFiles) {
    $slug = Split-Path (Split-Path $file.DirectoryName -Leaf) -Leaf
    if (-not $noBySlug.ContainsKey($slug)) { continue }
    $no = [int]$noBySlug[$slug]
    if (-not $sourceConstIdByNo.ContainsKey($no)) { continue }
    $sourceCid = [int]$sourceConstIdByNo[$no]
    $seatCandidates = if ($byConst.ContainsKey($sourceCid)) { @($byConst[$sourceCid]) } else { @() }

    $o = Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $o.parties) { continue }

    $localUpdated = $false

    foreach ($party in $o.parties) {
        $partyCode = Get-PartyCodeFromPartyObject $party
        $candidateName = Get-CandidateNameFromPartyObject $party 'en'
        $candidateNorm = Normalize-Text $candidateName

        $isMalformedAlias = (([string]$party.alias) -match '^cand-$' -or -not [string]$party.alias)
        if ($isMalformedAlias -and $party.candidateProfile) {
            $party.PSObject.Properties.Remove('candidateProfile')
            $localUpdated = $true
        }

        if ($isMalformedAlias) {
            $partyProfile = Get-PartyProfileUrl $partyCode
            if ($partyProfile) {
                if (-not $party.partyProfile) {
                    $party | Add-Member -NotePropertyName partyProfile -NotePropertyValue ([pscustomobject]@{ en = $partyProfile; ta = $partyProfile }) -Force
                    $updatedPartyProfiles++
                    $localUpdated = $true
                }
            }
            continue
        }

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

            # High-confidence guard: require exact name, or loose name with party match.
            if (-not $exactName) {
                $hasPartyMatch = ($partyCode -and $rowParty -and $partyCode -eq $rowParty)
                if (-not ($looseName -and $hasPartyMatch)) { continue }
            }

            if ($score -gt $bestScore) {
                $bestScore = $score
                $best = $row
            }
        }

        if ($best -and $bestScore -ge 7 -and $best.affidavit_url) {
            $candUrl = [string]$best.affidavit_url
            if (-not $party.candidateProfile) {
                $party | Add-Member -NotePropertyName candidateProfile -NotePropertyValue ([pscustomobject]@{ en = $candUrl; ta = $candUrl }) -Force
            } else {
                $party.candidateProfile.en = $candUrl
                $party.candidateProfile.ta = $candUrl
            }
            $updatedCandidateProfiles++
            $localUpdated = $true

            $perfParts = @()
            if ($best.assembly_attendance_pct -ne $null) { $perfParts += ("Assembly attendance: " + [string]$best.assembly_attendance_pct + "%") }
            if ($best.questions_asked -ne $null) { $perfParts += ("Questions asked: " + [string]$best.questions_asked) }
            if ($best.debates_count -ne $null) { $perfParts += ("Debates: " + [string]$best.debates_count) }

            if ($perfParts.Count -gt 0) {
                $perfText = ($perfParts -join " | ")
                if (-not $party.description) {
                    $party | Add-Member -NotePropertyName description -NotePropertyValue ([pscustomobject]@{ en = $perfText; ta = $perfText }) -Force
                } elseif (-not ([string]$party.description.en).Contains('Assembly attendance:')) {
                    $party.description.en = (([string]$party.description.en).Trim() + ' Past performance: ' + $perfText).Trim()
                    $party.description.ta = (([string]$party.description.ta).Trim() + ' Past performance: ' + $perfText).Trim()
                }
            }
        }

        $partyProfile = Get-PartyProfileUrl $partyCode
        if ($partyProfile) {
            if (-not $party.partyProfile) {
                $party | Add-Member -NotePropertyName partyProfile -NotePropertyValue ([pscustomobject]@{ en = $partyProfile; ta = $partyProfile }) -Force
                $updatedPartyProfiles++
                $localUpdated = $true
            } else {
                $cur = if ($party.partyProfile.en) { [string]$party.partyProfile.en } else { '' }
                if (-not $cur -or $cur -match 'wikipedia\.org|tnelections\.info/parties') {
                    $party.partyProfile.en = $partyProfile
                    $party.partyProfile.ta = $partyProfile
                    $updatedPartyProfiles++
                    $localUpdated = $true
                }
            }
        }
    }

    if ($localUpdated) {
        if ($o.PSObject.Properties.Name -contains 'candidateSourceNote') {
            if ($o.candidateSourceNote -notmatch 'candidate profiles mapped from tnelections.info Supabase') {
                $o.candidateSourceNote = "$($o.candidateSourceNote) Candidate profiles mapped from tnelections.info Supabase candidates table (one-time run)."
            }
        } else {
            $o | Add-Member -NotePropertyName candidateSourceNote -NotePropertyValue 'Candidate profiles mapped from tnelections.info Supabase candidates table (one-time run).' -Force
        }

        $jsonOut = $o | ConvertTo-Json -Depth 100
        [System.IO.File]::WriteAllText($file.FullName, $jsonOut, (New-Object System.Text.UTF8Encoding($false)))
        $updatedFiles++
    }
}

Write-Output "updated_files=$updatedFiles updated_candidate_profiles=$updatedCandidateProfiles updated_party_profiles=$updatedPartyProfiles source_candidates=$($candidates.Count)"
