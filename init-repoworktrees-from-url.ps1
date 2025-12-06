#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#===========================================================
# This script:
#   - Prompts for a GitHub repository URL,
#   - Uses the directory of this script as the base working folder,
#   - Performs a bare clone into a ".repo" directory,
#   - Creates a worktree for each remote "origin" branch,
#   - Sets the upstream of each local branch to "origin/<branch>".
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

try {
    #-------------------------------------------------------
    # 1. Read repository URL
    #-------------------------------------------------------

    # HTTPS URLs only (with or without the .git suffix).
    Write-Host 'Enter the GitHub repository URL (HTTPS only, e.g., https://github.com/user/repo)'
    $RepoUrl = Read-Host 'Repository URL'

    if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
        throw 'No repository URL was entered. Aborting.'
    }

    # Trim whitespace
    $RepoUrl = $RepoUrl.Trim()

    #-------------------------------------------------------
    # 2. Parse URL → Owner / Repo name / working folder
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

    # Check if working folder already exists
    if (Test-Path $WorkDir) {
        # Count all items inside the directory (including hidden ones)
        $itemCount = (Get-ChildItem -Path $WorkDir -Force | Measure-Object).Count

        if ($itemCount -gt 0) {
            throw "The working folder already exists and is not empty: $WorkDir`nTo avoid overwriting existing content, the script will stop."
        }
        else {
            Write-Host "The working folder already exists but is empty. It will be reused."
        }
    }


    # Check if "git" is available
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "The 'git' command could not be found. Please make sure Git is installed and available in PATH."
    }

    #-------------------------------------------------------
    # 3. Create working folder and change directory
    #-------------------------------------------------------
    if (-not (Test-Path $WorkDir)) {
        New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    }
    Set-Location $WorkDir

    #-------------------------------------------------------
    # 4. Perform bare clone
    #-------------------------------------------------------
    Write-Host '>>> Running "git clone --bare"...'
    Invoke-Git -Arguments @('clone', '--bare', $RepoUrl, '.repo') `
               -ErrorMessage 'Failed to run "git clone --bare".'

    #-------------------------------------------------------
    # 5. Configure remote.origin.fetch and fetch
    #-------------------------------------------------------
    Write-Host '>>> Configuring remote.origin.fetch...'
    Invoke-Git -Arguments @('--git-dir=.repo', 'config', 'remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*') `
               -ErrorMessage 'Failed to configure remote.origin.fetch.'

    Write-Host '>>> Running "git fetch origin"...'
    Invoke-Git -Arguments @('--git-dir=.repo', 'fetch', 'origin') `
               -ErrorMessage 'Failed to run "git fetch origin".'

    #-------------------------------------------------------
    # 6. Collect remote branch list
    #-------------------------------------------------------
    Write-Host '>>> Retrieving remote branch list...'

    $remoteBranchesRaw = @(
        git --git-dir=.repo for-each-ref --format="%(refname:short)" "refs/remotes/origin/*"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve the remote branch list."
    }

    $RemoteBranches = @(
        $remoteBranchesRaw |
        Where-Object { $_ -and ($_ -notlike 'origin/HEAD*') -and ($_ -ne 'origin') } |
        ForEach-Object { $_ -replace '^origin/', '' } |
        Sort-Object -Unique
    )

    if (-not $RemoteBranches -or $RemoteBranches.Count -eq 0) {
        throw "No usable branches were found under the remote 'origin'."
    }

    Write-Host 'Remote branches under origin:'
    foreach ($b in $RemoteBranches) {
        Write-Host " - $b"
    }
    Write-Host ''

    #-------------------------------------------------------
    # 7. Create worktrees for each branch
    #-------------------------------------------------------
    foreach ($branch in $RemoteBranches) {
        Write-Host ">>> Adding worktree... (branch: $branch)"
        Invoke-Git -Arguments @('--git-dir=.repo', 'worktree', 'add', $branch, $branch) `
                   -ErrorMessage "Failed to add worktree. (branch: $branch)"
    }

    #-------------------------------------------------------
    # 8. Set upstream for each branch (branch -> origin/branch)
    #-------------------------------------------------------
    foreach ($branch in $RemoteBranches) {
        $originBranch = "origin/$branch"
        Write-Host ">>> Setting upstream... ($branch -> $originBranch)"
        Invoke-Git -Arguments @('--git-dir=.repo', 'branch', '--set-upstream-to', $originBranch, $branch) `
                   -ErrorMessage "Failed to set upstream. ($branch -> $originBranch)"
    }

    #-------------------------------------------------------
    # 9. Completion summary
    #-------------------------------------------------------
    Write-Host ''
    Write-Host 'All operations completed successfully.'
    Write-Host 'Created worktree paths:'
    foreach ($branch in $RemoteBranches) {
        Write-Host " - $WorkDir\$branch"
    }

    Pause-End 'Script finished successfully.'
}
catch {
    Write-Host ''
    Write-Error $_ -ErrorAction Continue
    Pause-End 'The script was terminated due to an error.'
}
