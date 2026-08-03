<#
.SYNOPSIS
    Repare les chaines doublement encodees (UTF-8 relu en CP850) dans les fichiers texte.

.DESCRIPTION
    Sur cette machine la console Windows est en CP850. Un outil qui relit un fichier UTF-8
    dans cette page de code puis le reecrit produit du « mojibake » : « connecte » (avec
    accent) se retrouve stocke litteralement « connect├® » et s'affiche ainsi dans l'app.

    Le script balaye chaque run de caracteres non-ASCII et ne le convertit que si les
    TROIS gardes passent :

      1. L'aller-retour CP850 du run est exact. Sinon le caractere n'existe pas dans
         CP850 : c'est un emoji ou un symbole legitime, on n'y touche pas.
      2. Les octets obtenus forment de l'UTF-8 valide (UTF8Encoding($false, $true),
         qui jette sinon). Un accent deja correct echoue ici : « e accent » seul donne
         l'octet 0x82, qui n'est pas de l'UTF-8 valide.
      3. Le resultat ressemble a du texte reel (voir Test-PlausibleText).

    Le garde 3 n'est PAS optionnel. Les diagrammes ASCII en box-drawing des .md du depot
    (─ │ ┌ ┘ ═ ╔) vivent eux aussi dans CP850 : « ─│ » = octets C4 B3 = de l'UTF-8 valide
    par pur hasard, qui se decode en « ĳ ». Les gardes 1 et 2 laissent passer ce cas. Sans
    le garde 3, une passe sur docs/ detruisait 303 sequences de diagrammes (CALL_FLOW.md,
    PUSH_NOTIFICATIONS_GUIDE.md, PUSH_NOTIFICATIONS_MAQUETTES.md, ANALYSE_PROJET_002.md).

    A l'interieur d'un run, le balayage est gourmand plus-long-d'abord, pour traiter le
    cas d'un mojibake colle a du texte deja correct. Les fichiers sont reecrits en UTF-8
    SANS BOM.

.PARAMETER Root
    Racine a auditer. Passer la racine du depot pour un balayage complet.

.PARAMETER Apply
    Ecrit les fichiers. Sans ce commutateur, le script ne fait que simuler.

.EXAMPLE
    # 1. Simuler et RELIRE la liste des conversions uniques avant d'ecrire
    .\scripts\fix_mojibake.ps1 -Root (Get-Location) | Where-Object { $_ -match '->' } | Sort-Object -Unique

.EXAMPLE
    # 2. Appliquer
    .\scripts\fix_mojibake.ps1 -Root (Get-Location) -Apply

.NOTES
    Controles de sortie attendus : « flutter analyze » propre, et un « git diff --stat »
    parfaitement symetrique (autant d'insertions que de suppressions) — une asymetrie
    signalerait une ligne perdue.

    Ne pas auditer le resultat via « git show » dans la console PowerShell : elle decode
    la sortie de git en CP850 et fabrique du faux mojibake dans son propre affichage.
    Lire le contenu reel avec [System.IO.File]::ReadAllText($p, [Text.Encoding]::UTF8).

    Limite connue : le rapport final ne liste les runs laisses intacts que pour les
    fichiers ayant eu au moins une conversion. Un fichier dont TOUT le mojibake serait
    rejete par le garde 3 passerait donc silencieusement. Ce cas n'existe pas aujourd'hui
    (aucun « Ôöé » / « ÔòÉ » dans le depot) mais apparaitrait si un diagramme box-drawing
    se faisait lui-meme doublement encoder.

    Campagne du 2026-08-03 : 456b5f7 (7 fichiers du module appels), cbb58b1 (19 derniers
    fichiers de lib/, 166 sequences), cad0128 (TESTS_APPAREIL_A_FAIRE.md, 4 sequences).
#>
param(
    [Parameter(Mandatory = $true)][string]$Root,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

$cp850      = [System.Text.Encoding]::GetEncoding(850)
$utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)   # throwOnInvalidBytes
$utf8NoBom  = New-Object System.Text.UTF8Encoding($false)

# 3e garde : le resultat doit ressembler a du texte reel (francais + ponctuation
# typographique + emoji). Indispensable a cause des diagrammes ASCII en box-drawing :
# ils vivent dans CP850, donc « ─│ » (C4 B3) passe les deux premiers gardes et donne
# « ĳ ». Refuser le latin etendu, le grec et le box-drawing en SORTIE tue ce faux positif.
function Test-PlausibleText([string]$s) {
    for ($i = 0; $i -lt $s.Length; $i++) {
        $ch = $s[$i]
        $cp = [int][char]$ch
        if ([char]::IsHighSurrogate($ch) -and $i + 1 -lt $s.Length) {
            $cp = [char]::ConvertToUtf32($ch, $s[$i + 1])
            $i++
        }
        $ok = ($cp -ge 0x20 -and $cp -le 0x7E) -or $cp -eq 9 -or $cp -eq 10 -or $cp -eq 13 `
           -or ($cp -ge 0xA0 -and $cp -le 0xFF) `
           -or $cp -eq 0x152 -or $cp -eq 0x153 -or $cp -eq 0x178 -or $cp -eq 0x192 `
           -or ($cp -ge 0x2010 -and $cp -le 0x203A) -or $cp -eq 0x20AC -or $cp -eq 0x20E3 `
           -or $cp -eq 0x2122 -or $cp -eq 0xFE0F `
           -or ($cp -ge 0x2190 -and $cp -le 0x21FF) `
           -or ($cp -ge 0x25A0 -and $cp -le 0x25FF) `
           -or ($cp -ge 0x2600 -and $cp -le 0x27BF) `
           -or ($cp -ge 0x2B00 -and $cp -le 0x2BFF) `
           -or ($cp -ge 0x1F000 -and $cp -le 0x1FAFF)
        if (-not $ok) { return $false }
    }
    return $true
}

# Tente de reinterpreter une sous-chaine comme du mojibake CP850.
# Retourne $null si ce n'est pas un mojibake sur (aller-retour CP850 inexact,
# octets qui ne forment pas de l'UTF-8 valide, ou resultat invraisemblable).
function Convert-Mojibake([string]$s) {
    try {
        $bytes = $cp850.GetBytes($s)
        if ($cp850.GetString($bytes) -ne $s) { return $null }   # emoji / symbole hors CP850
        $dec = $utf8Strict.GetString($bytes)                    # jette si UTF-8 invalide
        if (-not (Test-PlausibleText $dec)) { return $null }    # box-drawing legitime, etc.
        return $dec
    } catch {
        return $null
    }
}

# Balaye un run de caracteres non-ASCII et remplace, de gauche a droite,
# la plus longue sous-chaine qui est un mojibake CP850 sur.
function Repair-Run([string]$run) {
    $sb = New-Object System.Text.StringBuilder
    $i = 0
    $n = $run.Length
    while ($i -lt $n) {
        $matched = $false
        for ($len = $n - $i; $len -ge 2; $len--) {
            $dec = Convert-Mojibake $run.Substring($i, $len)
            if ($null -ne $dec) {
                [void]$sb.Append($dec)
                $i += $len
                $matched = $true
                break
            }
        }
        if (-not $matched) {
            [void]$sb.Append($run[$i])   # laisse intact : emoji, symbole, accent deja correct
            $i++
        }
    }
    return $sb.ToString()
}

$rx = [regex]'[^\x00-\x7F]+'

# Extensions texte a auditer. Les binaires et les arbres generes sont exclus.
$exts = @('.dart', '.arb', '.md', '.json', '.js', '.mjs', '.cjs', '.ts', '.yaml', '.yml',
          '.sql', '.xml', '.html', '.css', '.txt', '.properties', '.plist', '.gradle',
          '.kts', '.kt', '.java', '.swift', '.rules', '.sh', '.ps1', '.gitignore')
$excludeRx = [regex]'(^|\\)(\.git|node_modules|build|\.dart_tool|\.gradle|Pods|\.idea|\.claude\\worktrees|coverage|graphify-out)(\\|$)'

# Le script s'exclut lui-meme : sa documentation cite du mojibake en exemple
# (« connect├® »), qu'il « reparerait » sinon, rendant ses propres exemples faux.
$files = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $exts -contains $_.Extension.ToLower() } |
    Where-Object { -not $excludeRx.IsMatch($_.DirectoryName) } |
    Where-Object { $_.FullName -ne $PSCommandPath }
$totalFiles = 0
$totalRuns = 0
$skipped = @()

foreach ($f in $files) {
    # La branche est partagee avec un agent qui ecrit en continu : un fichier peut
    # disparaitre entre l'enumeration et la lecture. On l'ignore au lieu de tout stopper.
    try {
        $content = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    } catch {
        Write-Warning ("illisible, ignore : {0}" -f $f.FullName)
        continue
    }
    $ms = $rx.Matches($content)
    if ($ms.Count -eq 0) { continue }

    $sb = New-Object System.Text.StringBuilder
    $pos = 0
    $fixedRuns = 0
    $fileSkipped = @()
    $preview = @()
    foreach ($m in $ms) {
        [void]$sb.Append($content.Substring($pos, $m.Index - $pos))
        $fixed = Repair-Run $m.Value
        if ($fixed -ne $m.Value) {
            $fixedRuns++
            $preview += ("    {0}  ->  {1}" -f $m.Value, $fixed)
        } else {
            $fileSkipped += ("{0} : {1}" -f $f.Name, $m.Value)
        }
        [void]$sb.Append($fixed)
        $pos = $m.Index + $m.Length
    }
    if ($fixedRuns -gt 0) {
        $preview | ForEach-Object { Write-Output $_ }
        $skipped += $fileSkipped
    }
    [void]$sb.Append($content.Substring($pos))
    $new = $sb.ToString()

    if ($new -ne $content) {
        $rel = $f.FullName.Substring($Root.Length).TrimStart('\')
        Write-Output ("[{0}] {1} ({2} runs)" -f $(if ($Apply) { 'ECRIT' } else { 'SIMU' }), $rel, $fixedRuns)
        $totalFiles++
        $totalRuns += $fixedRuns
        if ($Apply) {
            [System.IO.File]::WriteAllText($f.FullName, $new, $utf8NoBom)
        }
    }
}

Write-Output ""
Write-Output ("Fichiers concernes : {0} - runs repares : {1}" -f $totalFiles, $totalRuns)
if ($skipped.Count -gt 0) {
    Write-Output ""
    Write-Output ("Runs non-ASCII laisses intacts ({0}) :" -f $skipped.Count)
    $skipped | Sort-Object -Unique | ForEach-Object { Write-Output ("    " + $_) }
}
