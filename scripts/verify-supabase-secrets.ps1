<#
.SYNOPSIS
  Compare un fichier .env local aux secrets deployes sur Supabase, SANS jamais
  lire ni afficher une valeur.

.DESCRIPTION
  `supabase secrets list` ne rend que des empreintes : un secret s'ecrit, ne se
  relit jamais. Mais l'empreinte EST le SHA256 de la valeur. On peut donc
  prouver qu'une valeur locale est celle deployee -- ou reperer un gabarit
  (`sk_test_...`) pousse en production par megarde.

  Aucune valeur n'est affichee, ni ecrite, ni transmise.

.EXAMPLE
  powershell -File scripts/verify-supabase-secrets.ps1
  powershell -File scripts/verify-supabase-secrets.ps1 -EnvFile supabase/functions/.env
#>
param(
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $EnvFile)) {
    Write-Host "Fichier introuvable : $EnvFile" -ForegroundColor Red
    exit 1
}

# La CLI scoop n'est pas toujours dans le PATH de la session.
$cli = "supabase"
if (-not (Get-Command $cli -ErrorAction SilentlyContinue)) {
    $shim = Join-Path $env:USERPROFILE "scoop\shims\supabase.exe"
    if (Test-Path $shim) { $cli = $shim }
    else {
        Write-Host "CLI supabase introuvable (PATH et scoop\shims)." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Lecture des empreintes distantes..." -ForegroundColor Cyan
$listing = & $cli secrets list
if ($LASTEXITCODE -ne 0) { Write-Host "Echec de 'secrets list'." -ForegroundColor Red; exit 1 }

$remote = @{}
foreach ($line in $listing) {
    if ($line -match '^\s*([A-Z][A-Z0-9_]*)\s*\|\s*([0-9a-f]{64})\s*$') {
        $remote[$Matches[1]] = $Matches[2]
    }
}
Write-Host "  $($remote.Count) secrets deployes." -ForegroundColor Cyan

$sha = [System.Security.Cryptography.SHA256]::Create()
function Get-Digest([string]$value) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($value)
    return -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") })
}

# Un gabarit laisse tel quel est le defaut le plus couteux : il ecrase un vrai
# secret sans que rien ne proteste.
$stubPatterns = @('\.\.\.', 'your_', 'YOUR_', 'xxx', 'XXX', 'changeme', 'change-me', 'TODO', 'placeholder', '<project-ref>')

$rows = @()
foreach ($line in Get-Content $EnvFile) {
    if ($line -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$') { continue }
    $name  = $Matches[1]
    $value = $Matches[2].Trim()

    $isStub = $false
    foreach ($p in $stubPatterns) { if ($value -match $p) { $isStub = $true; break } }

    if (-not $remote.ContainsKey($name)) {
        $etat = "non pose sur Supabase"; $couleur = "DarkGray"
    }
    elseif ($value -eq "") {
        $etat = "vide en local (rien a comparer)"; $couleur = "DarkGray"
    }
    elseif ((Get-Digest $value) -eq $remote[$name]) {
        if ($isStub) { $etat = "IDENTIQUE -- et c'est un GABARIT en production"; $couleur = "Red" }
        else         { $etat = "identique";                                     $couleur = "Green" }
    }
    else {
        $etat = "DIFFERENT du deploye"; $couleur = "Yellow"
    }

    $rows += [pscustomobject]@{ Nom = $name; Etat = $etat; Couleur = $couleur }
}

Write-Host ""
Write-Host ("{0,-32} {1}" -f "SECRET", "ETAT")
Write-Host ("-" * 72)
foreach ($r in $rows) { Write-Host ("{0,-32} {1}" -f $r.Nom, $r.Etat) -ForegroundColor $r.Couleur }

$orphelins = $remote.Keys | Where-Object { $rows.Nom -notcontains $_ } | Sort-Object
if ($orphelins) {
    Write-Host ""
    Write-Host "Deployes mais absents de ${EnvFile} :" -ForegroundColor DarkGray
    foreach ($o in $orphelins) { Write-Host "  $o" -ForegroundColor DarkGray }
}

Write-Host ""
Write-Host "Aucune valeur n'a ete affichee : seules des empreintes ont ete comparees." -ForegroundColor Cyan
