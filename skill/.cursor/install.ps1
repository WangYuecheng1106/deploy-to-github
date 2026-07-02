# Installs the deploy-to-github skill into Cursor's user skills directory.
# Usage:  pwsh -File install.ps1           (user-level, all projects)
#         pwsh -File install.ps1 -Project  (project-level, current project only)

param(
    [switch]$Project
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Source    = Join-Path $ScriptDir "skill-skeleton"

if (-not (Test-Path (Join-Path $Source "SKILL.md"))) {
    Write-Error "skill-skeleton/SKILL.md not found next to install.ps1. Run this script from the repo root."
    exit 1
}

if ($Project) {
    $Dest = Join-Path (Get-Location) ".cursor/skills/deploy-to-github"
} else {
    $Dest = Join-Path $HOME ".cursor/skills/deploy-to-github"
}

Write-Host "Installing deploy-to-github skill to: $Dest"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

Copy-Item -Path (Join-Path $Source "*") -Destination $Dest -Recurse -Force
Write-Host "Done."
Write-Host ""
Write-Host "Verify with:"
Write-Host "  python `"$Dest/scripts/deploy_helper.py`" check"
