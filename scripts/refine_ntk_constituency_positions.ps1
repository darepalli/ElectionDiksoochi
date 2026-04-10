$ErrorActionPreference = "Stop"
Set-Location "d:\Ravi\Project\india-election-compass"

function Get-NtkMapping([string]$title) {
    $safeTitle = if ($null -eq $title) { "" } else { [string]$title }
    $t = $safeTitle.ToLowerInvariant()

    if ($t -match "state autonomy") {
        return [pscustomobject]@{
            position = "approve"
            explanation = "NTK public statements emphasize stronger State rights vis-a-vis the Union government (including fiscal and policy autonomy demands), which aligns with approving greater State autonomy."
            source = "https://www.naamtamilar.org/2025/02/pass-resolution-no-fund-no-tax-unless-the-indian-union-govt-releases-fund-for-tn-school-children-seeman-urges-dmk-govt/"
        }
    }

    if ($t -match "women") {
        return [pscustomobject]@{
            position = "approve"
            explanation = "NTK public statements call for stronger legal punishment and enforcement in sexual-violence cases, aligning with stronger women safety and mobility protections."
            source = "https://www.naamtamilar.org/2026/03/%e0%ae%aa%e0%af%86%e0%ae%a3%e0%af%8d-%e0%ae%95%e0%af%81%e0%ae%b4%e0%ae%a8%e0%af%8d%e0%ae%a4%e0%af%88%e0%ae%95%e0%ae%b3%e0%af%88%e0%ae%aa%e0%af%8d-%e0%ae%aa%e0%ae%be%e0%ae%b2%e0%ae%bf%e0%ae%af%e0%ae%b2/"
        }
    }

    if ($t -match "drinking water|water") {
        return [pscustomobject]@{
            position = "neutral"
            explanation = "NTK policy messaging emphasizes Tamil Nadu resource rights and water governance concerns, but this constituency-specific service-reliability thesis is kept neutral until a directly quantified local implementation commitment is published."
            source = "https://www.naamtamilar.org/policies/"
        }
    }

    if ($t -match "jobs|msme|street vendor") {
        return [pscustomobject]@{
            position = "neutral"
            explanation = "NTK manifesto and campaign material emphasize Tamil youth livelihood and local enterprise priorities; this thesis is mapped neutral here pending a directly quantified constituency-level MSME/vendor implementation commitment."
            source = "https://makkalarasu.in/assets/NTK-2026-Manifesto.pdf"
        }
    }

    if ($t -match "roads|drainage|flood") {
        return [pscustomobject]@{
            position = "neutral"
            explanation = "NTK policy materials include broad infrastructure and public-service themes, but this local roads/drainage execution thesis is kept neutral until a directly mapped constituency-level commitment is published."
            source = "https://makkalarasu.in/assets/NTK-2026-Manifesto.pdf"
        }
    }

    if ($t -match "public health|health") {
        return [pscustomobject]@{
            position = "neutral"
            explanation = "NTK policy documents and campaign materials include broad welfare and public-service themes, but this constituency-level public-health access thesis is kept neutral until a direct mapped commitment is available."
            source = "https://makkalarasu.in/assets/NTK-2026-Manifesto.pdf"
        }
    }

    if ($t -match "heritage") {
        return [pscustomobject]@{
            position = "neutral"
            explanation = "NTK policy positions emphasize Tamil identity and cultural protection themes, but this specific heritage-zone implementation thesis is kept neutral pending a directly mapped local policy commitment."
            source = "https://www.naamtamilar.org/policies/"
        }
    }

    if ($t -match "transport") {
        return [pscustomobject]@{
            position = "neutral"
            explanation = "NTK manifesto material includes broad public-service commitments, but this local transport-service thesis is kept neutral until a directly quantified constituency-level commitment is mapped."
            source = "https://makkalarasu.in/assets/NTK-2026-Manifesto.pdf"
        }
    }

    if ($t -match "housing") {
        return [pscustomobject]@{
            position = "neutral"
            explanation = "NTK manifesto material includes social-welfare commitments; this affordable-housing thesis is kept neutral here until a directly mapped and quantified constituency implementation commitment is published."
            source = "https://makkalarasu.in/assets/NTK-2026-Manifesto.pdf"
        }
    }

    return [pscustomobject]@{
        position = "neutral"
        explanation = "NTK public materials were reviewed, but this thesis remains neutral in this release until a direct, thesis-specific constituency commitment is mapped."
        source = "https://www.naamtamilar.org/policies/"
    }
}

$files = Get-ChildItem "elections/tn/constituencies" -Recurse -Filter config.json
$updatedFiles = 0
$updatedTheses = 0

foreach ($f in $files) {
    $o = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $changed = $false

    foreach ($th in $o.theses) {
        if (-not $th.positions -or -not ($th.positions.PSObject.Properties.Name -contains "cand-ntk")) { continue }

        $map = Get-NtkMapping -title ([string]$th.title.en)
        $th.positions."cand-ntk" = [pscustomobject]@{
            position = $map.position
            explanation = [pscustomobject]@{
                en = $map.explanation
                ta = $map.explanation
            }
            source = $map.source
        }
        $updatedTheses++
        $changed = $true
    }

    if ($changed) {
        if ($o.PSObject.Properties.Name -contains "candidateSourceNote") {
            if ([string]$o.candidateSourceNote -notmatch "NTK thesis positions refined from") {
                $o.candidateSourceNote = ([string]$o.candidateSourceNote + " NTK thesis positions refined from naamtamilar.org and NTK manifesto links (source-mapped pass).")
            }
        } else {
            $o | Add-Member -NotePropertyName candidateSourceNote -NotePropertyValue "NTK thesis positions refined from naamtamilar.org and NTK manifesto links (source-mapped pass)." -Force
        }

        $jsonOut = $o | ConvertTo-Json -Depth 100
        [System.IO.File]::WriteAllText($f.FullName, $jsonOut, (New-Object System.Text.UTF8Encoding($false)))
        $updatedFiles++
    }
}

Write-Output ("updated_files={0} updated_theses={1}" -f $updatedFiles, $updatedTheses)
