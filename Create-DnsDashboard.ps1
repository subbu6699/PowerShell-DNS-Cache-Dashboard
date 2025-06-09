<#
.SYNOPSIS
    Generates an interactive HTML dashboard from the local DNS cache.

.DESCRIPTION
    This script runs 'ipconfig /displaydns', parses the output, and creates a
    single, self-contained HTML file with a modern card-based view. The dashboard
    includes embedded CSS for styling and JavaScript for live filtering/searching.

.NOTES
    Author: AI Assistant
    Version: 1.1
#>

# --- Script Configuration ---
$outputFile = "dns_dashboard.html"

# --- Main Script ---
Write-Host "Step 1: Fetching DNS cache from 'ipconfig /displaydns'..." -ForegroundColor Cyan
$dnsOutput = ipconfig /displaydns

Write-Host "Step 2: Parsing DNS records... This might take a moment for large caches." -ForegroundColor Cyan
$DnsRecords = @()
$currentRecord = $null

# Use a 'for' loop to allow looking ahead at the next line
for ($i = 0; $i -lt $dnsOutput.Count; $i++) {
    $line = $dnsOutput[$i].Trim()

    # A new record block starts with a non-indented line followed by a separator line '----'
    if ($line -and -not $line.StartsWith(" ") -and ($i + 1) -lt $dnsOutput.Count -and $dnsOutput[$i + 1].Trim() -match '^-+$') {
        # If we were processing a previous record, add it to the list
        if ($null -ne $currentRecord) {
            $DnsRecords += $currentRecord
        }

        # Start a new record object
        $currentRecord = [PSCustomObject]@{
            RecordName = $line
        }
        # Skip the separator line
        $i++
        continue
    }

    # If we are inside a record block, parse its properties
    if ($null -ne $currentRecord -and $line -like '*: *') {
        $parts = $line -split ':', 2
        if ($parts.Count -eq 2) {
            # Clean up the key to make it a valid property name
            $key = $parts[0].Trim() -replace '\s|\.|\(|\)' -replace '-',''
            $value = $parts[1].Trim()
            
            # Add the property to the current object
            Add-Member -InputObject $currentRecord -MemberType NoteProperty -Name $key -Value $value
        }
    }
}

# Add the very last record after the loop finishes
if ($null -ne $currentRecord) {
    $DnsRecords += $currentRecord
}

Write-Host "Step 3: Generating HTML, CSS, and JavaScript for the dashboard..." -ForegroundColor Cyan

# --- CSS for the Dashboard ---
$css = @"
<style>
    :root {
        --bg-color: #1a1a1d;
        --card-bg: #2c2c34;
        --primary-text: #e1e1e1;
        --secondary-text: #b3b3b3;
        --accent-color: #4ecca3;
        --border-color: #444;
        --shadow-color: rgba(0,0,0,0.4);
    }
    body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        background-color: var(--bg-color);
        color: var(--primary-text);
        margin: 0;
        padding: 20px;
    }
    .dashboard-header {
        text-align: center;
        margin-bottom: 30px;
    }
    .dashboard-header h1 {
        color: var(--accent-color);
        margin-bottom: 5px;
    }
    #search-box {
        width: 100%;
        max-width: 600px;
        padding: 12px 15px;
        margin: 0 auto 30px auto;
        display: block;
        font-size: 16px;
        border-radius: 25px;
        border: 2px solid var(--border-color);
        background-color: var(--card-bg);
        color: var(--primary-text);
        outline: none;
        transition: border-color 0.3s, box-shadow 0.3s;
    }
    #search-box:focus {
        border-color: var(--accent-color);
        box-shadow: 0 0 10px var(--accent-color);
    }
    #dns-cards-container {
        display: flex;
        flex-wrap: wrap;
        gap: 20px;
        justify-content: center;
    }
    .dns-card {
        background-color: var(--card-bg);
        border: 1px solid var(--border-color);
        border-radius: 8px;
        padding: 15px;
        width: 350px;
        box-shadow: 0 4px 8px var(--shadow-color);
        transition: transform 0.2s ease-in-out, box-shadow 0.2s ease-in-out;
        display: flex;
        flex-direction: column;
    }
    .dns-card:hover {
        transform: translateY(-5px);
        box-shadow: 0 8px 16px var(--shadow-color);
    }
    .card-header {
        font-size: 1.2em;
        font-weight: bold;
        color: var(--accent-color);
        word-break: break-all;
        margin-bottom: 10px;
        border-bottom: 1px solid var(--border-color);
        padding-bottom: 10px;
    }
    .card-content p {
        margin: 5px 0;
        font-size: 0.9em;
        word-break: break-all;
    }
    .card-content strong {
        color: var(--primary-text);
        margin-right: 8px;
    }
    .card-content span {
        color: var(--secondary-text);
    }
    .no-results {
        font-size: 1.5em;
        color: var(--secondary-text);
        text-align: center;
        padding: 50px;
        display: none; /* Hidden by default */
    }
</style>
"@

# --- JavaScript for the Dashboard ---
$javascript = @"
<script>
    document.addEventListener('DOMContentLoaded', function() {
        const searchBox = document.getElementById('search-box');
        const cardsContainer = document.getElementById('dns-cards-container');
        const cards = cardsContainer.getElementsByClassName('dns-card');
        const noResults = document.getElementById('no-results');

        searchBox.addEventListener('keyup', function() {
            const searchTerm = searchBox.value.toLowerCase();
            let visibleCards = 0;

            for (let i = 0; i < cards.length; i++) {
                const cardText = cards[i].textContent.toLowerCase();
                if (cardText.includes(searchTerm)) {
                    cards[i].style.display = 'flex';
                    visibleCards++;
                } else {
                    cards[i].style.display = 'none';
                }
            }
            
            if(visibleCards === 0) {
                noResults.style.display = 'block';
            } else {
                noResults.style.display = 'none';
            }
        });
    });
</script>
"@

# --- HTML Card Generation ---
$cardHtmlBlocks = [System.Text.StringBuilder]::new()
$totalRecords = $DnsRecords.Count
$progress = 0

foreach ($record in $DnsRecords) {
    $progress++
    Write-Progress -Activity "Generating HTML Cards" -Status "Processing record $progress of $totalRecords" -PercentComplete (($progress / $totalRecords) * 100)
    
    [void]$cardHtmlBlocks.Append("<div class='dns-card'>")
    [void]$cardHtmlBlocks.Append("<div class='card-header'>$($record.RecordName)</div>")
    [void]$cardHtmlBlocks.Append("<div class='card-content'>")
    
    # Iterate through all properties of the object, skipping the name which is already in the header
    foreach ($prop in $record.PSObject.Properties | Where-Object { $_.Name -ne 'RecordName' }) {
        [void]$cardHtmlBlocks.Append("<p><strong>$($prop.Name):</strong> <span>$($prop.Value)</span></p>")
    }
    
    [void]$cardHtmlBlocks.Append("</div></div>")
}

# --- Final HTML Document Assembly ---
$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Local DNS Cache Dashboard</title>
    $css
</head>
<body>
    <div class="dashboard-header">
        <h1>DNS Cache Dashboard</h1>
        <p>Found $($DnsRecords.Count) records in the local DNS cache.</p>
    </div>

    <input type="text" id="search-box" placeholder="Filter by name, type, or IP...">

    <div id="dns-cards-container">
    $($cardHtmlBlocks.ToString())
    </div>
    
    <div id="no-results" class="no-results">No records match your filter.</div>

    $javascript
</body>
</html>
"@

Write-Host "Step 4: Writing dashboard to '$outputFile'..." -ForegroundColor Cyan
$htmlContent | Set-Content -Path $outputFile -Encoding UTF8

Write-Host "Done! Launching the dashboard in your default browser." -ForegroundColor Green
Invoke-Item -Path $outputFile
