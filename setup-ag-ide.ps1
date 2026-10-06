<#
.SYNOPSIS
    Khởi tạo và cấu hình môi trường Antigravity IDE (.agents, skills, rules, mcp_config.json, .harness)
    cho dự án Add-in Revit/AutoCAD dựa trên đường dẫn file solution (.sln).
    Hỗ trợ Windows 10 và Windows 11 (PowerShell 5.1 và PowerShell 7+).

.DESCRIPTION
    Script này nhận vào đường dẫn tới file .sln của dự án add-in, tự động xác định thư mục gốc dự án (Git root),
    và sao chép toàn bộ bộ kỹ năng (skills), sinh các rules kiểm thử (Maker != Checker, C# .NET 4.8 guidelines),
    thiết lập MCP server (Redmine, HicasTest), cùng thư mục quy trình (.harness) để sẵn sàng sử dụng
    trên Antigravity IDE với Model Gemini.

.PARAMETER SlnPath
    Đường dẫn tới file .sln của dự án Add-in (tương đối hoặc tuyệt đối).

.EXAMPLE
    .\setup-ag-ide.ps1 -SlnPath "D:\Gits\MyAddin\MyAddin.sln"
    .\setup-ag-ide.ps1 "..\MyAddin\MyAddin.sln"
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $false, HelpMessage = "Đường dẫn tới file .sln của dự án")]
    [string]$SlnPath
)

# Thiết lập encoding UTF-8 cho console
$OutputEncoding = [System.Text.Encoding]::UTF8
if ([Console]::OutputEncoding.EncodingName -ne [System.Text.Encoding]::UTF8.EncodingName) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
}

# Tự động nạp thư mục cài đặt công cụ cá nhân (.local\bin, .cargo\bin) vào PATH nếu có
$userLocalBin = Join-Path $env:USERPROFILE ".local\bin"
if ((Test-Path -LiteralPath $userLocalBin) -and ($env:Path -notlike "*$userLocalBin*")) {
    $env:Path = "$userLocalBin;$env:Path"
}

function Write-Step ([string]$message) {
    Write-Host "[>] $message" -ForegroundColor Cyan
}

function Write-Success ([string]$message) {
    Write-Host "[OK] $message" -ForegroundColor Green
}

function Write-Warn ([string]$message) {
    Write-Host "[!] $message" -ForegroundColor Yellow
}

function Write-Err ([string]$message) {
    Write-Host "[X] $message" -ForegroundColor Red
}

function Check-CommandExists ([string]$commandName) {
    return [bool](Get-Command $commandName -ErrorAction SilentlyContinue)
}

function Install-GitTool {
    Write-Step "Dang tien hanh cai dat Git..."
    if (Check-CommandExists "winget") {
        Write-Host "Thuc hien: winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements" -ForegroundColor DarkGray
        winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
    } else {
        Write-Warn "Khong tim thay winget. Vui long tai va cai dat Git thu cong tu: https://git-scm.com/download/win"
        Start-Process "https://git-scm.com/download/win"
        return
    }
    # Lam moi PATH cho session hien tai
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    if (Check-CommandExists "git") {
        Write-Success "Da cai dat Git thanh cong!"
    } else {
        Write-Warn "Da chay trinh cai dat Git. Co the can mo lai cua so Terminal sau khi cai dat xong de nhan PATH."
    }
}

function Install-UvxTool {
    Write-Step "Dang tien hanh cai dat uv / uvx qua installer chinh thuc (Astral)..."
    try {
        powershell -ExecutionPolicy ByPass -NoProfile -Command "irm https://astral.sh/uv/install.ps1 | iex"
    } catch {
        Write-Err "Loi khi tai va chay uv installer: $_"
    }
    # Bo sung duong dan mac dinh cua uv vao session hien tai
    $uvLocalBin = Join-Path $env:USERPROFILE ".local\bin"
    $uvCargoBin = Join-Path $env:USERPROFILE ".cargo\bin"
    if (Test-Path -LiteralPath $uvLocalBin) { $env:Path = "$uvLocalBin;$env:Path" }
    if (Test-Path -LiteralPath $uvCargoBin) { $env:Path = "$uvCargoBin;$env:Path" }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") + ";$uvLocalBin;$uvCargoBin"

    if (Check-CommandExists "uvx" -or Check-CommandExists "uv") {
        Write-Success "Da cai dat uv / uvx thanh cong!"
    } else {
        Write-Warn "Da chay installer uv. Co the can mo lai Terminal de nhan dien lenh uvx."
    }
}

function Test-Prerequisites {
    Write-Step "Kiem tra cac cong cu can thiet tren he thong (Git, uvx)..."
    $hasGit = Check-CommandExists "git"
    $hasUvx = (Check-CommandExists "uvx") -or (Check-CommandExists "uv")

    if ($hasGit) {
        $gitVer = (& git --version 2>$null)
        Write-Success "Git: Da cai dat ($gitVer)"
    } else {
        Write-Warn "Git: CHUA CAI DAT (Can thiet cho quan ly ma nguon va Worktree)"
    }

    if ($hasUvx) {
        $uvVer = (& uv --version 2>$null)
        Write-Success "uvx / uv: Da cai dat ($uvVer)"
    } else {
        Write-Warn "uvx / uv: CHUA CAI DAT (Can thiet cho MCP server Redmine)"
    }

    if ($hasGit -and $hasUvx) {
        Write-Success "Tat ca cac cong cu phu tro da san sang!"
        return
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host " PHAT HIEN CONG CU CON THIEU - TUY CHON CAI DAT THEO BITMASK" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host "  [0] Khong cai dat bat ky cong cu nao (Bo qua)" -ForegroundColor Gray
    Write-Host "  [1] Cai dat Git" -ForegroundColor Cyan
    Write-Host "  [2] Cai dat uvx (Trinh quan ly uv)" -ForegroundColor Cyan
    Write-Host "  [3] Cai dat ca Git va uvx (1 + 2 = 3)" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Yellow

    $choice = Read-Host "Nhap lua chon cua ban [0-3] (mac dinh: 0)"
    if ($choice) { $choice = $choice.Trim() }
    if (-not $choice) { $choice = "0" }

    switch ($choice) {
        "1" {
            if (-not $hasGit) { Install-GitTool } else { Write-Host "Git da co san tren he thong." -ForegroundColor Green }
        }
        "2" {
            if (-not $hasUvx) { Install-UvxTool } else { Write-Host "uvx da co san tren he thong." -ForegroundColor Green }
        }
        "3" {
            if (-not $hasGit) { Install-GitTool } else { Write-Host "Git da co san tren he thong." -ForegroundColor Green }
            if (-not $hasUvx) { Install-UvxTool } else { Write-Host "uvx da co san tren he thong." -ForegroundColor Green }
        }
        "0" {
            Write-Host "Bo qua buoc cai dat cong cu theo yeu cau." -ForegroundColor DarkGray
        }
        default {
            Write-Warn "Lua chon khong hop le ($choice). Bo qua cai dat."
        }
    }
    Write-Host ""
}

# 0. Kiem tra va cai dat cong cu tien quyet (Git, uvx)
Test-Prerequisites

# 1. Kiểm tra đầu vào SlnPath
if (-not $SlnPath) {
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "   HICAS SKILLS -> ANTIGRAVITY IDE CONFIGURATION SCRIPT   " -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    $SlnPath = Read-Host "Nhap duong dan toi file .sln cua du an Addin"
}

# Loại bỏ dấu ngoặc kép thừa nếu người dùng kéo thả file vào console
$SlnPath = $SlnPath.Trim().Trim('"').Trim("'")

if (-not $SlnPath) {
    Write-Err "Duong dan file .sln khong duoc de trong."
    exit 1
}

# Kiểm tra file .sln có tồn tại không
if (-not (Test-Path -Path $SlnPath -PathType Leaf)) {
    Write-Err "Khong tim thay file .sln tai duong dan: $SlnPath"
    exit 1
}

$SlnFile = Get-Item -LiteralPath $SlnPath
if ($SlnFile.Extension -ne ".sln") {
    Write-Err "File duoc chon khong phai la file solution Visual Studio (.sln): $($SlnFile.Name)"
    exit 1
}

$SlnFullPath = $SlnFile.FullName
$SlnDir = $SlnFile.Directory.FullName
Write-Success "Da xac nhan file .sln: $SlnFullPath"

# 2. Xác định thư mục gốc của dự án (Ưu tiên Git root nếu có)
Write-Step "Xac dinh thu muc goc (Project Root)..."
$ProjectRoot = $SlnDir
$CurrentDir = $SlnDir
while ($CurrentDir -and (Test-Path -LiteralPath $CurrentDir)) {
    if (Test-Path -LiteralPath (Join-Path $CurrentDir ".git")) {
        $ProjectRoot = $CurrentDir
        break
    }
    $ParentDir = Split-Path -Path $CurrentDir -Parent
    if ($ParentDir -eq $CurrentDir) { break }
    $CurrentDir = $ParentDir
}

Write-Success "Project Root: $ProjectRoot"

# Thư mục nguồn của bộ kỹ năng hicas-skills (vị trí hiện tại của script)
$SourceSkillsDir = $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $SourceSkillsDir "skills"))) {
    Write-Err "Khong tim thay thu muc skills/ tai: $SourceSkillsDir"
    exit 1
}

# 3. Tạo cấu trúc thư mục .agents cho Antigravity IDE trong Target Project
$AgentsDir = Join-Path $ProjectRoot ".agents"
$AgentsSkillsDir = Join-Path $AgentsDir "skills"
$AgentsRulesDir = Join-Path $AgentsDir "rules"

Write-Step "Khoi tao thu muc .agents/ tai target project..."
if (-not (Test-Path -LiteralPath $AgentsSkillsDir)) {
    New-Item -ItemType Directory -Path $AgentsSkillsDir -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $AgentsRulesDir)) {
    New-Item -ItemType Directory -Path $AgentsRulesDir -Force | Out-Null
}

# 4. Sao chép các Skills từ hicas-skills sang .agents/skills/
Write-Step "Dong bo cac Skills vao $AgentsSkillsDir..."
$SkillFolders = Get-ChildItem -LiteralPath (Join-Path $SourceSkillsDir "skills") -Directory
foreach ($folder in $SkillFolders) {
    $destFolder = Join-Path $AgentsSkillsDir $folder.Name
    Write-Host "  -> Syncing skill: $($folder.Name)" -ForegroundColor DarkGray
    Copy-Item -LiteralPath $folder.FullName -Destination $destFolder -Recurse -Force
}
Write-Success "Da copy $($SkillFolders.Count) skills thanh cong!"

# 5. Sinh các Rules chuyên dụng cho Add-in vào .agents/rules/
Write-Step "Khoi tao cac Rules cho Antigravity IDE..."

# Rule 1: maker-checker.md
$MakerCheckerRulePath = Join-Path $AgentsRulesDir "maker-checker.md"
$MakerCheckerContent = @'
# Nguyen tac Tham dinh Doc lap: Maker != Checker

Ap dung cho moi workflow phat trien Add-in Revit/AutoCAD:
1. **Khong tu danh gia**: Implementer (nguoi viet code) tuyet doi khong duoc tu danh dau "Pass" cho code hoac test case cua minh.
2. **Hop dong kiem thu la dong bang (Frozen Test Contract)**: Khong duoc sua doi, xoa bo hoac ha thap tieu chi cua cac test case da de ra trong `test-contract.md`.
3. **Bang chung may (Level-A)**: Chi duoc danh dau Pass khi co bang chung lenh thuc te (output lenh build, dotnet test, logs) dinh kem voi ma loi exit code 0.
4. **Bang chung thuc nghiem (Level-B & Critical)**: Ket qua may (HicasTest MATCH) chi la bang chung ho tro, luon yeu cau xac nhan tu nguoi dung (Human in the loop), khong bao gio tu dong ghi Pass.
5. **Gon gang & Chuyen nghiep**: Trao doi voi lap trinh vien bang tieng Viet; code, identifiers, commit message va code comments bang tieng Anh.
'@
Set-Content -LiteralPath $MakerCheckerRulePath -Value $MakerCheckerContent -Encoding UTF8
Write-Host "  -> Created rule: maker-checker.md" -ForegroundColor DarkGray

# Rule 2: addin-csharp-guidelines.md
$AddinRulePath = Join-Path $AgentsRulesDir "addin-csharp-guidelines.md"
$AddinRuleContent = @'
# Huong dan Ky thuat Add-in Revit / AutoCAD (.NET Framework 4.8, C#)

1. **Phan tang kien truc**:
   - Tang cao (Domain/Business): Logic nghiep vu thuan C#, khong phu thuoc namespace `Autodesk.*`.
   - Tang trung gian (Application): Dieu phoi quy trinh, goi Revit/AutoCAD qua interface Platform Services.
   - Tang thap (Platform Core / L0/L1): Thuc thi truc tiep tren Revit/AutoCAD API (Transactions, Document, Selection, Geometry).
2. **Giao tac & Luong (Threading & Transactions)**:
   - Revit API bat buoc chay tren UI Thread chinh (hoac thong qua `IExternalEventHandler`).
   - Moi thao tac sua doi model phai nam trong `Transaction` duoc dispose dung cach (`using (var t = new Transaction(doc)) { ... }`).
3. **Tuong thich phien ban (.NET 4.8, C# 7.3 legacy)**:
   - Tuan thu phien ban host thap nhat duoc ho tro.
   - Khong tu y nang cap goi NuGet hoac su dung cu phap C# moi (records, switch expressions, nullable reference types) neu `.csproj` chua ho tro.
4. **Giao dien WPF/XAML**:
   - ViewModel khong tham chieu truc tiep toi Revit API Document. Su dung DTO de truyen du lieu 2 chieu giua Revit va WPF.
'@
Set-Content -LiteralPath $AddinRulePath -Value $AddinRuleContent -Encoding UTF8
Write-Host "  -> Created rule: addin-csharp-guidelines.md" -ForegroundColor DarkGray
Write-Success "Da thiet lap cac rules tai .agents/rules/"

# Hàm hỗ trợ hợp nhất cấu hình MCP: giữ lại các giá trị cũ đã được điền
function Merge-McpConfig ($existingObj, $templateHashtable) {
    $resultServers = [ordered]@{}

    # 1. Khởi tạo từ template
    foreach ($serverName in $templateHashtable.mcpServers.Keys) {
        $tmpl = $templateHashtable.mcpServers[$serverName]
        $entry = [ordered]@{}
        foreach ($prop in $tmpl.Keys) {
            if ($prop -eq "env" -and ($tmpl[$prop] -is [System.Collections.IDictionary])) {
                $envTable = [ordered]@{}
                foreach ($ek in $tmpl[$prop].Keys) {
                    $envTable[$ek] = $tmpl[$prop][$ek]
                }
                $entry["env"] = $envTable
            } elseif ($tmpl[$prop] -is [System.Array]) {
                $entry[$prop] = @($tmpl[$prop])
            } else {
                $entry[$prop] = $tmpl[$prop]
            }
        }
        $resultServers[$serverName] = $entry
    }

    # 2. Hợp nhất nội dung từ file cũ
    if ($existingObj -and $existingObj.mcpServers) {
        $oldServers = $existingObj.mcpServers
        $oldNames = if ($oldServers -is [System.Management.Automation.PSCustomObject]) {
            $oldServers.PSObject.Properties.Name
        } elseif ($oldServers -is [System.Collections.IDictionary]) {
            $oldServers.Keys
        } else { @() }

        foreach ($name in $oldNames) {
            $oldServer = if ($oldServers -is [System.Management.Automation.PSCustomObject]) {
                $oldServers.$name
            } else {
                $oldServers[$name]
            }

            if ($resultServers.Contains($name)) {
                # Cùng server: điền lại các giá trị cũ đã có
                $oldProps = if ($oldServer -is [System.Management.Automation.PSCustomObject]) {
                    $oldServer.PSObject.Properties.Name
                } elseif ($oldServer -is [System.Collections.IDictionary]) {
                    $oldServer.Keys
                } else { @() }

                foreach ($p in $oldProps) {
                    $val = if ($oldServer -is [System.Management.Automation.PSCustomObject]) {
                        $oldServer.$p
                    } else {
                        $oldServer[$p]
                    }

                    if ($p -eq "env") {
                        if (-not $resultServers[$name].Contains("env")) {
                            $resultServers[$name]["env"] = [ordered]@{}
                        }
                        $oldEnvProps = if ($val -is [System.Management.Automation.PSCustomObject]) {
                            $val.PSObject.Properties.Name
                        } elseif ($val -is [System.Collections.IDictionary]) {
                            $val.Keys
                        } else { @() }

                        foreach ($ek in $oldEnvProps) {
                            $eVal = if ($val -is [System.Management.Automation.PSCustomObject]) {
                                $val.$ek
                            } else {
                                $val[$ek]
                            }
                            # Điền lại giá trị cũ của env
                            $resultServers[$name]["env"][$ek] = $eVal
                        }
                    } else {
                        $resultServers[$name][$p] = $val
                    }
                }
            } else {
                # Server riêng người dùng tự thêm từ trước -> Giữ lại nguyên vẹn
                $resultServers[$name] = $oldServer
            }
        }
    }

    return [ordered]@{
        mcpServers = $resultServers
    }
}

# 6. Thiết lập MCP Config cho Antigravity IDE
Write-Step "Thiet lap mcp_config.json cho .agents/..."
$McpConfigPath = Join-Path $AgentsDir "mcp_config.json"
$McpTemplate = [ordered]@{
    mcpServers = [ordered]@{
        redmine = [ordered]@{
            command = "uvx"
            args = @("--from", "mcp-redmine==2026.08.01.002543", "mcp-redmine")
            env = [ordered]@{
                REDMINE_URL = "${REDMINE_URL}"
                REDMINE_API_KEY = "${REDMINE_API_KEY}"
                REDMINE_READ_ONLY = "1"
            }
        }
        "hicas-test" = [ordered]@{
            command = "powershell"
            args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "install.ps1", "-RegisterMcp")
        }
    }
}

if (Test-Path -LiteralPath $McpConfigPath) {
    Write-Warn "Phat hien file mcp_config.json da ton tai tai: $McpConfigPath"
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host " TUY CHON GHI DE FILE MCP_CONFIG.JSON:" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Yellow
    Write-Host "  [0] Khong ghi de (Giu nguyen noi dung file hien tai)" -ForegroundColor Gray
    Write-Host "  [1] Ghi de hoan toan (Thay the bang template mac dinh)" -ForegroundColor Red
    Write-Host "  [2] Ghi de thong minh (Cap nhat & dien lai cac thong tin cu da co vao file moi)" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Yellow

    $mcpChoice = Read-Host "Nhap lua chon cua ban [0-2] (mac dinh: 2)"
    if ($mcpChoice) { $mcpChoice = $mcpChoice.Trim() }
    if (-not $mcpChoice) { $mcpChoice = "2" }

    switch ($mcpChoice) {
        "0" {
            Write-Host "Giu nguyen noi dung file mcp_config.json hien tai." -ForegroundColor DarkGray
        }
        "1" {
            $McpTemplate | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $McpConfigPath -Encoding UTF8
            Write-Success "Da ghi de hoan toan file $McpConfigPath theo template mac dinh."
        }
        "2" {
            try {
                $oldRaw = Get-Content -LiteralPath $McpConfigPath -Raw -Encoding UTF8
                $oldObj = $oldRaw | ConvertFrom-Json
                $mergedConfig = Merge-McpConfig $oldObj $McpTemplate
                $mergedConfig | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $McpConfigPath -Encoding UTF8
                Write-Success "Da cap nhat mcp_config.json: giu lai day du thong tin/bien moi truong cu da dien!"
            } catch {
                Write-Warn "Loi khi phan tich file cu ($_); ghi de bang template moi."
                $McpTemplate | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $McpConfigPath -Encoding UTF8
                Write-Success "Da tao lai $McpConfigPath"
            }
        }
        default {
            Write-Warn "Lua chon khong hop le ($mcpChoice). Mac dinh giu nguyen file cu (option 0)."
        }
    }
} else {
    $McpTemplate | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $McpConfigPath -Encoding UTF8
    Write-Success "Da tao moi file $McpConfigPath"
}

# 7. Khởi tạo thư mục quy trình .harness/ và git exclude
Write-Step "Khoi tao thu muc quy trinh .harness/..."
$HarnessDir = Join-Path $ProjectRoot ".harness"
$TicketsDir = Join-Path $HarnessDir "tickets"
$FeaturesDir = Join-Path $HarnessDir "features"
$BatchDir = Join-Path $HarnessDir "batch"

@( $HarnessDir, $TicketsDir, $FeaturesDir, $BatchDir ) | ForEach-Object {
    if (-not (Test-Path -LiteralPath $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# Tạo file cấu hình mẫu .harness/addin-story.json
$AddinStoryJsonPath = Join-Path $HarnessDir "addin-story.json"
if (-not (Test-Path -LiteralPath $AddinStoryJsonPath)) {
    # Tính đường dẫn tương đối từ ProjectRoot tới .sln
    $RelativeSln = $SlnFullPath.Substring($ProjectRoot.Length).TrimStart('\', '/')
    $AddinStoryConfig = @{
        solution = $RelativeSln
        featuresDir = ".harness/features"
        automationBridge = "hicas-test"
        testBuilds = @()
        testFixtures = @()
    }
    $AddinStoryConfig | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $AddinStoryJsonPath -Encoding UTF8
    Write-Host "  -> Created template: .harness/addin-story.json" -ForegroundColor DarkGray
}

# Cấu hình .gitignore của project để tránh commit .agents/ và .harness/
Write-Step "Kiem tra va cap nhat .gitignore cua project..."
$GitIgnorePath = Join-Path $ProjectRoot ".gitignore"
$ignoreEntries = @(
    "# Antigravity IDE & AI Workflow",
    ".agents/",
    "agents/",
    ".harness/"
)

if (Test-Path -LiteralPath $GitIgnorePath) {
    $existingIgnore = Get-Content -LiteralPath $GitIgnorePath -Raw -ErrorAction SilentlyContinue
    $missingEntries = @()
    foreach ($entry in @(".agents/", "agents/", ".harness/")) {
        if ($existingIgnore -notmatch [regex]::Escape($entry)) {
            $missingEntries += $entry
        }
    }
    if ($missingEntries.Count -gt 0) {
        $appendBlock = "`n# Antigravity IDE & AI Workflow`n" + ($missingEntries -join "`n") + "`n"
        Add-Content -LiteralPath $GitIgnorePath -Value $appendBlock -Encoding UTF8
        Write-Success "Da them $($missingEntries -join ', ') vao file .gitignore cua project"
    } else {
        Write-Host "  -> File .gitignore da bo qua cac thu muc agents/ va .harness/" -ForegroundColor DarkGray
    }
} else {
    $newIgnoreContent = ($ignoreEntries -join "`n") + "`n"
    Set-Content -LiteralPath $GitIgnorePath -Value $newIgnoreContent -Encoding UTF8
    Write-Success "Da tao moi file .gitignore voi cac thu muc .agents/, agents/, .harness/"
}

# Cấu hình thêm vào .git/info/exclude để bảo vệ cục bộ (local exclude)
$GitDir = Join-Path $ProjectRoot ".git"
if (Test-Path -LiteralPath $GitDir) {
    $GitExcludePath = Join-Path $GitDir "info\exclude"
    if (Test-Path -LiteralPath $GitExcludePath) {
        $excludeContent = Get-Content -LiteralPath $GitExcludePath -Raw -ErrorAction SilentlyContinue
        $toExclude = @()
        foreach ($e in @(".harness/", ".agents/", "agents/")) {
            if ($excludeContent -notmatch [regex]::Escape($e)) {
                $toExclude += $e
            }
        }
        if ($toExclude.Count -gt 0) {
            Add-Content -LiteralPath $GitExcludePath -Value ("`n" + ($toExclude -join "`n") + "`n") -Encoding UTF8
            Write-Success "Da them ($($toExclude -join ', ')) vao .git/info/exclude"
        }
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "   DA CAI DAT THANH CONG CHO ANTIGRAVITY IDE!             " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Du an:         $($SlnFile.Name)" -ForegroundColor White
Write-Host "Thu muc goc:   $ProjectRoot" -ForegroundColor White
Write-Host "Thu muc skill: $AgentsSkillsDir" -ForegroundColor White
Write-Host "Cac buoc tiep theo:" -ForegroundColor Yellow
Write-Host " 1. Mo Antigravity IDE tai thu muc: $ProjectRoot" -ForegroundColor Gray
Write-Host " 2. Chon model: Gemini (Flash hoac Pro/Thinking)" -ForegroundColor Gray
Write-Host " 3. Kiem tra bien moi truong REDMINE_URL va REDMINE_API_KEY tren may neu dung Redmine" -ForegroundColor Gray
Write-Host " 4. Goi cac skill nhu 'addin-story' hoac 'addin-batch' de bat dau!" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Green
