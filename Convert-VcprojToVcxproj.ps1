<#
.SYNOPSIS
    Convertit les anciens projets Visual C++ 2008 (.vcproj) au format MSBuild
    moderne (.vcxproj + .vcxproj.filters), lisible par Visual Studio 2026 (v18).

.DESCRIPTION
    Visual Studio 2026 ne sait plus ouvrir les .vcproj (format VS2008). Ce script
    reproduit le travail de l'assistant de migration : il lit chaque .vcproj et
    génère un .vcxproj équivalent (même GUID, mêmes configurations, mêmes fichiers
    et réglages compilateur/éditeur de liens essentiels), calqué sur le projet
    Steering déjà migré (toolset v145, VCProjectVersion 18.0).

    Par défaut, tous les .vcproj du dépôt sont convertis (sauf ceux déjà migrés et
    les dossiers Backup). On peut aussi cibler un fichier précis avec -Path.

.PARAMETER Path
    Chemin d'un .vcproj précis à convertir. Sinon, tous sont traités.

.PARAMETER Root
    Dossier racine à scanner (par défaut : dossier du script).

.PARAMETER Force
    Réécrit le .vcxproj même s'il existe déjà.

.EXAMPLE
    pwsh -File .\Convert-VcprojToVcxproj.ps1
#>

[CmdletBinding()]
param(
    [string]$Path,
    [string]$Root,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $Root) { $Root = $scriptDir }

# ---------------------------------------------------------------------------
# Tables de correspondance entre valeurs numériques .vcproj et énumérés MSBuild.
# ---------------------------------------------------------------------------
$mapConfigType   = @{ '1' = 'Application'; '2' = 'DynamicLibrary'; '4' = 'StaticLibrary'; '10' = 'Utility' }
$mapCharSet      = @{ '0' = 'NotSet'; '1' = 'Unicode'; '2' = 'MultiByte' }
$mapOptimize     = @{ '0' = 'Disabled'; '1' = 'MinSpace'; '2' = 'MaxSpeed'; '3' = 'Full' }
$mapInline       = @{ '0' = 'Disabled'; '1' = 'OnlyExplicitInline'; '2' = 'AnySuitable' }
$mapRuntimeLib   = @{ '0' = 'MultiThreaded'; '1' = 'MultiThreadedDebug'; '2' = 'MultiThreadedDLL'; '3' = 'MultiThreadedDebugDLL' }
$mapRuntimeCheck = @{ '0' = 'Default'; '1' = 'StackFrameRuntimeCheck'; '2' = 'UninitializedLocalUsageCheck'; '3' = 'EnableFastChecks' }
$mapWarning      = @{ '0' = 'TurnOffAllWarnings'; '1' = 'Level1'; '2' = 'Level2'; '3' = 'Level3'; '4' = 'Level4' }
$mapDebugInfo    = @{ '0' = 'None'; '1' = 'OldStyle'; '3' = 'ProgramDatabase'; '4' = 'EditAndContinue' }
$mapSubSystem    = @{ '0' = 'NotSet'; '1' = 'Console'; '2' = 'Windows' }
$mapMachine      = @{ '0' = 'NotSet'; '1' = 'MachineX86'; '17' = 'MachineX64' }

# Extensions de fichiers source / en-tête / ressources.
$extCompile  = @('.cpp', '.c', '.cxx', '.cc')
$extInclude  = @('.h', '.hpp', '.hxx', '.hm', '.inl')
$extResource = @('.rc')

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Get-Attr($node, [string]$name) {
    if ($null -eq $node) { return $null }
    if (-not $node.HasAttribute($name)) { return $null }
    return $node.GetAttribute($name)
}

# Recherche sûre dans une table de correspondance (clé $null/absente -> $null).
function MapEnum($table, $val) {
    if ([string]::IsNullOrEmpty($val)) { return $null }
    if ($table.ContainsKey($val)) { return $table[$val] }
    return $null
}

function Get-Tool($config, [string]$name) {
    foreach ($t in $config.Tool) { if ($t.Name -eq $name) { return $t } }
    return $null
}

# Échappement XML pour les valeurs d'attribut.
function XmlEnc([string]$s) {
    if ($null -eq $s) { return '' }
    return ($s -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;')
}

# GUID déterministe (stable d'une exécution à l'autre) dérivé d'une chaîne.
function New-StableGuid([string]$seed) {
    $md5   = [System.Security.Cryptography.MD5]::Create()
    $bytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($seed))
    return ([Guid]::new($bytes)).ToString().ToUpper()
}

# Parcourt récursivement les <Filter>/<File> et renvoie une liste plate :
#   @{ Path; Filter }  (Filter = "Source Files\Sub", ou $null si à la racine)
function Get-FileEntries($node, [string]$parentFilter) {
    $result = @()
    foreach ($child in $node.ChildNodes) {
        if ($child.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
        # NB : utiliser LocalName et non Name — l'adaptateur XML de PowerShell
        # masque .Name avec la valeur de l'attribut "Name" du nœud.
        if ($child.LocalName -eq 'Filter') {
            $fname = Get-Attr $child 'Name'
            $full  = if ($parentFilter) { "$parentFilter\$fname" } else { $fname }
            $result += Get-FileEntries $child $full
        }
        elseif ($child.LocalName -eq 'File') {
            $rel = (Get-Attr $child 'RelativePath') -replace '^\.\\', '' -replace '/', '\'
            $result += [pscustomobject]@{ Path = $rel; Filter = $parentFilter }
        }
    }
    return $result
}

function Classify([string]$path) {
    $ext = [IO.Path]::GetExtension($path).ToLower()
    if ($extCompile  -contains $ext) { return 'ClCompile' }
    if ($extInclude  -contains $ext) { return 'ClInclude' }
    if ($extResource -contains $ext) { return 'ResourceCompile' }
    return 'None'
}

# Chemin relatif de $fromDir vers $toPath (séparateurs Windows).
function Get-RelPath([string]$fromDir, [string]$toPath) {
    $fromUri = [Uri]($fromDir.TrimEnd('\', '/') + '\')
    $rel = $fromUri.MakeRelativeUri([Uri]$toPath).ToString() -replace '/', '\'
    return [Uri]::UnescapeDataString($rel)
}

# Projets déjà migrés à la main : on ne les régénère jamais (références).
$protectedProjects = @('Steering.vcproj', 'Raven.vcproj')

# ---------------------------------------------------------------------------
# Conversion d'un projet
# ---------------------------------------------------------------------------
function Convert-OneProject([string]$vcprojPath) {

    $vcprojPath = (Resolve-Path -LiteralPath $vcprojPath).Path
    $vcxprojPath = [IO.Path]::ChangeExtension($vcprojPath, '.vcxproj')

    if ($protectedProjects -contains [IO.Path]::GetFileName($vcprojPath)) {
        Write-Host "  ~ projet de référence protégé, ignoré : $([IO.Path]::GetFileName($vcprojPath))"
        return
    }

    if ((Test-Path -LiteralPath $vcxprojPath) -and -not $Force) {
        Write-Host "  = déjà migré, ignoré : $([IO.Path]::GetFileName($vcxprojPath))"
        return
    }

    $xml = New-Object System.Xml.XmlDocument
    $xml.Load($vcprojPath)
    $xmlRoot = $xml.DocumentElement

    $projName = Get-Attr $xmlRoot 'Name'
    $guid     = (Get-Attr $xmlRoot 'ProjectGUID')
    if (-not $guid) { $guid = '{' + (New-StableGuid $vcprojPath) + '}' }
    $guid = $guid.ToUpper()

    $configs = @($xmlRoot.Configurations.Configuration)

    # Le dossier Common (en-têtes partagés inclus via "misc/...", "2D/...", etc.)
    # n'était sur le chemin d'inclusion d'aucun .vcproj d'origine (le dépôt se
    # compile via CMake). On l'ajoute pour rendre les projets réellement compilables.
    $projDir   = Split-Path -Parent $vcprojPath
    $commonDir = Join-Path $Root 'Common'
    $commonRel = if (Test-Path -LiteralPath $commonDir) { Get-RelPath $projDir $commonDir } else { $null }

    # ---- En-tête + ProjectConfigurations -------------------------------
    $sb = [System.Text.StringBuilder]::new()
    $nl = "`r`n"
    [void]$sb.Append('<?xml version="1.0" encoding="utf-8"?>' + $nl)
    [void]$sb.Append('<Project DefaultTargets="Build" ToolsVersion="Current" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' + $nl)
    [void]$sb.Append('  <ItemGroup Label="ProjectConfigurations">' + $nl)
    foreach ($c in $configs) {
        $name = Get-Attr $c 'Name'                      # "Debug|Win32"
        $parts = $name -split '\|'
        [void]$sb.Append("    <ProjectConfiguration Include=`"$name`">$nl")
        [void]$sb.Append("      <Configuration>$($parts[0])</Configuration>$nl")
        [void]$sb.Append("      <Platform>$($parts[1])</Platform>$nl")
        [void]$sb.Append("    </ProjectConfiguration>$nl")
    }
    [void]$sb.Append('  </ItemGroup>' + $nl)

    # ---- Globals -------------------------------------------------------
    [void]$sb.Append('  <PropertyGroup Label="Globals">' + $nl)
    [void]$sb.Append('    <VCProjectVersion>18.0</VCProjectVersion>' + $nl)
    [void]$sb.Append("    <ProjectGuid>$guid</ProjectGuid>$nl")
    [void]$sb.Append("    <RootNamespace>$(XmlEnc $projName)</RootNamespace>$nl")
    [void]$sb.Append('  </PropertyGroup>' + $nl)
    [void]$sb.Append('  <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />' + $nl)

    # ---- PropertyGroup "Configuration" par config ----------------------
    foreach ($c in $configs) {
        $name    = Get-Attr $c 'Name'
        $cfgType = MapEnum $mapConfigType (Get-Attr $c 'ConfigurationType')
        if (-not $cfgType) { $cfgType = 'Application' }
        $charSet = MapEnum $mapCharSet (Get-Attr $c 'CharacterSet')
        $useMfc  = (Get-Attr $c 'UseOfMFC')
        $cond    = "'`$(Configuration)|`$(Platform)'=='$name'"
        [void]$sb.Append("  <PropertyGroup Condition=`"$cond`" Label=`"Configuration`">$nl")
        [void]$sb.Append("    <ConfigurationType>$cfgType</ConfigurationType>$nl")
        [void]$sb.Append("    <PlatformToolset>v145</PlatformToolset>$nl")
        if ($useMfc) {
            $mfc = if ($useMfc -eq '0') { 'false' } elseif ($useMfc -eq '1') { 'Static' } else { 'Dynamic' }
            [void]$sb.Append("    <UseOfMfc>$mfc</UseOfMfc>$nl")
        }
        if ($charSet) { [void]$sb.Append("    <CharacterSet>$charSet</CharacterSet>$nl") }
        [void]$sb.Append('  </PropertyGroup>' + $nl)
    }

    # ---- Imports props -------------------------------------------------
    [void]$sb.Append('  <Import Project="$(VCTargetsPath)\Microsoft.Cpp.props" />' + $nl)
    [void]$sb.Append('  <ImportGroup Label="ExtensionSettings">' + $nl)
    [void]$sb.Append('  </ImportGroup>' + $nl)
    foreach ($c in $configs) {
        $name = Get-Attr $c 'Name'
        $cond = "'`$(Configuration)|`$(Platform)'=='$name'"
        [void]$sb.Append("  <ImportGroup Condition=`"$cond`" Label=`"PropertySheets`">$nl")
        [void]$sb.Append('    <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists(''$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props'')" Label="LocalAppDataPlatform" />' + $nl)
        [void]$sb.Append('  </ImportGroup>' + $nl)
    }
    [void]$sb.Append('  <PropertyGroup Label="UserMacros" />' + $nl)

    # ---- OutDir / IntDir / LinkIncremental par config ------------------
    foreach ($c in $configs) {
        $name = Get-Attr $c 'Name'
        $cond = "'`$(Configuration)|`$(Platform)'=='$name'"
        $outDir = Get-Attr $c 'OutputDirectory'
        $intDir = Get-Attr $c 'IntermediateDirectory'
        if ($outDir -and ($outDir -notmatch '[\\/]$')) { $outDir += '\' }
        if ($intDir -and ($intDir -notmatch '[\\/]$')) { $intDir += '\' }
        $linker = Get-Tool $c 'VCLinkerTool'
        $linkInc = Get-Attr $linker 'LinkIncremental'   # 1=non, 2=oui

        [void]$sb.Append("  <PropertyGroup Condition=`"$cond`">$nl")
        if ($outDir) { [void]$sb.Append("    <OutDir>$(XmlEnc $outDir)</OutDir>$nl") }
        if ($intDir) { [void]$sb.Append("    <IntDir>$(XmlEnc $intDir)</IntDir>$nl") }
        if ($linkInc) {
            $li = if ($linkInc -eq '2') { 'true' } else { 'false' }
            [void]$sb.Append("    <LinkIncremental>$li</LinkIncremental>$nl")
        }
        [void]$sb.Append('  </PropertyGroup>' + $nl)
    }

    # ---- ItemDefinitionGroup (compilateur / ressources / linker) -------
    foreach ($c in $configs) {
        $name = Get-Attr $c 'Name'
        $cond = "'`$(Configuration)|`$(Platform)'=='$name'"
        $cl   = Get-Tool $c 'VCCLCompilerTool'
        $rc   = Get-Tool $c 'VCResourceCompilerTool'
        $link = Get-Tool $c 'VCLinkerTool'

        [void]$sb.Append("  <ItemDefinitionGroup Condition=`"$cond`">$nl")

        # ClCompile
        [void]$sb.Append('    <ClCompile>' + $nl)
        $v = MapEnum $mapOptimize (Get-Attr $cl 'Optimization');          if ($v) { [void]$sb.Append("      <Optimization>$v</Optimization>$nl") }
        $v = MapEnum $mapInline (Get-Attr $cl 'InlineFunctionExpansion'); if ($v) { [void]$sb.Append("      <InlineFunctionExpansion>$v</InlineFunctionExpansion>$nl") }
        # Répertoires d'inclusion : ceux d'origine (s'il y en a) + le dossier Common.
        $incDirs = @()
        $vinc = Get-Attr $cl 'AdditionalIncludeDirectories'
        if ($vinc) { $incDirs += $vinc }
        if ($commonRel) { $incDirs += $commonRel }
        if ($incDirs.Count) { [void]$sb.Append("      <AdditionalIncludeDirectories>$(XmlEnc ($incDirs -join ';'));%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>$nl") }
        $v = Get-Attr $cl 'PreprocessorDefinitions';                     if ($v) { [void]$sb.Append("      <PreprocessorDefinitions>$(XmlEnc $v);%(PreprocessorDefinitions)</PreprocessorDefinitions>$nl") }
        $v = Get-Attr $cl 'StringPooling';                               if ($v -eq 'true') { [void]$sb.Append("      <StringPooling>true</StringPooling>$nl") }
        $v = Get-Attr $cl 'MinimalRebuild';                              if ($v -eq 'true') { [void]$sb.Append("      <MinimalRebuild>true</MinimalRebuild>$nl") }
        $v = MapEnum $mapRuntimeCheck (Get-Attr $cl 'BasicRuntimeChecks'); if ($v) { [void]$sb.Append("      <BasicRuntimeChecks>$v</BasicRuntimeChecks>$nl") }
        $v = MapEnum $mapRuntimeLib (Get-Attr $cl 'RuntimeLibrary');      if ($v) { [void]$sb.Append("      <RuntimeLibrary>$v</RuntimeLibrary>$nl") }
        $v = Get-Attr $cl 'EnableFunctionLevelLinking';                  if ($v -eq 'true') { [void]$sb.Append("      <FunctionLevelLinking>true</FunctionLevelLinking>$nl") }
        $v = Get-Attr $cl 'RuntimeTypeInfo';                             if ($v) { [void]$sb.Append("      <RuntimeTypeInfo>$v</RuntimeTypeInfo>$nl") }
        $v = Get-Attr $cl 'UsePrecompiledHeader';                        if ($v -eq '0') { [void]$sb.Append("      <PrecompiledHeader>NotUsing</PrecompiledHeader>$nl") }
        $v = MapEnum $mapWarning (Get-Attr $cl 'WarningLevel');           if ($v) { [void]$sb.Append("      <WarningLevel>$v</WarningLevel>$nl") }
        $v = Get-Attr $cl 'SuppressStartupBanner';                       if ($v -eq 'true') { [void]$sb.Append("      <SuppressStartupBanner>true</SuppressStartupBanner>$nl") }
        $v = MapEnum $mapDebugInfo (Get-Attr $cl 'DebugInformationFormat'); if ($v) { [void]$sb.Append("      <DebugInformationFormat>$v</DebugInformationFormat>$nl") }
        [void]$sb.Append('    </ClCompile>' + $nl)

        # ResourceCompile
        if ($rc) {
            $rcDefs = Get-Attr $rc 'PreprocessorDefinitions'
            $rcCult = Get-Attr $rc 'Culture'
            [void]$sb.Append('    <ResourceCompile>' + $nl)
            if ($rcDefs) { [void]$sb.Append("      <PreprocessorDefinitions>$(XmlEnc $rcDefs);%(PreprocessorDefinitions)</PreprocessorDefinitions>$nl") }
            if ($rcCult) { [void]$sb.Append("      <Culture>0x{0:x4}</Culture>$nl" -f [int]$rcCult) }
            [void]$sb.Append('    </ResourceCompile>' + $nl)
        }

        # Link
        [void]$sb.Append('    <Link>' + $nl)
        $v = Get-Attr $link 'AdditionalDependencies';                    if ($v) { [void]$sb.Append("      <AdditionalDependencies>$(XmlEnc $v);%(AdditionalDependencies)</AdditionalDependencies>$nl") }
        $v = Get-Attr $link 'OutputFile';                                if ($v) { [void]$sb.Append("      <OutputFile>$(XmlEnc $v)</OutputFile>$nl") }
        $v = Get-Attr $link 'AdditionalLibraryDirectories';              if ($v) { [void]$sb.Append("      <AdditionalLibraryDirectories>$(XmlEnc $v);%(AdditionalLibraryDirectories)</AdditionalLibraryDirectories>$nl") }
        $v = Get-Attr $link 'SuppressStartupBanner';                     if ($v -eq 'true') { [void]$sb.Append("      <SuppressStartupBanner>true</SuppressStartupBanner>$nl") }
        $v = Get-Attr $link 'GenerateDebugInformation';                  if ($v -eq 'true') { [void]$sb.Append("      <GenerateDebugInformation>true</GenerateDebugInformation>$nl") }
        $v = Get-Attr $link 'ProgramDatabaseFile';                       if ($v) { [void]$sb.Append("      <ProgramDatabaseFile>$(XmlEnc $v)</ProgramDatabaseFile>$nl") }
        $v = MapEnum $mapSubSystem (Get-Attr $link 'SubSystem');          if ($v) { [void]$sb.Append("      <SubSystem>$v</SubSystem>$nl") }
        $v = MapEnum $mapMachine (Get-Attr $link 'TargetMachine');        if ($v) { [void]$sb.Append("      <TargetMachine>$v</TargetMachine>$nl") }
        [void]$sb.Append('    </Link>' + $nl)

        [void]$sb.Append('  </ItemDefinitionGroup>' + $nl)
    }

    # ---- Listes de fichiers --------------------------------------------
    $entries = @(Get-FileEntries $xmlRoot.Files $null)
    $byKind = @{ ClCompile = @(); ClInclude = @(); ResourceCompile = @(); None = @() }
    foreach ($e in $entries) { $byKind[(Classify $e.Path)] += $e }

    foreach ($kind in 'ClCompile', 'ClInclude', 'ResourceCompile', 'None') {
        $items = $byKind[$kind]
        if (-not $items) { continue }
        [void]$sb.Append('  <ItemGroup>' + $nl)
        foreach ($e in $items) {
            [void]$sb.Append("    <$kind Include=`"$(XmlEnc $e.Path)`" />$nl")
        }
        [void]$sb.Append('  </ItemGroup>' + $nl)
    }

    # ---- Targets -------------------------------------------------------
    [void]$sb.Append('  <Import Project="$(VCTargetsPath)\Microsoft.Cpp.targets" />' + $nl)
    [void]$sb.Append('  <ImportGroup Label="ExtensionTargets">' + $nl)
    [void]$sb.Append('  </ImportGroup>' + $nl)
    [void]$sb.Append('</Project>' + $nl)

    # ---- Écriture .vcxproj (UTF-8 BOM) ---------------------------------
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [IO.File]::WriteAllText($vcxprojPath, $sb.ToString(), $utf8Bom)

    # ---- Génération du .vcxproj.filters --------------------------------
    Write-FiltersFile -VcxprojPath $vcxprojPath -Entries $entries

    Write-Host "  + $([IO.Path]::GetFileName($vcprojPath))  ->  $([IO.Path]::GetFileName($vcxprojPath))  ($($entries.Count) fichiers)"
}

function Write-FiltersFile([string]$VcxprojPath, $Entries) {
    $nl = "`r`n"
    $filtersPath = "$VcxprojPath.filters"

    # Ensemble des filtres (et de leurs parents) à déclarer.
    $filterSet = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($e in $Entries) {
        $f = $e.Filter
        while ($f) {
            [void]$filterSet.Add($f)
            $idx = $f.LastIndexOf('\')
            $f = if ($idx -ge 0) { $f.Substring(0, $idx) } else { $null }
        }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('<?xml version="1.0" encoding="utf-8"?>' + $nl)
    [void]$sb.Append('<Project ToolsVersion="Current" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' + $nl)

    # Déclaration des filtres.
    [void]$sb.Append('  <ItemGroup>' + $nl)
    foreach ($f in ($filterSet | Sort-Object)) {
        $g = New-StableGuid $f
        [void]$sb.Append("    <Filter Include=`"$(XmlEnc $f)`">$nl")
        [void]$sb.Append("      <UniqueIdentifier>{$g}</UniqueIdentifier>$nl")
        [void]$sb.Append('    </Filter>' + $nl)
    }
    [void]$sb.Append('  </ItemGroup>' + $nl)

    # Affectation des fichiers à leur filtre, groupés par type d'item.
    $byKind = @{ ClCompile = @(); ClInclude = @(); ResourceCompile = @(); None = @() }
    foreach ($e in $Entries) { $byKind[(Classify $e.Path)] += $e }

    foreach ($kind in 'ClCompile', 'ClInclude', 'ResourceCompile', 'None') {
        $items = $byKind[$kind]
        if (-not $items) { continue }
        [void]$sb.Append('  <ItemGroup>' + $nl)
        foreach ($e in $items) {
            if ($e.Filter) {
                [void]$sb.Append("    <$kind Include=`"$(XmlEnc $e.Path)`">$nl")
                [void]$sb.Append("      <Filter>$(XmlEnc $e.Filter)</Filter>$nl")
                [void]$sb.Append("    </$kind>$nl")
            } else {
                [void]$sb.Append("    <$kind Include=`"$(XmlEnc $e.Path)`" />$nl")
            }
        }
        [void]$sb.Append('  </ItemGroup>' + $nl)
    }

    [void]$sb.Append('</Project>' + $nl)

    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [IO.File]::WriteAllText($filtersPath, $sb.ToString(), $utf8Bom)
}

# ---------------------------------------------------------------------------
# Programme principal
# ---------------------------------------------------------------------------
if ($Path) {
    Write-Host "Conversion de : $Path"
    Convert-OneProject $Path
} else {
    Write-Host "Conversion de tous les .vcproj sous : $Root"
    $files = Get-ChildItem -Path $Root -Recurse -Filter '*.vcproj' -File |
        Where-Object { $_.FullName -notmatch '[\\/]Backup[\\/]' } |
        Sort-Object FullName
    foreach ($f in $files) { Convert-OneProject $f.FullName }
}

Write-Host ""
Write-Host "Terminé."
