$ErrorActionPreference = "Stop"
Set-Location "d:\Ravi\Project\india-election-compass"

$bundleUrl = "https://tnelections2026.in/data/candidates_bundle.min.js"
$raw = (Invoke-WebRequest -UseBasicParsing -Uri $bundleUrl).Content
$eq = $raw.IndexOf("=")
if ($eq -lt 0) { throw "Unable to parse candidates bundle" }
$json = $raw.Substring($eq + 1).Trim()
if ($json.EndsWith(";")) { $json = $json.Substring(0, $json.Length - 1) }
$cands = $json | ConvertFrom-Json

$ntkByAc = @{}
foreach ($c in $cands) {
    if (-not $c -or -not $c.party -or [string]$c.party.code -ne "NTK") { continue }
    if (-not $c.name -or [string]$c.name -eq "-") { continue }
    $ac = [int]$c.acNo
    if (-not $ntkByAc.ContainsKey($ac)) {
        $ntkByAc[$ac] = ([string]$c.name).Trim()
    }
}

$meta = Get-Content "elections/tn/constituencies/constituencies.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$slugToAc = @{}
foreach ($r in $meta.constituencies) {
    $slugToAc[[string]$r.slug] = [int]$r.no
}

$targets = @()
Get-ChildItem "elections/tn/constituencies" -Recurse -Filter config.json | ForEach-Object {
    $o = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $ok = $true
    foreach ($t in $o.theses) {
        if (-not ($t.positions.PSObject.Properties.Name -contains "cand-ntk")) {
            $ok = $false
            break
        }
    }
    if (-not $ok) { $targets += $_.FullName }
}

$updated = 0
$failed = @()
foreach ($path in $targets) {
    try {
        $slug = Split-Path (Split-Path $path -Parent) -Leaf
        $ac = if ($slugToAc.ContainsKey($slug)) { $slugToAc[$slug] } else { $null }
        $ntkName = if ($ac -and $ntkByAc.ContainsKey($ac)) { $ntkByAc[$ac] } else { "" }

        $o = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $o.parties) {
            $o | Add-Member -NotePropertyName parties -NotePropertyValue @() -Force
        }

        $ntkObj = @($o.parties | Where-Object { $_.alias -eq "cand-ntk" }) | Select-Object -First 1
        if (-not $ntkObj) {
            $displayName = if ($ntkName) { "$ntkName (NTK)" } else { "NTK Candidate (NTK)" }
            $shortName = if ($ntkName) { "$ntkName / NTK" } else { "NTK Candidate / NTK" }
            $desc = if ($ntkName) {
                "Public-source mapping: $ntkName is listed as NTK candidate for this constituency on tnelections2026.in candidates explorer."
            } else {
                "Public-source mapping: NTK candidate should be verified for this constituency on tnelections2026.in candidates explorer."
            }
            $new = [pscustomobject]@{
                alias = "cand-ntk"
                name = [pscustomobject]@{ en = $displayName; ta = $displayName }
                short = [pscustomobject]@{ en = $shortName; ta = $shortName }
                description = [pscustomobject]@{ en = $desc; ta = $desc }
                profile = [pscustomobject]@{ en = "https://www.tnelections.info/parties#ntk"; ta = "https://www.tnelections.info/parties#ntk" }
                partyProfile = [pscustomobject]@{ en = "https://www.tnelections.info/parties#ntk"; ta = "https://www.tnelections.info/parties#ntk" }
            }
            $o.parties = @($o.parties + $new)
        }

        foreach ($th in $o.theses) {
            if (-not $th.positions) {
                $th | Add-Member -NotePropertyName positions -NotePropertyValue ([pscustomobject]@{}) -Force
            }
            if (-not ($th.positions.PSObject.Properties.Name -contains "cand-ntk")) {
                $th.positions | Add-Member -NotePropertyName "cand-ntk" -NotePropertyValue ([pscustomobject]@{
                    position = "neutral"
                    explanation = [pscustomobject]@{
                        en = "NTK candidate is listed in public source for this constituency. Update stance with source-backed issue statements as they are published."
                        ta = "NTK candidate is listed in public source for this constituency. Update stance with source-backed issue statements as they are published."
                    }
                    source = "https://tnelections2026.in/candidates.html"
                }) -Force
            }
        }

        if ($o.PSObject.Properties.Name -contains "candidateSourceNote") {
            if ([string]$o.candidateSourceNote -notmatch "NTK candidate mapped from https://tnelections2026.in/candidates.html") {
                $o.candidateSourceNote = ([string]$o.candidateSourceNote + " NTK candidate mapped from https://tnelections2026.in/candidates.html").Trim()
            }
        } else {
            $o | Add-Member -NotePropertyName candidateSourceNote -NotePropertyValue "NTK candidate mapped from https://tnelections2026.in/candidates.html" -Force
        }

        $jsonOut = $o | ConvertTo-Json -Depth 100
        [System.IO.File]::WriteAllText($path, $jsonOut, (New-Object System.Text.UTF8Encoding($false)))
        $updated++
    } catch {
        $failed += ("{0} :: {1}" -f $path, $_.Exception.Message)
    }
}

Write-Output ("targets={0} updated={1} failed={2}" -f $targets.Count, $updated, $failed.Count)
$failed | Select-Object -First 20 | ForEach-Object { Write-Output $_ }
