$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Variables

$cursedFolderPath = "$env:LOCALAPPDATA\cursed"
$cursedOldFolderPath = "$HOME\cursed-cli"

# Functions

function Write-Success {
Write-Host ' > OK' -ForegroundColor Green
}

function Write-Unsuccess {
Write-Host ' > ERROR' -ForegroundColor Red
}

function Test-Admin {
Write-Host 'Checking if the script is not being run as administrator...' -NoNewline

```
$currentUser = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

return -not $currentUser.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
```

}

function Test-PowerShellVersion {
$PSMinVersion = [version]'5.1'

```
Write-Host 'Checking if your PowerShell version is compatible...' -NoNewline

return $PSVersionTable.PSVersion -ge $PSMinVersion
```

}

function Move-OldCursedFolder {
if (Test-Path -Path $cursedOldFolderPath) {
Write-Host 'Moving the old cursed folder...' -NoNewline

```
    if (-not (Test-Path -Path $cursedFolderPath)) {
        New-Item -ItemType Directory -Path $cursedFolderPath -Force | Out-Null
    }

    Copy-Item `
        -Path "$cursedOldFolderPath\*" `
        -Destination $cursedFolderPath `
        -Recurse `
        -Force

    Remove-Item `
        -Path $cursedOldFolderPath `
        -Recurse `
        -Force

    Write-Success
}
```

}

function Get-Cursed {
if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') {
$architecture = 'x64'
}
elseif ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
$architecture = 'arm64'
}
else {
$architecture = 'x32'
}

```
if ($v) {
    if ($v -match '^\d+\.\d+\.\d+$') {
        $targetVersion = $v
    }
    else {
        Write-Warning "Invalid cursed version: $v"
        Write-Warning 'The version must use the format: 1.2.3'
        exit
    }
}
else {
    Write-Host 'Fetching the latest cursed version...' -NoNewline

    $latestRelease = Invoke-RestMethod `
        -Uri 'https://api.github.com/repos/cursed77772/cursed-cli/releases/latest'

    $targetVersion = $latestRelease.tag_name -replace '^v', ''

    Write-Success
}

$archivePath = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    'cursed.zip'

Write-Host "Downloading cursed v$targetVersion..." -NoNewline

$downloadUrl = "https://github.com/cursed77772/cursed-cli/releases/download/v$targetVersion/cursed-$targetVersion-windows-$architecture.zip"

Invoke-WebRequest `
    -Uri $downloadUrl `
    -UseBasicParsing `
    -OutFile $archivePath

Write-Success

return $archivePath
```

}

function Add-CursedToPath {
Write-Host 'Making cursed available in the PATH...' -NoNewline

```
$user = [EnvironmentVariableTarget]::User
$path = [Environment]::GetEnvironmentVariable('PATH', $user)

if ($path -notlike "*$cursedFolderPath*") {
    $path = "$path;$cursedFolderPath"
}

[Environment]::SetEnvironmentVariable(
    'PATH',
    $path,
    $user
)

if (($env:PATH -split ';') -notcontains $cursedFolderPath) {
    $env:PATH = "$env:PATH;$cursedFolderPath"
}

Write-Success
```

}

function Install-Cursed {
Write-Host 'Installing cursed...'

```
$archivePath = Get-Cursed

if (-not (Test-Path -Path $cursedFolderPath)) {
    New-Item `
        -ItemType Directory `
        -Path $cursedFolderPath `
        -Force | Out-Null
}

Write-Host 'Extracting cursed...' -NoNewline

Expand-Archive `
    -Path $archivePath `
    -DestinationPath $cursedFolderPath `
    -Force

Write-Success

Add-CursedToPath

Remove-Item `
    -Path $archivePath `
    -Force `
    -ErrorAction SilentlyContinue

Write-Host 'cursed was successfully installed!' -ForegroundColor Green
```

}

# Checks

if (-not (Test-PowerShellVersion)) {
Write-Unsuccess

```
Write-Warning 'PowerShell 5.1 or higher is required to run this script.'
Write-Warning "You are running PowerShell $($PSVersionTable.PSVersion)."

Pause
exit
```

}
else {
Write-Success
}

if (-not (Test-Admin)) {
Write-Unsuccess

```
Write-Warning 'The script is running as administrator.'
Write-Warning 'This can cause problems with the installation process.'

$Host.UI.RawUI.FlushInputBuffer()

$choices = [System.Management.Automation.Host.ChoiceDescription[]] @(
    (New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Abort installation.'),
    (New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'Resume installation.')
)

$choice = $Host.UI.PromptForChoice(
    '',
    'Do you want to abort the installation process?',
    $choices,
    0
)

if ($choice -eq 0) {
    Write-Host 'cursed installation aborted' -ForegroundColor Yellow
    Pause
    exit
}
```

}
else {
Write-Success
}

# Check existing installation

$installedCursed = Join-Path `    $cursedFolderPath`
'cursed.exe'

if (-not (Test-Path -LiteralPath $installedCursed -PathType Leaf)) {
$installedCommand = Get-Command `        -Name 'cursed'`
-CommandType Application `
-ErrorAction SilentlyContinue |
Select-Object -First 1

```
if ($installedCommand) {
    $installedCursed = $installedCommand.Source
}
else {
    $installedCursed = $null
}
```

}

if ($installedCursed) {
$Host.UI.RawUI.FlushInputBuffer()

```
$choices = [System.Management.Automation.Host.ChoiceDescription[]] @(
    (New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Run cursed update.'),
    (New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'Continue with installation.')
)

$choice = $Host.UI.PromptForChoice(
    '',
    'Cursed is already installed. Do you want to update it?',
    $choices,
    0
)

if ($choice -eq 0) {
    & $installedCursed update

    if ($LASTEXITCODE -ne 0) {
        throw "Cursed update failed with exit code $LASTEXITCODE."
    }

    exit
}
```

}

# Install

Move-OldCursedFolder
Install-Cursed

Write-Host ''
Write-Host 'Run ' -NoNewline
Write-Host 'cursed -h' -ForegroundColor Cyan -NoNewline
Write-Host ' to get started.'
