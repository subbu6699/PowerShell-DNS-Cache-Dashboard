<#
.SYNOPSIS
    Generates a modern, single-file HTML dashboard with system information.

.DESCRIPTION
    This script collects key system information including OS, CPU, RAM, and Disk usage.
    It then generates a self-contained HTML file with embedded CSS and JavaScript
    to display the information in a clean, responsive "card" layout.

    The final report is saved to the user's Temp directory and opened automatically.

.EXAMPLE
    .\Get-SystemDashboard.ps1

    This will create 'System-Dashboard.html' in your Temp folder and open it.

.EXAMPLE
    .\Get-SystemDashboard.ps1 -OutputPath "C:\Reports\MyServerReport.html"

    This will save the report to the specified path and open it.
#>
[CmdletBinding()]
param (
    [string]$OutputPath = (Join-Path $env:TEMP "System-Dashboard.html")
)

Write-Host "Gathering system information..." -ForegroundColor Cyan

#region Data Collection

# --- General System & OS Info ---
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$csInfo = Get-CimInstance -ClassName Win32_ComputerSystem
$computerName = $csInfo.Name
$osName = $osInfo.Caption
$lastBoot = $osInfo.LastBootUpTime
$uptime = (Get-Date) - $lastBoot
$uptimeString = "{0:00}d {1:00}h {2:00}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes

# --- CPU Info ---
$cpuInfo = Get-CimInstance -ClassName Win32_Processor
$cpuName = $cpuInfo.Name
$cpuCores = $cpuInfo.NumberOfCores
$cpuLogical = $cpuInfo.NumberOfLogicalProcessors
$cpuSpeed = "$($cpuInfo.MaxClockSpeed) MHz"

# --- RAM Info ---
$totalRamGB = [math]::Round($csInfo.TotalPhysicalMemory / 1GB, 2)
$freeRamBytes = (Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Memory).AvailableBytes
$freeRamGB = [math]::Round($freeRamBytes / 1GB, 2)
$usedRamGB = $totalRamGB - $freeRamGB
$ramUsagePercent = [math]::Round(($usedRamGB / $totalRamGB) * 100)
$ramStatusColor = if ($ramUsagePercent -gt 90) { 'red' } elseif ($ramUsagePercent -gt 75) { 'orange' } else { 'green' }

# --- Disk Info ---
Write-Host "Analyzing disk drives..." -ForegroundColor Cyan
$diskCollection = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
$diskHtml = foreach ($disk in $diskCollection) {
    $diskName = $disk.DeviceID
    $diskLabel = $disk.VolumeName
    $sizeGB = [math]::Round($disk.Size / 1GB, 2)
    $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
    $usedGB = $sizeGB - $freeGB
    # Avoid division by zero for empty drives
    $usagePercent = if ($sizeGB -gt 0) { [math]::Round(($usedGB / $sizeGB) * 100) } else { 0 }
    $diskStatusColor = if ($usagePercent -gt 90) { 'red' } elseif ($usagePercent -gt 75) { 'orange' } else { 'green' }

    # Generate HTML for each disk card
    @"
    <div class="card disk-card">
        <h2>Disk: $diskName ($diskLabel)</h2>
        <p><strong>Total Size:</strong> $sizeGB GB</p>
        <p><strong>Used Space:</strong> $usedGB GB</p>
        <p><strong>Free Space:</strong> $freeGB GB</p>
        <div class="progress-bar-container">
            <div class="progress-bar $diskStatusColor" style="width: $($usagePercent)%;">
                $($usagePercent)% Used
            </div>
        </div>
    </div>
"@
}
#endregion Data Collection

Write-Host "Generating HTML report..." -ForegroundColor Cyan

#region HTML Generation
# Using a Here-String for the main HTML template.
$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Information Dashboard - $computerName</title>
    <style>
        /* CSS is embedded here */
        :root {
            --bg-color: #f4f7f9;
            --card-bg-color: #ffffff;
            --text-color: #333;
            --header-color: #0056b3;
            --shadow-color: rgba(0, 0, 0, 0.1);
            --border-radius: 8px;
            --progress-bg: #e9ecef;
            --bar-green: #28a745;
            --bar-orange: #fd7e14;
            --bar-red: #dc3545;
            --font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        body {
            font-family: var(--font-family);
            background-color: var(--bg-color);
            color: var(--text-color);
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: auto;
        }
        header {
            text-align: center;
            margin-bottom: 30px;
        }
        header h1 {
            color: var(--header-color);
            margin-bottom: 5px;
        }
        header p {
            color: #6c757d;
            font-size: 1.1em;
        }
        .dashboard-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }
        .card {
            background-color: var(--card-bg-color);
            border-radius: var(--border-radius);
            box-shadow: 0 4px 8px var(--shadow-color);
            padding: 20px;
            transition: transform 0.2s;
        }
        .card:hover {
            transform: translateY(-5px);
        }
        .card h2 {
            margin-top: 0;
            color: var(--header-color);
            border-bottom: 2px solid #e9ecef;
            padding-bottom: 10px;
            margin-bottom: 15px;
            font-size: 1.4em;
        }
        .card p {
            margin: 8px 0;
            font-size: 1em;
            display: flex;
            justify-content: space-between;
        }
        .card p strong {
            color: #495057;
        }
        .progress-bar-container {
            background-color: var(--progress-bg);
            border-radius: 5px;
            margin-top: 15px;
            height: 24px;
            overflow: hidden;
            width: 100%;
        }
        .progress-bar {
            height: 100%;
            color: white;
            font-weight: bold;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 0.9em;
            white-space: nowrap;
            transition: width 0.6s ease;
        }
        .green { background-color: var(--bar-green); }
        .orange { background-color: var(--bar-orange); }
        .red { background-color: var(--bar-red); }
        footer {
            text-align: center;
            margin-top: 40px;
            color: #6c757d;
            font-size: 0.9em;
        }
    </style>
</head>
<body>

    <div class="container">
        <header>
            <h1>System Information Dashboard</h1>
            <p>$computerName</p>
        </header>

        <div class="dashboard-grid">
            <!-- System Card -->
            <div class="card">
                <h2>System Overview</h2>
                <p><strong>Operating System:</strong> <span>$osName</span></p>
                <p><strong>Uptime:</strong> <span>$uptimeString</span></p>
                <p><strong>Last Boot:</strong> <span>$lastBoot</span></p>
            </div>

            <!-- CPU Card -->
            <div class="card">
                <h2>CPU</h2>
                <p><strong>Model:</strong> <span>$cpuName</span></p>
                <p><strong>Cores:</strong> <span>$cpuCores</span></p>
                <p><strong>Logical Processors:</strong> <span>$cpuLogical</span></p>
                <p><strong>Max Speed:</strong> <span>$cpuSpeed</span></p>
            </div>

            <!-- RAM Card -->
            <div class="card">
                <h2>Memory (RAM)</h2>
                <p><strong>Total RAM:</strong> <span>$totalRamGB GB</span></p>
                <p><strong>Used RAM:</strong> <span>$usedRamGB GB</span></p>
                <p><strong>Free RAM:</strong> <span>$freeRamGB GB</span></p>
                <div class="progress-bar-container">
                    <div class="progress-bar $ramStatusColor" style="width: $($ramUsagePercent)%;">
                        $($ramUsagePercent)% Used
                    </div>
                </div>
            </div>

            <!-- Disk Cards are dynamically inserted here -->
            $($diskHtml -join "`n")
        </div>

        <footer>
            <p>Report generated on <span id="reportDate"></span></p>
        </footer>
    </div>

    <script>
        // JS is embedded here
        document.getElementById('reportDate').textContent = new Date().toLocaleString();
    </script>

</body>
</html>
"@
#endregion HTML Generation

# --- File Output and Launch ---
try {
    $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8 -ErrorAction Stop
    Write-Host "Successfully generated dashboard: $OutputPath" -ForegroundColor Green
    
    # Launch the file in the default browser
    Invoke-Item -Path $OutputPath
}
catch {
    Write-Error "Failed to write report to '$OutputPath'. Error: $_"
}
