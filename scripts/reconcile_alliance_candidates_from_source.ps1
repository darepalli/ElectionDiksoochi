$ErrorActionPreference = "Stop"
Set-Location "d:\Ravi\Project\india-election-compass"

function Get-AliasFromPartyCode([string]$code) {
    switch ($code) {
        "DMK" { "cand-dmk" }
        "INC" { "cand-inc" }
        "VCK" { "cand-vck" }
        "CPI" { "cand-cpi" }
        "CPI(M)" { "cand-cpm" }
        "CPM" { "cand-cpm" }
        "MDMK" { "cand-mdmk" }
        "IUML" { "cand-iuml" }
        "ADMK" { "cand-aiadmk" }
        "BJP" { "cand-bjp" }
        "PMK" { "cand-pmk" }
        "DMDK" { "cand-dmdk" }
        "AMMK" { "cand-ammk" }
        "TVK" { "cand-tvk" }
        "NTK" { "cand-ntk" }
        default { "cand-" + ($code.ToLowerInvariant() -replace '[^a-z0-9]+','-').Trim('-') }
    }
}

function Get-ShortFromPartyCode([string]$code) {
    switch ($code) {
        "ADMK" { "AIADMK" }
        default { $code }
    }
}

function Get-ProfileUrlFromPartyCode([string]$code) {
    switch ($code) {
        "DMK" { "https://en.wikipedia.org/wiki/Dravida_Munnetra_Kazhagam" }
        "INC" { "https://en.wikipedia.org/wiki/Indian_National_Congress" }
        "VCK" { "https://en.wikipedia.org/wiki/Viduthalai_Chiruthaigal_Katchi" }
        "CPI" { "https://en.wikipedia.org/wiki/Communist_Party_of_India" }
        "CPI(M)" { "https://en.wikipedia.org/wiki/Communist_Party_of_India_(Marxist)" }
        "CPM" { "https://en.wikipedia.org/wiki/Communist_Party_of_India_(Marxist)" }
        "MDMK" { "https://en.wikipedia.org/wiki/Marumalarchi_Dravida_Munnetra_Kazhagam" }
        "IUML" { "https://en.wikipedia.org/wiki/Indian_Union_Muslim_League" }
        "ADMK" { "https://en.wikipedia.org/wiki/All_India_Anna_Dravida_Munnetra_Kazhagam" }
        "BJP" { "https://en.wikipedia.org/wiki/Bharatiya_Janata_Party" }
        "PMK" { "https://en.wikipedia.org/wiki/Pattali_Makkal_Katchi" }
        "DMDK" { "https://en.wikipedia.org/wiki/Desiya_Murpokku_Dravida_Kazhagam" }
        "AMMK" { "https://en.wikipedia.org/wiki/Amma_Makkal_Munneetra_Kazhagam" }
        "TVK" { "https://en.wikipedia.org/wiki/Tamilaga_Vetri_Kazhagam" }
        "NTK" { "https://en.wikipedia.org/wiki/Naam_Tamilar_Katchi" }
        default { "https://tnelections2026.in/candidates.html" }
    }
}

$spaAliases = @('cand-dmk','cand-inc','cand-vck','cand-cpi','cand-cpm','cand-mdmk','cand-iuml','cand-kmdk','cand-mmk')
$ndaAliases = @('cand-aiadmk','cand-bjp','cand-pmk','cand-dmdk','cand-ammk','cand-tmc','cand-pt')

$bundleUrl = "https://tnelections2026.in/data/candidates_bundle.min.js"
$raw = (Invoke-WebRequest -UseBasicParsing -Uri $bundleUrl).Content
$eq = $raw.IndexOf("=")
if ($eq -lt 0) { throw "Could not parse candidates bundle" }
$jsonText = $raw.Substring($eq + 1).Trim()
if ($jsonText.EndsWith(";")) { $jsonText = $jsonText.Substring(0, $jsonText.Length - 1) }
$candidates = $jsonText | ConvertFrom-Json

$byAc = @{}
foreach ($c in $candidates) {
    $ac = [int]$c.acNo
    if (-not $byAc.ContainsKey($ac)) {
        $byAc[$ac] = [ordered]@{ spa = $null; nda = $null; tvk = $null }
    }
    $name = if ($c.name) { ([string]$c.name).Trim() } else { "" }
    if (-not $name -or $name -eq "-") { continue }

    $code = if ($c.party -and $c.party.code) { [string]$c.party.code } else { "" }
    $alliance = if ($c.alliance) { [string]$c.alliance } else { "" }
    if ($alliance -eq "spa" -and -not $byAc[$ac].spa) { $byAc[$ac].spa = $c }
    if ($alliance -eq "nda" -and -not $byAc[$ac].nda) { $byAc[$ac].nda = $c }
    if ($code -eq "TVK" -and -not $byAc[$ac].tvk) { $byAc[$ac].tvk = $c }
}

$meta = Get-Content "elections/tn/constituencies/constituencies.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$noToSlug = @{}
foreach ($r in $meta.constituencies) { $noToSlug[[int]$r.no] = [string]$r.slug }

$updated = 0
$spaReconciled = 0
$ndaReconciled = 0
$tvkReconciled = 0

foreach ($ac in ($byAc.Keys | Sort-Object)) {
    if (-not $noToSlug.ContainsKey($ac)) { continue }
    $slug = $noToSlug[$ac]
    $path = Join-Path "elections/tn/constituencies" (Join-Path $slug "config.json")
    if (-not (Test-Path $path)) { continue }

    $o = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $o.parties -or -not $o.theses) { continue }

    $seat = $byAc[$ac]
    $aliasRemap = @{}

    if ($seat.spa) {
        $spaCode = [string]$seat.spa.party.code
        $spaName = ([string]$seat.spa.name).Trim()
        $spaAlias = Get-AliasFromPartyCode $spaCode
        $spaShort = Get-ShortFromPartyCode $spaCode
        $spaProfile = Get-ProfileUrlFromPartyCode $spaCode

        $spaObj = @($o.parties | Where-Object { $_.alias -in $spaAliases -or $_.alias -eq $spaAlias }) | Select-Object -First 1
        if (-not $spaObj) { $spaObj = $o.parties | Select-Object -First 1 }
        if ($spaObj) {
            $old = [string]$spaObj.alias
            $spaObj.alias = $spaAlias
            $spaObj.name.en = "$spaName ($spaShort)"
            $spaObj.short.en = "$spaName / $spaShort"
            $spaObj.description.en = "Public-source mapping: $spaName is listed as $spaCode alliance candidate for this constituency on tnelections2026.in candidates explorer."
            if ($spaObj.profile) {
                $spaObj.profile.en = $spaProfile
                $spaObj.profile.ta = $spaProfile
            }
            if ($old -ne $spaAlias) { $aliasRemap[$old] = $spaAlias }
            $spaReconciled++
        }
    }

    if ($seat.nda) {
        $ndaCode = [string]$seat.nda.party.code
        $ndaName = ([string]$seat.nda.name).Trim()
        $ndaAlias = Get-AliasFromPartyCode $ndaCode
        $ndaShort = Get-ShortFromPartyCode $ndaCode
        $ndaProfile = Get-ProfileUrlFromPartyCode $ndaCode

        $ndaObj = @($o.parties | Where-Object { $_.alias -in $ndaAliases -or $_.alias -eq $ndaAlias }) | Select-Object -First 1
        if (-not $ndaObj) { $ndaObj = $o.parties | Select-Object -Skip 1 -First 1 }
        if ($ndaObj) {
            $old = [string]$ndaObj.alias
            $ndaObj.alias = $ndaAlias
            $ndaObj.name.en = "$ndaName ($ndaShort)"
            $ndaObj.short.en = "$ndaName / $ndaShort"
            $ndaObj.description.en = "Public-source mapping: $ndaName is listed as $ndaCode alliance candidate for this constituency on tnelections2026.in candidates explorer."
            if ($ndaObj.profile) {
                $ndaObj.profile.en = $ndaProfile
                $ndaObj.profile.ta = $ndaProfile
            }
            if ($old -ne $ndaAlias) { $aliasRemap[$old] = $ndaAlias }
            $ndaReconciled++
        }
    }

    if ($seat.tvk) {
        $tvkName = ([string]$seat.tvk.name).Trim()
        $tvkObj = @($o.parties | Where-Object { $_.alias -eq 'cand-tvk' }) | Select-Object -First 1
        if (-not $tvkObj) {
            $tvkObj = [pscustomobject]@{
                alias = 'cand-tvk'
                name = [pscustomobject]@{ en = ''; ta = '' }
                short = [pscustomobject]@{ en = ''; ta = '' }
                description = [pscustomobject]@{ en = ''; ta = '' }
                profile = [pscustomobject]@{ en = ''; ta = '' }
            }
            $o.parties = @($o.parties + $tvkObj)
        }
        $tvkObj.alias = 'cand-tvk'
        $tvkObj.name.en = "$tvkName (TVK)"
        $tvkObj.short.en = "$tvkName / TVK"
        $tvkObj.description.en = "Public-source mapping: $tvkName is listed as TVK candidate for this constituency on tnelections2026.in candidates explorer."
        $tvkObj.profile.en = "https://en.wikipedia.org/wiki/Tamilaga_Vetri_Kazhagam"
        $tvkObj.profile.ta = "https://en.wikipedia.org/wiki/Tamilaga_Vetri_Kazhagam"
        $tvkReconciled++
    }

    $dedup = [ordered]@{}
    foreach ($p in $o.parties) {
        if (-not $p.alias) { continue }
        $k = [string]$p.alias
        if (-not $dedup.Contains($k)) { $dedup[$k] = $p }
    }
    $o.parties = @($dedup.Values)

    foreach ($th in $o.theses) {
        if (-not $th.positions) { continue }
        $oldPos = $th.positions
        $newPos = [ordered]@{}
        foreach ($prop in $oldPos.PSObject.Properties) {
            $k = [string]$prop.Name
            $target = if ($aliasRemap.ContainsKey($k)) { $aliasRemap[$k] } else { $k }
            if (-not $newPos.Contains($target)) {
                $entry = $prop.Value
                if ($target -in @('cand-tvk') -or $target -in $spaAliases -or $target -in $ndaAliases) {
                    $entry.source = "https://tnelections2026.in/candidates.html"
                }
                $newPos[$target] = $entry
            }
        }
        if ($seat.tvk -and -not $newPos.Contains('cand-tvk')) {
            $newPos['cand-tvk'] = [pscustomobject]@{
                position = 'neutral'
                explanation = [pscustomobject]@{
                    en = 'TVK candidate is listed in public source for this constituency. Update stance with source-backed issue statements as they are published.'
                    ta = 'TVK candidate is listed in public source for this constituency. Update stance with source-backed issue statements as they are published.'
                }
                source = 'https://tnelections2026.in/candidates.html'
            }
        }
        $th.positions = [pscustomobject]$newPos
    }

    if ($o.PSObject.Properties.Name -contains 'candidateSourceNote') {
        if ($o.candidateSourceNote -notmatch 'tnelections2026.in/candidates.html') {
            $o.candidateSourceNote = "$($o.candidateSourceNote) Alliance candidates cross-verified from https://tnelections2026.in/candidates.html"
        }
    } else {
        $o | Add-Member -NotePropertyName candidateSourceNote -NotePropertyValue 'Alliance candidates cross-verified from https://tnelections2026.in/candidates.html' -Force
    }

    $jsonOut = $o | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText((Resolve-Path $path), $jsonOut, (New-Object System.Text.UTF8Encoding($false)))
    $updated++
}

Write-Output "updated_files=$updated spa_reconciled=$spaReconciled nda_reconciled=$ndaReconciled tvk_reconciled=$tvkReconciled"
