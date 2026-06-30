param(
    [string]$Port = "mlog"
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message
}

function Write-Detail {
    param([string]$Name, [string]$Value)
    Write-Host ("      {0,-14}: {1}" -f $Name, $Value)
}

function Invoke-Logged {
    param(
        [string]$Title,
        [string]$Command,
        [string[]]$Arguments
    )

    Write-Host ("      command       : {0} {1}" -f $Command, ($Arguments -join " "))
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Title failed with exit code $LASTEXITCODE"
    }
}

function Quote-Json {
    param([string]$Value)
    return ($Value | ConvertTo-Json -Compress)
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string[]]$Lines
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines((Join-Path $Root $Path), $Lines, $encoding)
}

function Get-VersionField {
    param($Manifest)

    foreach ($field in @("version", "version-string", "version-semver", "version-date")) {
        if ($null -ne $Manifest.PSObject.Properties[$field]) {
            return $field
        }
    }

    throw "No version field found in vcpkg.json"
}

function Write-BaselineJson {
    param(
        [string]$Path,
        [string]$Port,
        [string]$Version,
        [int]$PortVersion
    )

    $entries = @{}
    if (Test-Path (Join-Path $Root $Path)) {
        $baseline = Get-Content -Raw (Join-Path $Root $Path) | ConvertFrom-Json
        if ($baseline.default) {
            foreach ($prop in $baseline.default.PSObject.Properties) {
                $entries[$prop.Name] = [pscustomobject]@{
                    baseline = [string]$prop.Value.baseline
                    portVersion = [int]$prop.Value.'port-version'
                }
            }
        }
    }

    $entries[$Port] = [pscustomobject]@{
        baseline = $Version
        portVersion = $PortVersion
    }

    $names = @($entries.Keys | Sort-Object)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("{")
    $lines.Add("`t""default"": {")

    for ($i = 0; $i -lt $names.Count; $i++) {
        $name = $names[$i]
        $comma = if ($i -lt $names.Count - 1) { "," } else { "" }
        $entry = $entries[$name]
        $lines.Add("`t`t$(Quote-Json $name): {")
        $lines.Add("`t`t`t""baseline"": $(Quote-Json $entry.baseline),")
        $lines.Add("`t`t`t""port-version"": $($entry.portVersion)")
        $lines.Add("`t`t}$comma")
    }

    $lines.Add("`t}")
    $lines.Add("}")
    Write-Utf8NoBom -Path $Path -Lines $lines.ToArray()
}

function Get-EntryVersionField {
    param($Entry)

    foreach ($field in @("version", "version-string", "version-semver", "version-date")) {
        if ($null -ne $Entry.PSObject.Properties[$field]) {
            return $field
        }
    }

    return "version"
}

function Write-PortVersionJson {
    param(
        [string]$Path,
        [string]$VersionField,
        [string]$Version,
        [int]$PortVersion,
        [string]$GitTree
    )

    $existingEntries = @()
    if (Test-Path (Join-Path $Root $Path)) {
        $db = Get-Content -Raw (Join-Path $Root $Path) | ConvertFrom-Json
        if ($db.versions) {
            $existingEntries = @($db.versions)
        }
    }

    $filtered = @()
    foreach ($entry in $existingEntries) {
        $field = Get-EntryVersionField $entry
        $entryVersion = [string]$entry.$field
        $entryPortVersion = [int]$entry.'port-version'
        if (-not (($entryVersion -eq $Version) -and ($entryPortVersion -eq $PortVersion))) {
            $filtered += $entry
        }
    }

    $newEntry = [pscustomobject]@{
        versionField = $VersionField
        version = $Version
        portVersion = $PortVersion
        gitTree = $GitTree
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("{")
    $lines.Add("`t""versions"": [")

    $allEntries = @($newEntry) + $filtered
    for ($i = 0; $i -lt $allEntries.Count; $i++) {
        $comma = if ($i -lt $allEntries.Count - 1) { "," } else { "" }
        $entry = $allEntries[$i]

        if ($entry.PSObject.Properties["versionField"]) {
            $field = $entry.versionField
            $entryVersion = $entry.version
            $entryPortVersion = $entry.portVersion
            $entryGitTree = $entry.gitTree
        } else {
            $field = Get-EntryVersionField $entry
            $entryVersion = [string]$entry.$field
            $entryPortVersion = [int]$entry.'port-version'
            $entryGitTree = [string]$entry.'git-tree'
        }

        $lines.Add("`t`t{")
        $lines.Add("`t`t`t$(Quote-Json $field): $(Quote-Json $entryVersion),")
        $lines.Add("`t`t`t""port-version"": $entryPortVersion,")
        $lines.Add("`t`t`t""git-tree"": $(Quote-Json $entryGitTree)")
        $lines.Add("`t`t}$comma")
    }

    $lines.Add("`t]")
    $lines.Add("}")
    Write-Utf8NoBom -Path $Path -Lines $lines.ToArray()
}

Write-Host "============================================================"
Write-Host " registry_add_version.bat"
Write-Host "============================================================"
Write-Detail "Registry root" $Root
Write-Detail "Port name" $Port
Write-Detail "Time" (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Write-Host "============================================================"

Set-Location $Root

Write-Step "[1/9] Validating registry layout"
if (-not (Test-Path ".git")) {
    throw "This directory is not a git repository: $Root"
}

$portDir = "ports/$Port"
$manifestPath = "$portDir/vcpkg.json"
$portfilePath = "$portDir/portfile.cmake"
if (-not (Test-Path $manifestPath)) {
    throw "Missing port manifest: $manifestPath"
}
if (-not (Test-Path $portfilePath)) {
    throw "Missing portfile: $portfilePath"
}
Write-Detail "Port dir" $portDir
Write-Detail "Manifest" $manifestPath
Write-Detail "Portfile" $portfilePath

Write-Step "[2/9] Reading port metadata"
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
$versionField = Get-VersionField $manifest
$version = [string]$manifest.$versionField
$portVersion = if ($null -ne $manifest.PSObject.Properties["port-version"]) { [int]$manifest.'port-version' } else { 0 }
Write-Detail "Version field" $versionField
Write-Detail "Version" $version
Write-Detail "Port version" ([string]$portVersion)

Write-Step "[3/9] Git status before update"
git status --short
if ($LASTEXITCODE -ne 0) {
    throw "git status failed"
}

Write-Step "[4/9] Staging port directory"
Invoke-Logged "git add" "git" @("add", "ports/$Port")

Write-Step "[5/9] Calculating git-tree"
Write-Detail "Command" "git write-tree --prefix=ports/$Port/"
$gitTree = (& git write-tree "--prefix=ports/$Port/").Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitTree)) {
    throw "git write-tree failed"
}
Write-Detail "git-tree" $gitTree

Write-Step "[6/9] Resolving versions path"
$first = $Port.Substring(0, 1).ToLowerInvariant()
$versionDir = "versions/$first-"
$versionPath = "$versionDir/$Port.json"
New-Item -ItemType Directory -Force -Path (Join-Path $Root $versionDir) | Out-Null
Write-Detail "Baseline" "versions/baseline.json"
Write-Detail "Version db" $versionPath

Write-Step "[7/9] Updating versions metadata"
Write-BaselineJson -Path "versions/baseline.json" -Port $Port -Version $version -PortVersion $portVersion
Write-PortVersionJson -Path $versionPath -VersionField $versionField -Version $version -PortVersion $portVersion -GitTree $gitTree
Write-Detail "Recorded" "$Port $version#$portVersion -> $gitTree"

Write-Step "[8/9] Staging versions metadata"
Invoke-Logged "git add versions" "git" @("add", "versions/baseline.json", $versionPath)

Write-Step "[9/9] Final status and staged diff summary"
git status --short
Write-Host ""
git diff --cached --stat

Write-Host ""
Write-Host "============================================================"
Write-Host " Done."
Write-Host "============================================================"
Write-Host " Next suggested commands:"
Write-Host "   git diff --cached"
Write-Host "   git commit -m `"Update $Port port version`""
Write-Host "   git push"
Write-Host "============================================================"
