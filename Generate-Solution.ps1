<#
.SYNOPSIS
    Génère une solution Visual Studio unique regroupant tous les sous-projets
    (.vcxproj) trouvés dans chaque dossier du dépôt.

.DESCRIPTION
    Parcourt récursivement le dossier racine à la recherche de fichiers *.vcxproj,
    lit le ProjectGuid et les configurations (Debug|Win32, Release|Win32, ...) de
    chacun, puis écrit un fichier .sln au format Visual Studio à la racine.

    Seuls les projets .vcxproj (format MSBuild moderne) sont inclus : un .sln ne
    peut pas référencer les anciens .vcproj sans migration préalable. Tout projet
    converti plus tard en .vcxproj sera automatiquement détecté au prochain lancement.

.PARAMETER Root
    Dossier racine à scanner. Par défaut : le dossier du script.

.PARAMETER Output
    Chemin du fichier .sln à générer. Par défaut : <Root>\BdeB-GameAI.sln

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Generate-Solution.ps1
#>

[CmdletBinding()]
param(
    [string]$Root,
    [string]$Output
)

$ErrorActionPreference = 'Stop'

# Dossier du script (fonctionne sous Windows PowerShell 5.1 et PowerShell 7).
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

if (-not $Root)   { $Root   = $scriptDir }
if (-not $Output) { $Output = Join-Path $scriptDir 'BdeB-GameAI.sln' }

# GUID de type "projet C++" reconnu par Visual Studio.
$cppProjectTypeGuid = '8BC9CEB8-8B4A-11D0-8D11-00A0C91BC942'

# --- Découverte des projets ----------------------------------------------
Write-Host "Recherche des projets .vcxproj dans : $Root"

$projectFiles = Get-ChildItem -Path $Root -Recurse -Filter '*.vcxproj' -File |
    Where-Object { $_.FullName -notmatch '[\\/]Backup[\\/]' } |
    Sort-Object FullName

if (-not $projectFiles) {
    Write-Warning "Aucun fichier .vcxproj trouvé."
    return
}

$rootUri   = [Uri]([IO.Path]::GetFullPath($Root) + [IO.Path]::DirectorySeparatorChar)
$projects  = @()
$allConfigs = [System.Collections.Generic.List[string]]::new()

foreach ($file in $projectFiles) {
    [xml]$xml = Get-Content -LiteralPath $file.FullName -Raw

    # Espace de noms MSBuild (présent dans tous les .vcxproj).
    $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $ns.AddNamespace('m', 'http://schemas.microsoft.com/developer/msbuild/2003')

    # ProjectGuid (génère un GUID si absent — rare).
    $guidNode = $xml.SelectSingleNode('//m:ProjectGuid', $ns)
    if ($guidNode -and $guidNode.InnerText) {
        $guid = $guidNode.InnerText.Trim('{', '}')
    } else {
        $guid = [Guid]::NewGuid().ToString()
        Write-Warning "Pas de ProjectGuid dans '$($file.Name)' — GUID temporaire généré."
    }

    # Configurations du projet (Debug|Win32, Release|Win32, ...).
    $configs = $xml.SelectNodes("//m:ItemGroup[@Label='ProjectConfigurations']/m:ProjectConfiguration", $ns) |
        ForEach-Object { $_.GetAttribute('Include') }

    if (-not $configs) { $configs = @('Debug|Win32', 'Release|Win32') }

    foreach ($c in $configs) {
        if (-not $allConfigs.Contains($c)) { $allConfigs.Add($c) }
    }

    # Chemin relatif à la racine de la solution.
    $relPath = $rootUri.MakeRelativeUri([Uri]$file.FullName).ToString() -replace '/', '\'
    $relPath = [Uri]::UnescapeDataString($relPath)

    $projects += [pscustomobject]@{
        Name    = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        Path    = $relPath
        Guid    = $guid.ToUpper()
        Configs = $configs
    }

    Write-Host "  + $($file.Name)  ->  {$($guid.ToUpper())}"
}

# Ordre des configurations de solution : Debug d'abord, puis Release, puis le reste.
$solutionConfigs = $allConfigs | Sort-Object @{
    Expression = {
        switch -Wildcard ($_) { 'Debug*' { 0 } 'Release*' { 1 } default { 2 } }
    }
}, @{ Expression = { $_ } }

$solutionGuid = [Guid]::NewGuid().ToString().ToUpper()

# --- Construction du .sln -------------------------------------------------
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine()
[void]$sb.AppendLine('Microsoft Visual Studio Solution File, Format Version 12.00')
[void]$sb.AppendLine('# Visual Studio Version 18')
[void]$sb.AppendLine('VisualStudioVersion = 18.7.11919.86 stable')
[void]$sb.AppendLine('MinimumVisualStudioVersion = 10.0.40219.1')

foreach ($p in $projects) {
    [void]$sb.AppendLine("Project(`"{$cppProjectTypeGuid}`") = `"$($p.Name)`", `"$($p.Path)`", `"{$($p.Guid)}`"")
    [void]$sb.AppendLine('EndProject')
}

[void]$sb.AppendLine('Global')

# SolutionConfigurationPlatforms
[void]$sb.AppendLine("`tGlobalSection(SolutionConfigurationPlatforms) = preSolution")
foreach ($c in $solutionConfigs) {
    [void]$sb.AppendLine("`t`t$c = $c")
}
[void]$sb.AppendLine("`tEndGlobalSection")

# ProjectConfigurationPlatforms
[void]$sb.AppendLine("`tGlobalSection(ProjectConfigurationPlatforms) = postSolution")
foreach ($p in $projects) {
    foreach ($c in $solutionConfigs) {
        # Si le projet possède exactement cette config, on l'active ET on la compile.
        # Sinon on la mappe sur sa config la plus proche (sans Build) pour rester valide.
        if ($p.Configs -contains $c) {
            $target = $c
            $build  = $true
        } else {
            $platform = ($c -split '\|')[1]
            $target = $p.Configs | Where-Object { ($_ -split '\|')[1] -eq $platform } | Select-Object -First 1
            if (-not $target) { $target = $p.Configs | Select-Object -First 1 }
            $build = $false
        }

        [void]$sb.AppendLine("`t`t{$($p.Guid)}.$c.ActiveCfg = $target")
        if ($build) {
            [void]$sb.AppendLine("`t`t{$($p.Guid)}.$c.Build.0 = $target")
        }
    }
}
[void]$sb.AppendLine("`tEndGlobalSection")

# SolutionProperties
[void]$sb.AppendLine("`tGlobalSection(SolutionProperties) = preSolution")
[void]$sb.AppendLine("`t`tHideSolutionNode = FALSE")
[void]$sb.AppendLine("`tEndGlobalSection")

# ExtensibilityGlobals
[void]$sb.AppendLine("`tGlobalSection(ExtensibilityGlobals) = postSolution")
[void]$sb.AppendLine("`t`tSolutionGuid = {$solutionGuid}")
[void]$sb.AppendLine("`tEndGlobalSection")

[void]$sb.AppendLine('EndGlobal')

# Écriture en UTF-8 avec BOM (attendu par Visual Studio).
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[IO.File]::WriteAllText($Output, $sb.ToString(), $utf8Bom)

Write-Host ""
Write-Host "Solution générée : $Output"
Write-Host "  $($projects.Count) projet(s), $($solutionConfigs.Count) configuration(s)."
