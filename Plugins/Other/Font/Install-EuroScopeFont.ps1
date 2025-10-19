# ==============================================================
# Install-EuroScope-Silent.ps1
# Installs or replaces EuroScope.ttf silently, auto-confirming all prompts
# Equivalent to GUI "Install" button with automatic overwrite
# ==============================================================

# --- Ensure running as Administrator ---
function Ensure-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Host "[!] Elevating to Administrator..." -ForegroundColor Yellow
        Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}
Ensure-Admin

# --- Define paths ---
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$FontName   = "EuroScope.ttf"
$SourceFont = Join-Path $ScriptDir $FontName
$FontsDir   = "$env:WINDIR\Fonts"
$DestFont   = Join-Path $FontsDir $FontName

Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " EuroScope Font Silent Installer (auto-overwrite)"
Write-Host "=============================================================="
Write-Host "[*] Source:      $SourceFont"
Write-Host "[*] Destination: $DestFont"
Write-Host "--------------------------------------------------------------"

# --- Check file ---
if (-not (Test-Path $SourceFont)) {
    Write-Host "[ERROR] Source file not found! Place EuroScope.ttf next to script." -ForegroundColor Red
    Pause
    exit 1
}

# --- Optional: remove old font if exists ---
if (Test-Path $DestFont) {
    Write-Host "[*] Removing old EuroScope.ttf..." -ForegroundColor Yellow
    try {
        & takeown /f "$DestFont" | Out-Null
        & icacls "$DestFont" /grant Administrators:F | Out-Null
        Remove-Item "$DestFont" -Force
        Write-Host "[OK] Old version removed." -ForegroundColor Green
    }
    catch {
        Write-Host "[WARN] Could not delete old version: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- Silent install via Shell.Application (auto-accept overwrite) ---
try {
    Write-Host "[*] Installing font via Shell.CopyHere (silent overwrite)..." -ForegroundColor Cyan
    $shell = New-Object -ComObject Shell.Application
    $fontsFolder = $shell.Namespace($FontsDir)
    $COPY_FLAGS = 0x10 + 0x04  # 16 = Yes to All, 4 = No UI
    $fontsFolder.CopyHere($SourceFont, $COPY_FLAGS)
    Start-Sleep -Milliseconds 800
    Write-Host "[OK] Font installation requested (Explorer-level)." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Shell.CopyHere failed: $($_.Exception.Message)" -ForegroundColor Red
    Pause
    exit 1
}

# --- Ensure registered immediately (AddFontResourceEx + WM_FONTCHANGE) ---
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class FontLoader {
    [DllImport("gdi32.dll", EntryPoint="AddFontResourceEx", SetLastError=true)]
    public static extern int AddFontResourceEx(string lpszFilename, uint fl, IntPtr pdv);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern int SendMessage(int hWnd, uint Msg, int wParam, int lParam);
}
"@
[void][FontLoader]::AddFontResourceEx($DestFont, 0, [IntPtr]::Zero)
[FontLoader]::SendMessage(0xffff, 0x001D, 0, 0) | Out-Null
Write-Host "[OK] Font registered with system and WM_FONTCHANGE broadcasted." -ForegroundColor Green

# --- Registry update for persistence ---
try {
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" `
                     -Name "EuroScope (TrueType)" -Value $FontName -PropertyType String -Force | Out-Null
    Write-Host "[OK] Registry updated." -ForegroundColor Green
}
catch {
    Write-Host "[WARN] Could not update registry: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=============================================================="
Write-Host " [DONE] EuroScope.ttf installed or replaced silently."
Write-Host " The font should now appear in EuroScope and other apps."
Write-Host "=============================================================="
Pause

