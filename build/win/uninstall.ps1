#Requires -Version 5.1
# [nocturne] Removes what the portable Windows build leaves outside its own folder.
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Force,
  [switch]$KeepConfig,
  [switch]$RemoveAppFolder
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$appRoot = $PSScriptRoot
$exeName = 'Typewriter Nocturne.exe'
$binPath = Join-Path $appRoot 'resources\bin'

if (-not (Test-Path -LiteralPath (Join-Path $appRoot $exeName)) -or
    -not (Test-Path -LiteralPath (Join-Path $appRoot 'resources'))) {
  throw "This script must sit beside '$exeName' in the extracted folder. Not found in: $appRoot"
}

$running = @(Get-CimInstance Win32_Process | Where-Object {
    $_.ExecutablePath -and $_.ExecutablePath.StartsWith($appRoot + '\', [StringComparison]::OrdinalIgnoreCase)
  })
if ($running.Count -gt 0) {
  throw "Typewriter Nocturne is still running from this folder ($($running.Count) process(es)). Close it and run again."
}

function Get-DefaultValue {
  param([string]$Path)
  if (Test-Path -LiteralPath $Path) { return (Get-Item -LiteralPath $Path).GetValue('') }
  return $null
}

# A second extracted copy may own the same association; only claim what points here.
function Test-PointsHere {
  param([string]$Command)
  return ($Command -and $Command.IndexOf($appRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0)
}

$plan = @()

if (-not $KeepConfig) {
  $dataDirs = @(Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Typewriter Nocturne')
  # paths.ts honours XDG_CONFIG_HOME ahead of userData on every platform, Windows included.
  if ($env:XDG_CONFIG_HOME) {
    $dataDirs += Join-Path $env:XDG_CONFIG_HOME 'TypewriterNocturne'
  }
  foreach ($dir in $dataDirs) {
    if (Test-Path -LiteralPath $dir) {
      $plan += [pscustomobject]@{Kind = 'dir'; Path = $dir; Name = ''; Detail = 'settings, plugins, caches' }
    }
  }
}

foreach ($key in @(
    'HKCU:\Software\Classes\Directory\Background\shell\TypewriterNocturne',
    'HKCU:\Software\Classes\Directory\shell\TypewriterNocturne',
    'HKCU:\Software\Classes\Drive\shell\TypewriterNocturne'
  )) {
  if (Test-Path -LiteralPath $key) {
    $command = Get-DefaultValue "$key\command"
    if (Test-PointsHere $command) {
      $plan += [pscustomobject]@{Kind = 'regtree'; Path = $key; Name = ''; Detail = 'Explorer context menu' }
    } else {
      Write-Host "Leaving context menu alone (owned by another copy): $key" -ForegroundColor DarkGray
    }
  }
}

$envKeyPath = 'HKCU:\Environment'
$envKey = Get-Item -LiteralPath $envKeyPath
$pathName = @($envKey.GetValueNames() | Where-Object { $_ -ieq 'Path' })[0]
$pathEntries = @()
if ($pathName) {
  $pathKind = $envKey.GetValueKind($pathName)
  $pathRaw = $envKey.GetValue($pathName, '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
  $pathEntries = @($pathRaw -split ';' | Where-Object {
      $_.Trim().TrimEnd('\') -ne $binPath.TrimEnd('\')
    })
  if ($pathEntries.Count -lt @($pathRaw -split ';').Count) {
    $plan += [pscustomobject]@{
      Kind = 'path'; Path = $envKeyPath; Name = $pathName; Detail = "removes $binPath"
    }
  }
}

$sshKey = 'HKCU:\Software\Classes\ssh'
if (Test-PointsHere (Get-DefaultValue "$sshKey\shell\open\command")) {
  $plan += [pscustomobject]@{Kind = 'regtree'; Path = $sshKey; Name = ''; Detail = 'ssh:// protocol handler' }

  $regAppsPath = 'HKCU:\Software\RegisteredApplications'
  if (Test-Path -LiteralPath $regAppsPath) {
    $regApps = Get-Item -LiteralPath $regAppsPath
    foreach ($name in $regApps.GetValueNames()) {
      $capPath = Join-Path 'HKCU:\Software' ([string]$regApps.GetValue($name))
      $assocPath = Join-Path $capPath 'URLAssociations'
      if (-not (Test-Path -LiteralPath $assocPath)) { continue }
      $assoc = Get-Item -LiteralPath $assocPath
      $sshValue = @($assoc.GetValueNames() | Where-Object { $_ -ieq 'ssh' })[0]
      if (-not $sshValue) { continue }
      $plan += [pscustomobject]@{
        Kind = 'regvalue'; Path = $assocPath; Name = $sshValue; Detail = "default-apps claim ($name)"
      }
      $remaining = @($assoc.GetValueNames() | Where-Object { $_ -ine $sshValue })
      $hasOtherAssociations = (Test-Path -LiteralPath (Join-Path $capPath 'FileAssociations')) -or
                              (Test-Path -LiteralPath (Join-Path $capPath 'MIMEAssociations'))
      if ($remaining.Count -eq 0 -and -not $hasOtherAssociations) {
        $plan += [pscustomobject]@{Kind = 'regtree'; Path = $capPath; Name = ''; Detail = 'empty capabilities key' }
        $plan += [pscustomobject]@{
          Kind = 'regvalue'; Path = $regAppsPath; Name = $name; Detail = 'default-apps registration'
        }
      }
    }
  }
}

if ($RemoveAppFolder) {
  $plan += [pscustomobject]@{Kind = 'appfolder'; Path = $appRoot; Name = ''; Detail = 'the extracted application' }
}

if ($plan.Count -eq 0) {
  Write-Host 'Nothing to clean: no Typewriter Nocturne leftovers found outside this folder.' -ForegroundColor Green
  return
}

Write-Host ''
Write-Host 'Typewriter Nocturne portable cleanup' -ForegroundColor Cyan
Write-Host "Application folder: $appRoot"
Write-Host ''
Write-Host 'This will remove:'
foreach ($item in $plan) {
  $label = if ($item.Name) { "$($item.Path) -> $($item.Name)" } else { $item.Path }
  Write-Host "  [$($item.Kind)] $label" -ForegroundColor Yellow
  Write-Host "        $($item.Detail)" -ForegroundColor DarkGray
}
if ($KeepConfig) {
  Write-Host ''
  Write-Host 'Settings and plugins are kept (-KeepConfig).' -ForegroundColor DarkGray
}
Write-Host ''

if ($DryRun) {
  Write-Host 'Dry run: nothing was changed.' -ForegroundColor Cyan
  return
}

if (-not $Force) {
  $answer = Read-Host 'Settings and plugins cannot be recovered. Proceed? (y/N)'
  if ($answer -notmatch '^(y|yes)$') {
    Write-Host 'Cancelled. Nothing was changed.'
    return
  }
}

$failed = @()
foreach ($item in $plan) {
  if ($item.Kind -eq 'appfolder') { continue }
  try {
    switch ($item.Kind) {
      'dir' { Remove-Item -LiteralPath $item.Path -Recurse -Force }
      'regtree' { Remove-Item -LiteralPath $item.Path -Recurse -Force }
      'regvalue' { Remove-ItemProperty -LiteralPath $item.Path -Name $item.Name -Force }
      'path' {
        Set-ItemProperty -LiteralPath $item.Path -Name $item.Name -Value ($pathEntries -join ';') -Type $pathKind
      }
    }
    Write-Host "  removed $($item.Path)" -ForegroundColor Green
  } catch {
    $failed += $item.Path
    Write-Host "  FAILED  $($item.Path): $($_.Exception.Message)" -ForegroundColor Red
  }
}

if (@($plan | Where-Object { $_.Kind -eq 'path' }).Count -gt 0 -and $failed -notcontains $envKeyPath) {
  # Explorer caches the environment block; without this broadcast PATH changes need a logoff.
  if (-not ('Nocturne.Native' -as [type])) {
    Add-Type -Namespace Nocturne -Name Native -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, string lParam,
  uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
'@
  }
  $result = [IntPtr]::Zero
  [Nocturne.Native]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [IntPtr]::Zero, 'Environment', 2, 5000, [ref]$result) |
    Out-Null
}

if ($RemoveAppFolder -and $failed.Count -eq 0) {
  # This script lives inside the folder it deletes, so the removal has to outlive the process.
  $delay = '/c ping -n 4 127.0.0.1 >nul & rmdir /s /q "' + $appRoot + '"'
  Start-Process -FilePath $env:ComSpec -ArgumentList $delay -WindowStyle Hidden
  Write-Host ''
  Write-Host "The application folder will be deleted in a few seconds: $appRoot" -ForegroundColor Cyan
}

Write-Host ''
if ($failed.Count -gt 0) {
  Write-Host "Done, but $($failed.Count) item(s) could not be removed. Close the app and re-run." -ForegroundColor Yellow
  exit 1
}
Write-Host 'Done.' -ForegroundColor Green
if (-not $RemoveAppFolder) {
  Write-Host "You can now delete the application folder yourself: $appRoot"
}