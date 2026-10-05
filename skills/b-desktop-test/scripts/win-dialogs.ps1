<#
 Read-only. Lists top-level windows of the given processes (default Revit, acad) with title and class and, for
 dialogs, the visible text/button/edit names of their children (UI Automation). Use it instead of a screenshot when you
 only need to know "is there an error or prompt dialog, and what does it say". Never clicks or types.
 Usage: powershell -NoProfile -File win-dialogs.ps1 [-Process Revit,acad]
 Output: JSON array of { pid, title, class, texts[] } (empty array when the processes are not running).
#>
param([string[]]$Process = @('Revit', 'acad'))
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$ids = @(Get-Process -Name $Process -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
$result = @()
if ($ids.Count -gt 0) {
  $root = [System.Windows.Automation.AutomationElement]::RootElement
  $wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
  foreach ($w in $wins) {
    $c = $w.Current
    if ($ids -notcontains $c.ProcessId) { continue }
    $texts = @()
    if ($c.ClassName -eq '#32770') {
      $kids = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
      $n = 0
      foreach ($k in $kids) {
        if ($n -ge 40) { break }
        $kc = $k.Current
        $kind = $kc.ControlType.ProgrammaticName -replace 'ControlType\.', ''
        if ($kc.Name -and ($kind -in 'Text', 'Button', 'Edit')) { $texts += ($kind + ': ' + $kc.Name); $n++ }
      }
    }
    $result += [pscustomobject]@{ pid = $c.ProcessId; title = $c.Name; class = $c.ClassName; texts = $texts }
  }
}
ConvertTo-Json -InputObject @($result) -Depth 4 -Compress
