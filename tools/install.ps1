<#
.SYNOPSIS
Copies this checkout into a WoW AddOns folder under the name the client expects.

.DESCRIPTION
WoW resolves UmbraUnitFrames_Mainline.toc only inside a folder named
UmbraUnitFrames, so a clone directory named after the repository is never
looked at. This script copies to the right name, fetches oUF if it is missing,
and leaves out everything that does not belong in an addon folder.

The WoW path is remembered in tools/.wowpath after the first run.

.EXAMPLE
.\tools\install.ps1 -WowPath "C:\Games\World of Warcraft"

.EXAMPLE
.\tools\install.ps1 -Flavor forever
#>
[CmdletBinding()]
param(
	[string]$WowPath,

	[ValidateSet('retail', 'forever')]
	[string]$Flavor = 'retail',

	[string]$OufTag = '14.0.3'
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$pathFile = Join-Path $PSScriptRoot '.wowpath'

if (-not $WowPath) {
	if (Test-Path $pathFile) {
		$WowPath = (Get-Content $pathFile -Raw).Trim()
	} else {
		throw "No WoW path known. Pass -WowPath once, for example: .\tools\install.ps1 -WowPath 'C:\Games\World of Warcraft'"
	}
}

if (-not (Test-Path $WowPath)) {
	throw "WoW path does not exist: $WowPath"
}

Set-Content -Path $pathFile -Value $WowPath -Encoding utf8

$clientDir = if ($Flavor -eq 'forever') { '_classic_beta_' } else { '_retail_' }
$addons = Join-Path $WowPath "$clientDir\Interface\AddOns"

if (-not (Test-Path $addons)) {
	throw "AddOns folder not found: $addons"
}

# oUF is fetched at build time and is not part of the repository, so a fresh
# checkout has nothing to load.
$ouf = Join-Path $repo 'Libs\oUF'
if (-not (Test-Path (Join-Path $ouf 'oUF.xml'))) {
	Write-Host "Fetching oUF $OufTag into Libs/oUF"
	git clone --quiet --depth 1 --branch $OufTag https://github.com/oUF-wow/oUF.git $ouf
}

$target = Join-Path $addons 'UmbraUnitFrames'

# /MIR so that files deleted in the checkout also disappear from the install.
$excludeDirs = @('.git', '.github', 'docs', 'assets', 'tools', '.release')
robocopy $repo $target /MIR /XD @excludeDirs /XF '.gitignore' '.gitattributes' '.luacheckrc' '.pkgmeta' /NFL /NDL /NJH /NJS /NP | Out-Null

# robocopy exit codes below 8 are success; 8 and above are genuine failures.
if ($LASTEXITCODE -ge 8) {
	throw "robocopy failed with exit code $LASTEXITCODE"
}

# /MIR does not delete what /XD and /XF skipped, so an earlier hand-copy of the
# whole repository would leave its .git and docs behind forever.
foreach ($stale in $excludeDirs + @('.gitignore', '.gitattributes', '.luacheckrc', '.pkgmeta')) {
	$path = Join-Path $target $stale
	if (Test-Path $path) {
		Remove-Item -Path $path -Recurse -Force
	}
}

# The packager substitutes @project-version@ on release. A checkout has no
# release to name, so the installed copy gets the commit it was built from,
# which beats the raw token showing up in the addon list.
$version = 'dev'
$sha = (git -C $repo rev-parse --short HEAD 2>$null)
if ($LASTEXITCODE -eq 0 -and $sha) {
	$version = "dev-$sha"
	git -C $repo diff --quiet HEAD 2>$null
	if ($LASTEXITCODE -ne 0) { $version += '-dirty' }
}

foreach ($toc in Get-ChildItem -Path $target -Filter '*.toc') {
	$text = [System.IO.File]::ReadAllText($toc.FullName)
	$text = $text -replace '@project-version@', $version
	[System.IO.File]::WriteAllText($toc.FullName, $text, (New-Object System.Text.UTF8Encoding $false))
}

Write-Host "Installed to $target as $version"
Write-Host "Restart the client fully: a newly added addon folder is only read at launch."

# robocopy answers 1 for "files were copied" and git diff --quiet answers 1 for
# "the tree is dirty". Both are ordinary outcomes here, and both leave
# $LASTEXITCODE behind as this script's own exit code, which made a successful
# run look like a failed one. Anything that genuinely went wrong has thrown by
# this point.
exit 0
