<#
 Saves a PNG of ONE application window (not the whole screen, so other apps never end up in the evidence).
 Usage: powershell -NoProfile -File shot.ps1 -Out <file.png> [-Process Revit] [-TitleLike "Revit"]
 Picks the largest visible top-level window of the process (or the one whose title matches -TitleLike).
 Output: JSON { ok, file, title, width, height } ; ok=false + error when no window is found.
#>
param(
  [Parameter(Mandatory = $true)][string]$Out,
  [string]$Process = 'Revit',
  [string]$TitleLike = ''
)
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WinShot {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
}
'@
$procs = @(Get-Process -Name $Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })
if ($TitleLike) { $procs = @($procs | Where-Object { $_.MainWindowTitle -like "*$TitleLike*" }) }
if ($procs.Count -eq 0) { ConvertTo-Json -Compress @{ ok = $false; error = "no visible window for process '$Process'" }; exit 1 }
$best = $null; $bestArea = -1
foreach ($p in $procs) {
  $r = New-Object WinShot+RECT
  if ([WinShot]::GetWindowRect($p.MainWindowHandle, [ref]$r)) {
    $a = ($r.Right - $r.Left) * ($r.Bottom - $r.Top)
    if ($a -gt $bestArea) { $bestArea = $a; $best = @{ proc = $p; rect = $r } }
  }
}
$rect = $best.rect; $w = $rect.Right - $rect.Left; $h = $rect.Bottom - $rect.Top
if ($w -le 0 -or $h -le 0) { ConvertTo-Json -Compress @{ ok = $false; error = 'window has no size (minimised?)' }; exit 1 }
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
$null = [WinShot]::PrintWindow($best.proc.MainWindowHandle, $hdc, 2)   # 2 = PW_RENDERFULLCONTENT
$g.ReleaseHdc($hdc); $g.Dispose()
$dir = Split-Path -Parent $Out
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
ConvertTo-Json -Compress @{ ok = $true; file = (Resolve-Path $Out).Path; title = $best.proc.MainWindowTitle; width = $w; height = $h }
