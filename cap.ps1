param(
    [Parameter(Mandatory=$true)]
    [string]$CommitMessage
)

# Set error action preference to stop on errors
$ErrorActionPreference = "Stop"

# Get the directory where the script is located (supertokens-hello-world)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "Starting git commit and push process..." -ForegroundColor Green
Write-Host "Working directory: $ScriptDir" -ForegroundColor Yellow

try {
    # Check if we're in a git repository
    $gitStatus = git status 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Not in a git repository or git is not installed"
    }

    # Check if there are any changes to commit
    $gitStatusOutput = git status --porcelain
    if ([string]::IsNullOrEmpty($gitStatusOutput)) {
        Write-Host "No changes to commit." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Changes detected:" -ForegroundColor Cyan
    git status --short

    # Add all changes
    Write-Host "Adding all changes..." -ForegroundColor Green
    git add .
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to add changes to git"
    }

    # Commit changes
    Write-Host "Committing changes with message: '$CommitMessage'" -ForegroundColor Green
    git commit -m $CommitMessage
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to commit changes"
    }

    # Check current branch
    $currentBranch = git branch --show-current
    Write-Host "Current branch: $currentBranch" -ForegroundColor Yellow

    # Push to main branch (or current branch if different)
    Write-Host "Pushing to origin/$currentBranch..." -ForegroundColor Green
    git push origin $currentBranch
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to push changes to remote repository"
    }

    Write-Host "Successfully committed and pushed changes!" -ForegroundColor Green
    Write-Host "Commit message: $CommitMessage" -ForegroundColor Cyan
    Write-Host "Pushed to: origin/$currentBranch" -ForegroundColor Cyan

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Git commit and push failed." -ForegroundColor Red
    exit 1
}
