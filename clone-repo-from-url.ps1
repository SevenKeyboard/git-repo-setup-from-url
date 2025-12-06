#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#===========================================================
# This script:
#   - Prompts for GitHub repository URLs (HTTPS only),
#   - Uses the directory of this script as the base folder,
#   - Creates (or reuses if empty) a working folder named after the repository,
#   - Runs "git clone" into that folder,
#   - Repeats for multiple repositories until the user enters a blank URL.
#   - If any cloning operation fails, the script stops.
#===========================================================

# Base directory for repositories: the directory where this script (.ps1) resides
$BaseDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

function Pause-End {
    param(
        [string]$Message = ''
    )

    if ($Message) {
        Write-Host ''
        Write-Host $Message
    }

    Write-Host ''
    Write-Host 'Press any key to exit...'
    [void][System.Console]::ReadKey($true)
    exit
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [string]$ErrorMessage = 'An error occurred while executing a Git command.'
    )

    git @Arguments

    if ($LASTEXITCODE -ne 0) {
        $cmdText = 'git ' + ($Arguments -join ' ')
        throw "$ErrorMessage`nCommand: $cmdText`nExit code: $LASTEXITCODE"
    }
}

function Invoke-RepoClone {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoUrl
    )

    # Trim whitespace
    $RepoUrl = $RepoUrl.Trim()

    #-------------------------------------------------------
    # 1. Parse URL → Owner / Repo name / working folder
    #-------------------------------------------------------
    try {
        $uri = [Uri]$RepoUrl
    }
    catch {
        throw "The URL is not valid: $RepoUrl"
    }

    if ($uri.Host -notin @('github.com', 'www.github.com')) {
        throw "The URL does not appear to be a GitHub URL: $RepoUrl"
    }

    # Extract segments from /owner/repo[...] in the path
    $segments = $uri.AbsolutePath.Trim('/') -split '/'
    if ($segments.Count -lt 2) {
        throw "The URL does not match the expected GitHub repository format: $RepoUrl"
    }

    # Typical GitHub URL: /Owner/Repo[/...]
    $Owner    = $segments[0]
    $RepoName = $segments[1]

    # Strip trailing ".git" if present
    $RepoName = $RepoName -replace '\.git$', ''

    $WorkDir  = Join-Path $BaseDir $RepoName

    Write-Host ''
    Write-Host '==========================================='
    Write-Host " GitHub Owner : $Owner"
    Write-Host " Repository   : $RepoName"
    Write-Host " Repo URL     : $RepoUrl"
    Write-Host " Base Folder  : $BaseDir"
    Write-Host " Work Folder  : $WorkDir"
    Write-Host '==========================================='
    Write-Host ''

    #-------------------------------------------------------
    # 2. Check working folder
    #-------------------------------------------------------
    if (Test-Path $WorkDir) {
        # Count all items inside the directory (including hidden ones)
        $itemCount = (Get-ChildItem -Path $WorkDir -Force | Measure-Object).Count

        if ($itemCount -gt 0) {
            throw "The working folder already exists and is not empty: $WorkDir`nTo avoid overwriting existing content, the operation for this repository will stop."
        }
        else {
            Write-Host "The working folder already exists but is empty. It will be reused."
        }
    }

    #-------------------------------------------------------
    # 3. Check if "git" is available
    #    (In practice this will be true if the first call worked, but we keep it defensive here.)
    #-------------------------------------------------------
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "The 'git' command could not be found. Please make sure Git is installed and available in PATH."
    }

    #-------------------------------------------------------
    # 4. Clone repository into the working folder
    #-------------------------------------------------------
    # Run "git clone <URL> <RepoName>" from the base directory.
    Set-Location $BaseDir

    Write-Host '>>> Running "git clone"...'
    Invoke-Git -Arguments @('clone', $RepoUrl, $RepoName) `
               -ErrorMessage 'Failed to run "git clone".'

    # Move into the cloned repository
    Set-Location $WorkDir

    #-------------------------------------------------------
    # 5. Per-repository summary
    #-------------------------------------------------------
    Write-Host ''
    Write-Host 'Repository cloned successfully.'
    Write-Host "Location: $WorkDir"
}

try {
    #-------------------------------------------------------
    # Main loop: process multiple repository URLs
    #   - Blank input → exit the script.
    #   - Any failure → exit via catch.
    #-------------------------------------------------------
    while ($true) {
        Write-Host ''
        Write-Host 'Enter the GitHub repository URL (HTTPS only, e.g., https://github.com/user/repo)'
        $RepoUrl = Read-Host 'Repository URL (blank to exit)'

        if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
            break
        }

        Invoke-RepoClone -RepoUrl $RepoUrl
        # On success, the loop continues and prompts for the next URL.
    }

    Pause-End 'Script finished successfully.'
}
catch {
    Write-Host ''
    Write-Error $_ -ErrorAction Continue
    Pause-End 'The script was terminated due to an error.'
}
