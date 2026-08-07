# Check (and optionally publish) the privacy policies that Google Play links to.
#
# The trap this exists for (2026-08-07): each app's privacy policy is WRITTEN in
# its own repo at docs/privacy-policy.html, but the copy Google Play actually
# links to is the one served from THIS repo by GitHub Pages, under a different
# filename. Editing and pushing the app repo therefore publishes nothing. That
# is not hypothetical -- MASH's policy was corrected and pushed to the mash repo
# while the live page still served the previous version, with a paragraph that
# was no longer true of the shipping app.
#
#   .\publish-policies.ps1            # report drift only, changes nothing
#   .\publish-policies.ps1 -Publish   # copy, commit and push the live copies
#
# Run the check after ANY edit to either app's docs/privacy-policy.html.

[CmdletBinding()]
param(
    [switch]$Publish,
    [string]$SpiritRepo = "C:\Users\paulb\AndroidStudioProjects\20260704_Claude_Spirit_App_rev2.6",
    [string]$MashRepo = "C:\Users\paulb\AndroidStudioProjects\MASH"
)

$ErrorActionPreference = "Stop"
$SiteRoot = $PSScriptRoot

$policies = @(
    @{ Name = "Spirit"
       Source = Join-Path $SpiritRepo "docs\privacy-policy.html"
       Published = Join-Path $SiteRoot "spirit-privacy-policy.html"
       Url = "https://paulbevins63-bit.github.io/policies/spirit-privacy-policy.html" },
    @{ Name = "MASH"
       Source = Join-Path $MashRepo "docs\privacy-policy.html"
       Published = Join-Path $SiteRoot "mash-privacy-policy.html"
       Url = "https://paulbevins63-bit.github.io/policies/mash-privacy-policy.html" }
)

$drifted = @()

foreach ($p in $policies) {
    if (-not (Test-Path $p.Source)) {
        Write-Host "?? $($p.Name): source missing at $($p.Source)" -ForegroundColor Yellow
        continue
    }
    $same = (Get-FileHash $p.Source).Hash -eq (Get-FileHash $p.Published).Hash
    if ($same) {
        Write-Host "ok   $($p.Name): published copy matches the repo" -ForegroundColor Green
    } else {
        Write-Host "DRIFT $($p.Name): the LIVE page is not what the repo says" -ForegroundColor Red
        Write-Host "      source:    $($p.Source)"
        Write-Host "      published: $($p.Published)"
        Write-Host "      live:      $($p.Url)"
        $drifted += $p
    }
}

if ($drifted.Count -eq 0) {
    Write-Host "`nBoth published policies are current." -ForegroundColor Green
    exit 0
}

if (-not $Publish) {
    Write-Host "`n$($drifted.Count) policy/policies out of date. Re-run with -Publish to fix." -ForegroundColor Yellow
    exit 1
}

foreach ($p in $drifted) {
    Copy-Item $p.Source $p.Published -Force
    Write-Host "copied $($p.Name)" -ForegroundColor Cyan
}

Push-Location $SiteRoot
try {
    git add -- ($drifted | ForEach-Object { Split-Path $_.Published -Leaf })
    $names = ($drifted | ForEach-Object { $_.Name }) -join " + "
    git commit -m "Publish $names privacy policy"
    if ($LASTEXITCODE -ne 0) { throw "commit failed" }
    git -c http.sslBackend=schannel push origin main
    if ($LASTEXITCODE -ne 0) { throw "push failed (AVG breaks OpenSSL here; schannel is already set)" }
} finally {
    Pop-Location
}

Write-Host "`nPushed. GitHub Pages takes a minute; then confirm:" -ForegroundColor Green
$drifted | ForEach-Object { Write-Host "  $($_.Url)" }
