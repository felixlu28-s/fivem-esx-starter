# Installs pinned, unmodified upstream dependencies. Existing resources are preserved.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$cacheRoot = Join-Path $projectRoot '.codex-log/esx-dependencies'
New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
$packages = @(
    @{ Repository = 'ESX-Legacy-Addons'; Commit = 'ccda737f7d4f73d224fab2097bee5083afd4dd4e'; Folder = '[esx_addons]'; Target = '[esx]'; Resources = @('esx_addonaccount', 'esx_addoninventory', 'esx_datastore', 'esx_society') },
    @{ Repository = 'esx_core'; Commit = 'ddd71a58f1ea6279d68413fb4a44e0ef34ede2fa'; Folder = '[core]'; Target = '[core]'; Resources = @('cron') }
)
foreach ($package in $packages) {
    $checkout = Join-Path $cacheRoot ($package.Repository + '-' + $package.Commit)
    if (-not (Test-Path -LiteralPath $checkout)) {
        & git clone --filter=blob:none --no-checkout ('https://github.com/esx-framework/' + $package.Repository + '.git') $checkout
        if ($LASTEXITCODE -ne 0) { throw 'Dependency clone failed.' }
    }
    & git -C $checkout checkout --detach $package.Commit
    if ($LASTEXITCODE -ne 0) { throw 'Pinned dependency checkout failed.' }
    foreach ($resource in $package.Resources) {
        $destination = Join-Path $projectRoot ('server-data/resources/' + $package.Target + '/' + $resource)
        if (Test-Path -LiteralPath $destination) {
            if (-not (Test-Path -LiteralPath (Join-Path $destination 'fxmanifest.lua'))) { throw "Incomplete existing resource: $resource" }
            Write-Output "Preserved existing resource: $resource (not overwritten or version-verified)"
            continue
        }
        $resourceSource = Join-Path $checkout ($package.Folder + '/' + $resource)
        New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
        Copy-Item -LiteralPath $resourceSource -Destination $destination -Recurse
        Write-Output "Installed $resource at upstream commit $($package.Commit)"
    }
}
Write-Output 'Apply rp_organizations/migrations/001_organizations.sql before starting the dependencies. Follow server.cfg.example for start order and ACE permissions.'
