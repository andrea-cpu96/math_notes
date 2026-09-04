$ErrorActionPreference = 'Stop'

$path    = 'c:\Andrea\math\Theory\Theory\Theory\calculus-1-theory.tex'
$outPath = 'c:\Andrea\math\Theory\Theory\Theory\calculus-1-theory.reformatted.tex'

$noBlank = @('align*','align','equation*','equation','tikzpicture','tabular','array','matrix','pmatrix','bmatrix','vmatrix','cases','gather*','gather','multline*','multline','split','aligned','alignedat')

# ---- tokenize: break each merged line at structural tokens, both before and after ----
$lines = [System.IO.File]::ReadAllLines($path)
$tokens = @()
foreach ($ln in $lines) {
    if ($ln.Trim().Length -eq 0) { continue }
    $parts = [regex]::Split($ln, '(?=(?:\\begin\{|\\end\{|\\\[|\\\]))')
    foreach ($part in $parts) {
        $subparts = [regex]::Split($part, '(?<=(?:\\begin\{[^}]*\}|\\end\{[^}]*\}|\\\[|\\\]))')
        foreach ($p in $subparts) {
            if ($p.Trim().Length -gt 0) { $tokens += $p.Trim() }
        }
    }
}

$out   = @()
$para  = @()
$stack = @()
$disp  = $false
$prot  = $false

function Add-BlankIfNeeded {
    if ($script:out.Count -gt 0 -and $script:out[$script:out.Count-1].Trim().Length -gt 0) {
        $script:out += ''
    }
}

function Invoke-FlushParagraph {
    if ($script:para.Count -eq 0) { return }
    $text = $script:para -join ' '
    $text = $text -replace '[ \t]+', ' '
    $script:para = @()
    $words = $text.Trim().Split(' ')
    $cur = ''
    foreach ($w in $words) {
        if ($cur.Length -eq 0) {
            $cur = $w
        } elseif (($cur + ' ' + $w).Length -le 79) {
            $cur = $cur + ' ' + $w
        } else {
            $script:out += $cur
            $cur = $w
        }
    }
    if ($cur.Length -gt 0) { $script:out += $cur }
}

function Test-Protected {
    $s = @($args[0])
    foreach ($e in $s) { if ($noBlank -contains $e) { return $true } }
    return $false
}

foreach ($t in $tokens) {
    if ($t -match '^\\begin\{([^}]+)\}') {
        $env = $Matches[1]
        Invoke-FlushParagraph
        Add-BlankIfNeeded
        $out += $t
        $stack += $env
        $prot = Test-Protected $stack
        continue
    }
    if ($t -match '^\\end\{([^}]+)\}') {
        $env = $Matches[1]
        Invoke-FlushParagraph
        $out += $t
        if ($stack.Count -gt 0 -and $stack[$stack.Count-1] -eq $env) {
            if ($stack.Count -eq 1) { $stack = @() } else { $stack = $stack[0..($stack.Count-2)] }
        } else {
            $stack = $stack | Where-Object { $_ -ne $env }
        }
        $prot = Test-Protected $stack
        Add-BlankIfNeeded
        continue
    }
    if ($t -eq '\[') {
        Invoke-FlushParagraph
        Add-BlankIfNeeded
        $out += '\['
        $disp = $true
        continue
    }
    if ($t -eq '\]') {
        $disp = $false
        $out += '\]'
        Add-BlankIfNeeded
        continue
    }
    if ($t.StartsWith('%')) {
        Invoke-FlushParagraph
        $out += $t
        continue
    }
    if ($t -match '^\\item') {
        Invoke-FlushParagraph
        $para += $t
        continue
    }
    if ($t -match '^\\section|^\\subsection|^\\subsubsection') {
        Invoke-FlushParagraph
        Add-BlankIfNeeded
        $out += $t
        Add-BlankIfNeeded
        continue
    }
    if ($disp -or $prot) {
        $out += $t
    } else {
        $para += $t
    }
}
Invoke-FlushParagraph

if (-not $out.Contains('\end{document}')) {
    Add-BlankIfNeeded
    $out += '\end{document}'
}

[System.IO.File]::WriteAllLines($outPath, $out, (New-Object System.Text.UTF8Encoding($false)))

# ---- validation output ----
Write-Output ('tokens            : ' + $tokens.Count)
Write-Output ('out lines         : ' + $out.Count)
Write-Output ('blank lines       : ' + ($out | Where-Object { $_.Trim().Length -eq 0 }).Count)
Write-Output ('open \[ count     : ' + ($out | Where-Object { $_ -eq '\[' }).Count)
Write-Output ('close \ ] count   : ' + ($out | Where-Object { $_ -eq '\]' }).Count)
Write-Output ('begin align*      : ' + ($out | Where-Object { $_ -match '^\\begin\{align' }).Count)
Write-Output ('end   align*      : ' + ($out | Where-Object { $_ -match '^\\end\{align' }).Count)
$max = ($out | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
Write-Output ('max line length   : ' + $max)

# check for blank lines inside align and tikzpicture blocks (would be LaTeX errors)
$inAlign = $false; $badAlign = 0
$inTikz  = $false; $badTikz  = 0
foreach ($l in $out) {
    if ($l -match '^\\begin\{align') { $inAlign = $true; continue }
    if ($l -match '^\\end\{align') { $inAlign = $false; continue }
    if ($inAlign -and $l.Trim().Length -eq 0) { $badAlign++ }
    if ($l -match '^\\begin\{tikzpicture\}') { $inTikz = $true; continue }
    if ($l -match '^\\end\{tikzpicture\}') { $inTikz = $false; continue }
    if ($inTikz -and $l.Trim().Length -eq 0) { $badTikz++ }
}
Write-Output ('blank in align    : ' + $badAlign)
Write-Output ('blank in tikzpict : ' + $badTikz)