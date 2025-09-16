#!/usr/bin/env pwsh
# Password management script for persistent deployments
# This script manages passwords that survive incremental deployments

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("get", "create", "reset")]
    [string]$Action,
    
    [string]$PASSWORD_FILE = "./deployment-passwords.json"
)

function Get-Passwords {
    if (Test-Path $PASSWORD_FILE) {
        $passwords = Get-Content $PASSWORD_FILE | ConvertFrom-Json
        Write-Host "📋 Retrieved existing passwords" -ForegroundColor Green
        return $passwords
    } else {
        Write-Host "❌ No password file found at $PASSWORD_FILE" -ForegroundColor Red
        return $null
    }
}

function New-Passwords {
    Write-Host "🔐 Generating new secure passwords..." -ForegroundColor Yellow
    
    # Generate secure passwords (avoiding special characters that break PostgreSQL URIs)
    $SUPERTOKENS_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
    $APP_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
    
    $passwords = @{
        POSTGRES_ROOT_PASSWORD = $SUPERTOKENS_PASSWORD
        SUPERTOKENS_PASSWORD = $SUPERTOKENS_PASSWORD
        APP_PASSWORD = $APP_PASSWORD
        CREATED_DATE = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $passwords | ConvertTo-Json | Out-File -FilePath $PASSWORD_FILE -Encoding UTF8
    
    Write-Host "✅ Generated and saved new passwords" -ForegroundColor Green
    Write-Host "POSTGRES_ROOT_PASSWORD: $SUPERTOKENS_PASSWORD" -ForegroundColor Cyan
    Write-Host "SUPERTOKENS_PASSWORD: $SUPERTOKENS_PASSWORD" -ForegroundColor Cyan
    Write-Host "APP_PASSWORD: $APP_PASSWORD" -ForegroundColor Cyan
    
    return $passwords
}

function Reset-Passwords {
    if (Test-Path $PASSWORD_FILE) {
        Remove-Item $PASSWORD_FILE -Force
        Write-Host "🗑️  Removed existing password file" -ForegroundColor Yellow
    }
    return New-Passwords
}

# Main execution
switch ($Action) {
    "get" {
        $passwords = Get-Passwords
        if ($passwords) {
            Write-Host "📅 Passwords created: $($passwords.CREATED_DATE)" -ForegroundColor Gray
            return $passwords
        } else {
            Write-Host "💡 No existing passwords found. Run with 'create' to generate new ones." -ForegroundColor Yellow
            return $null
        }
    }
    "create" {
        return New-Passwords
    }
    "reset" {
        return Reset-Passwords
    }
}
