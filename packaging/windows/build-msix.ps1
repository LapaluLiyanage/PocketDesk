# SPDX-License-Identifier: GPL-3.0-or-later
# Builds the Microsoft Store package (unsigned .msix; the Store signs it).
#
#   ./build-msix.ps1 -Version 0.8.0 -Agent ..\..\agent\target\release -Out PocketDesk.msix `
#     -IdentityName 12345LapaluLiyanage.PocketDesk -Publisher "CN=…" -PublisherName "Lapalu Liyanage"
#
# The identity values are on Partner Center → PocketDesk → Product identity.
# Needs makeappx.exe from the Windows SDK (on GitHub's Windows runners).
param(
  [Parameter(Mandatory)] [string] $Version,
  [Parameter(Mandatory)] [string] $Agent,   # folder with pocketdesk.exe and pocketdesk-startup.exe
  [Parameter(Mandatory)] [string] $Out,
  [string] $IdentityName = "LapaluLiyanage.PocketDesk",
  [string] $Publisher = "CN=Lapalu Liyanage",
  [string] $PublisherName = "Lapalu Liyanage"
)
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$stage = Join-Path ([IO.Path]::GetTempPath()) ("pocketdesk-msix-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $stage "Assets") | Out-Null

Copy-Item (Join-Path $Agent "pocketdesk.exe") $stage
Copy-Item (Join-Path $Agent "pocketdesk-startup.exe") $stage
Copy-Item (Join-Path $here "..\icons\msix\*.png") (Join-Path $stage "Assets")
Copy-Item (Join-Path $here "..\..\LICENSE") (Join-Path $stage "LICENSE.txt")

# MSIX versions have four parts and the last must be 0 for the Store.
$v = ($Version -split '[-+]')[0]
$manifest = Get-Content (Join-Path $here "msix\AppxManifest.xml") -Raw
$manifest = $manifest.Replace("@VERSION@", "$v.0").Replace("@IDENTITY_NAME@", $IdentityName)
$manifest = $manifest.Replace("@PUBLISHER@", [Security.SecurityElement]::Escape($Publisher))
$manifest = $manifest.Replace("@PUBLISHER_NAME@", [Security.SecurityElement]::Escape($PublisherName))
Set-Content -Path (Join-Path $stage "AppxManifest.xml") -Value $manifest -Encoding UTF8

$makeappx = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\makeappx.exe" |
  Sort-Object FullName -Descending | Select-Object -First 1
if (-not $makeappx) { throw "makeappx.exe not found (install the Windows SDK)" }
& $makeappx.FullName pack /o /d $stage /p $Out
if ($LASTEXITCODE -ne 0) { throw "makeappx failed ($LASTEXITCODE)" }
Remove-Item -Recurse -Force $stage
Write-Host "Built $Out"
