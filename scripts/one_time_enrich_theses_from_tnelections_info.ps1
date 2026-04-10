$ErrorActionPreference = "Stop"
Set-Location "d:\Ravi\Project\india-election-compass"

$base = "https://ljbewpsksaetftwuaqaz.supabase.co/rest/v1"
$key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxqYmV3cHNrc2FldGZ0d3VhcWF6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MTkzMTAsImV4cCI6MjA4OTQ5NTMxMH0.uX-cnXxHFXXBUed-B9j-02qQriYRuYihiOgiU9E_-CM"
$headers = @{ 'apikey' = $key; 'Authorization' = "Bearer $key" }

function Get-PartyCodeFromAlias([string]$alias) {
    $a = [string]$alias
    if ($a -match '^cand-([a-z0-9()\-]+)$') {
        $code = $Matches[1].ToUpperInvariant()
        if ($code -eq 'AIADMK') { return 'AIADMK' }
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

function Get-CategoryFromThesis([string]$titleEn) {
    $t = ([string]$titleEn).ToLowerInvariant()
    if ($t -match 'women|girl|mother|female') { return 'women' }
    if ($t -match 'education|school|college|student|university') { return 'education' }
    if ($t -match 'health|hospital|medical|clinic|doctor|disease') { return 'healthcare' }
    if ($t -match 'job|employment|industry|startup|msme|economy|business|investment') { return 'employment' }
    if ($t -match 'agri|farm|farmer|irrigation|crop|paddy|livestock|dairy') { return 'agriculture' }
    if ($t -match 'fisher|marine|coast|boat') { return 'fisheries' }
    if ($t -match 'labour|worker|wage|gig|auto driver|construction') { return 'labour' }
    if ($t -match 'housing|house|slum|patta|home') { return 'housing' }
    if ($t -match 'culture|language|temple|heritage|tourism|tamil') { return 'culture' }
    if ($t -match 'environment|climate|river|forest|pollution|water body') { return 'environment' }
    if ($t -match 'sport|stadium|athlete') { return 'sports' }
    if ($t -match 'govern|corruption|transparency|service|police|digital|administration') { return 'governance' }
    if ($t -match 'welfare|pension|allowance|social|disabled|minority|tribal') { return 'social_welfare' }
    if ($t -match 'cash|subsidy|free\s+electricity|free\s+lpg|transfer') { return 'cash_benefits' }
    if ($t -match 'road|bus|transport|metro|drain|sewer|electric|power|infrastructure') { return 'infrastructure' }
    return ''
}

function Get-BelievabilityWeight([string]$label) {
    switch (([string]$label).ToLowerInvariant()) {
        'very likely' { 2.0 }
        'likely' { 1.5 }
        'uncertain' { 0.5 }
        'unlikely' { -0.5 }
        'not announced' { -1.0 }
        default { 0.0 }
    }
}

function Get-PositionFromScore([double]$score) {
    if ($score -ge 2.0) { return 'strongly-approve' }
    if ($score -ge 1.0) { return 'approve' }
    if ($score -le -1.5) { return 'strongly-reject' }
    if ($score -le -0.5) { return 'reject' }
    return 'neutral'
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

$promises = Invoke-RestMethod -Uri "$base/manifesto_promises?select=*&election_year=eq.2026&limit=2000" -Headers $headers -Method Get
$facts = Invoke-RestMethod -Uri "$base/party_facts?select=*&limit=3000" -Headers $headers -Method Get

$promiseByPartyCategory = @{}
foreach ($p in $promises) {
    $party = ([string]$p.party).ToUpperInvariant()
    $cat = [string]$p.category
    if (-not $party -or -not $cat) { continue }
    $k = "$party|$cat"
    if (-not $promiseByPartyCategory.ContainsKey($k)) { $promiseByPartyCategory[$k] = @() }
    $promiseByPartyCategory[$k] += $p
}

$factByPartyCategory = @{}
foreach ($f in $facts) {
    $party = ([string]$f.party).ToUpperInvariant()
    $cat = [string]$f.category
    if (-not $party -or -not $cat) { continue }
    $k = "$party|$cat"
    if (-not $factByPartyCategory.ContainsKey($k)) { $factByPartyCategory[$k] = @() }
    $factByPartyCategory[$k] += $f
}

$configFiles = @()
$configFiles += Get-ChildItem "elections/tn/constituencies" -Recurse -Filter "config.json"
$stateConfigPath = "elections/tn/2026-state/config.json"
if (Test-Path $stateConfigPath) {
    $configFiles += Get-Item $stateConfigPath
}
$updatedFiles = 0
$updatedPositions = 0
$updatedProfiles = 0

foreach ($file in $configFiles) {
    $o = Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $o.parties -or -not $o.theses) { continue }

    $localPos = 0
    $localProf = 0

    foreach ($party in $o.parties) {
        $code = Get-PartyCodeFromAlias $party.alias
        $profileUrl = Get-PartyProfileUrl $code
        if ($profileUrl) {
            if (-not $party.profile) {
                $party | Add-Member -NotePropertyName profile -NotePropertyValue ([pscustomobject]@{ en = $profileUrl; ta = $profileUrl }) -Force
                $localProf++
            } else {
                $curEn = if ($party.profile.en) { [string]$party.profile.en } else { '' }
                if (-not $curEn -or $curEn -match 'wikipedia.org') {
                    $party.profile.en = $profileUrl
                    $party.profile.ta = $profileUrl
                    $localProf++
                }
            }
        }
    }

    foreach ($th in $o.theses) {
        $titleEn = if ($th.title -and $th.title.en) { [string]$th.title.en } else { '' }
        $cat = Get-CategoryFromThesis $titleEn
        if (-not $cat -or -not $th.positions) { continue }

        foreach ($prop in $th.positions.PSObject.Properties) {
            $alias = [string]$prop.Name
            $entry = $prop.Value
            $partyCode = Get-PartyCodeFromAlias $alias
            if (-not $partyCode) { continue }

            $k = "$partyCode|$cat"
            $partyPromises = if ($promiseByPartyCategory.ContainsKey($k)) { @($promiseByPartyCategory[$k]) } else { @() }
            $partyFacts = if ($factByPartyCategory.ContainsKey($k)) { @($factByPartyCategory[$k]) } else { @() }
            if ($partyPromises.Count -eq 0 -and $partyFacts.Count -eq 0) { continue }

            $score = 0.0
            foreach ($pp in $partyPromises) {
                $score += Get-BelievabilityWeight $pp.believability_label
                if ($pp.is_flagship -eq $true) { $score += 0.5 }
            }
            foreach ($pf in $partyFacts) {
                $type = ([string]$pf.fact_type).ToLowerInvariant()
                if ($type -eq 'positive') { $score += 0.5 }
                elseif ($type -eq 'concern') { $score -= 0.5 }
            }

            $position = Get-PositionFromScore $score

            $p0 = $partyPromises | Select-Object -First 1
            $f0 = $partyFacts | Select-Object -First 1
            $promiseTextEn = if ($p0 -and $p0.promise_text) { [string]$p0.promise_text } else { 'Manifesto promise tracked for this category.' }
            $promiseTextTa = if ($p0 -and $p0.promise_text_tamil) { [string]$p0.promise_text_tamil } else { $promiseTextEn }
            $factTextEn = if ($f0 -and $f0.fact_text) { [string]$f0.fact_text } else { 'Past performance facts were reviewed for this category.' }
            $factTextTa = if ($f0 -and $f0.fact_text_ta) { [string]$f0.fact_text_ta } else { $factTextEn }

            if (-not $entry.explanation) {
                $entry | Add-Member -NotePropertyName explanation -NotePropertyValue ([pscustomobject]@{ en = ''; ta = '' }) -Force
            }
            $entry.position = $position
            $entry.explanation.en = "Stated position (2026): $promiseTextEn Past performance signal: $factTextEn"
            $entry.explanation.ta = "Stated position (2026): $promiseTextTa Past performance signal: $factTextTa"

            $src = if ($p0 -and $p0.source_url) { [string]$p0.source_url } elseif ($f0 -and $f0.source_url) { [string]$f0.source_url } else { 'https://www.tnelections.info/manifesto' }
            if ($entry.PSObject.Properties.Name -contains 'source') {
                $entry.source = $src
            } else {
                $entry | Add-Member -NotePropertyName source -NotePropertyValue $src -Force
            }

            $localPos++
        }
    }

    if ($o.PSObject.Properties.Name -contains 'candidateSourceNote') {
        if ($o.candidateSourceNote -notmatch 'tnelections.info') {
            $o.candidateSourceNote = "$($o.candidateSourceNote) Thesis positions enriched from https://www.tnelections.info/manifesto and party_facts (one-time run)."
        }
    } else {
        $o | Add-Member -NotePropertyName candidateSourceNote -NotePropertyValue 'Thesis positions enriched from https://www.tnelections.info/manifesto and party_facts (one-time run).' -Force
    }

    if ($localPos -gt 0 -or $localProf -gt 0) {
        $jsonOut = $o | ConvertTo-Json -Depth 100
        [System.IO.File]::WriteAllText($file.FullName, $jsonOut, (New-Object System.Text.UTF8Encoding($false)))
        $updatedFiles++
        $updatedPositions += $localPos
        $updatedProfiles += $localProf
    }
}

Write-Output "updated_files=$updatedFiles updated_positions=$updatedPositions updated_profiles=$updatedProfiles"
