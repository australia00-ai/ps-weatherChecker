# =====================================================
# SIMPLE WEATHER ALERT MONITOR FOR NTFY
# =====================================================

# -----------------------------
# LOCAL WEATHER (MELBOURNE)
# -----------------------------
$LocalName = "Melbourne"
$LocalLat  = -37.8136
$LocalLon  = 144.9631

# -----------------------------
# TARNEIT (NEW LOCATION ADDED)
# -----------------------------
$TarneitName = "Tarneit"
$TarneitLat  = -37.8361
$TarneitLon  = 144.6593

# -----------------------------
# KHULNA
# -----------------------------
$KhulnaName = "Khulna"
$KhulnaLat  = 22.8456
$KhulnaLon  = 89.5403

# -----------------------------
# BAGERHAT
# -----------------------------
$BagerhatName = "Bagerhat"
$BagerhatLat  = 22.6602
$BagerhatLon  = 89.7895

# -----------------------------
# NTFY TOPIC
# -----------------------------
$NtfyTopic = "*****"

# -----------------------------
# CHECK INTERVAL
# -----------------------------
$CheckIntervalMinutes = 15

# -----------------------------
# PREVIOUS LOCAL VALUES ONLY
# (unchanged logic)
# -----------------------------
$PreviousCurrent = $null
$PreviousHigh    = $null
$PreviousLow     = $null

# =====================================================
# WEATHER FUNCTION
# =====================================================
function Get-Weather {

    param(
        [string]$Name,
        [double]$Lat,
        [double]$Lon
    )

    $Url = "https://api.open-meteo.com/v1/forecast?latitude=$Lat&longitude=$Lon&current_weather=true&daily=temperature_2m_max,temperature_2m_min&timezone=auto"

    $Data = Invoke-RestMethod -Uri $Url

    return @{
        Name    = $Name
        Current = [math]::Round($Data.current_weather.temperature, 1)
        High    = [math]::Round($Data.daily.temperature_2m_max[0], 1)
        Low     = [math]::Round($Data.daily.temperature_2m_min[0], 1)
    }
}

# =====================================================
# NTFY SENDER (NO ATTACHMENTS - RAW TEXT ONLY)
# =====================================================
function Send-Notification {

    param(
        [string]$Title,
        [string]$Message
    )

    $Url = "https://ntfy.sh/$NtfyTopic"

    $Client = New-Object System.Net.WebClient
    $Client.Encoding = [System.Text.Encoding]::UTF8

    $Client.Headers.Add("Title", $Title)
    $Client.Headers.Add("Priority", "default")
    $Client.Headers.Add("Tags", "weather,cloud")

    $Client.UploadString($Url, $Message) | Out-Null
}

# =====================================================
# STARTUP
# =====================================================
Write-Host ""
Write-Host "========================================"
Write-Host " WEATHER MONITOR STARTED"
Write-Host "========================================"
Write-Host ""

# =====================================================
# MAIN LOOP
# =====================================================
while ($true) {

    try {

        # -----------------------------
        # FETCH ALL WEATHER
        # -----------------------------
        $Melbourne = Get-Weather $LocalName $LocalLat $LocalLon
        $Tarneit   = Get-Weather $TarneitName $TarneitLat $TarneitLon
        $Khulna    = Get-Weather $KhulnaName $KhulnaLat $KhulnaLon
        $Bagerhat  = Get-Weather $BagerhatName $BagerhatLat $BagerhatLon

        $Now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # =================================================
        # FIRST RUN → SEND START MESSAGE
        # =================================================
        if ($PreviousCurrent -eq $null) {

            $PreviousCurrent = $Melbourne.Current
            $PreviousHigh    = $Melbourne.High
            $PreviousLow     = $Melbourne.Low

            $Message = @"
🌤 WEATHER MONITOR STARTED

MELBOURNE
Current: $($Melbourne.Current)°C
High: $($Melbourne.High)°C
Low: $($Melbourne.Low)°C

TARNEIT
Current: $($Tarneit.Current)°C
High: $($Tarneit.High)°C
Low: $($Tarneit.Low)°C

KHULNA
Current: $($Khulna.Current)°C
High: $($Khulna.High)°C
Low: $($Khulna.Low)°C

BAGERHAT
Current: $($Bagerhat.Current)°C
High: $($Bagerhat.High)°C
Low: $($Bagerhat.Low)°C

Time: $Now
"@

            Send-Notification "Weather Monitor Started" $Message

            Write-Host "$Now | Startup notification sent"
        }
        else {

            # =================================================
            # ONLY MELBOURNE TRIGGERS ALERTS
            # =================================================
            $Changed = $false

            if ($Melbourne.Current -ne $PreviousCurrent) { $Changed = $true }
            if ($Melbourne.High    -ne $PreviousHigh)    { $Changed = $true }
            if ($Melbourne.Low     -ne $PreviousLow)     { $Changed = $true }

            if ($Changed) {

                $Message = @"
🌦 MELBOURNE WEATHER UPDATE

Current:
$PreviousCurrent°C → $($Melbourne.Current)°C

High:
$PreviousHigh°C → $($Melbourne.High)°C

Low:
$PreviousLow°C → $($Melbourne.Low)°C

-------------------------
TARNEIT (INFO ONLY)
Current: $($Tarneit.Current)°C
High: $($Tarneit.High)°C
Low: $($Tarneit.Low)°C

KHULNA (INFO ONLY)
Current: $($Khulna.Current)°C
High: $($Khulna.High)°C
Low: $($Khulna.Low)°C

BAGERHAT (INFO ONLY)
Current: $($Bagerhat.Current)°C
High: $($Bagerhat.High)°C
Low: $($Bagerhat.Low)°C

"@

                Send-Notification "Melbourne Weather Changed" $Message

                Write-Host "$Now | Melbourne weather alert sent"

                $PreviousCurrent = $Melbourne.Current
                $PreviousHigh    = $Melbourne.High
                $PreviousLow     = $Melbourne.Low
            }
            else {
                Write-Host "$Now | No Melbourne change"
            }
        }

    }
    catch {
        Write-Host "ERROR: $_"
    }

    Start-Sleep -Seconds ($CheckIntervalMinutes * 60)
}
