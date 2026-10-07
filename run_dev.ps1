# Helper script to automatically run Flutter with the developer's local IP address
# Usage: .\run_dev.ps1

# Set output encoding to UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Get the first active IPv4 address from Wi-Fi or Ethernet
$ipAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.InterfaceAlias -match "Wi-Fi|Ethernet|LAN" -and $_.IPAddress -notmatch "^169\.254|^127"
} | Select-Object -First 1).IPAddress

# Fallback to emulator host loopback if no network IP is found
if (-not $ipAddress) {
    $ipAddress = "10.0.2.2"
    Write-Warning "[WARNING] Tidak dapat mendeteksi IP Wi-Fi/Ethernet. Menggunakan default emulator: $ipAddress"
} else {
    Write-Host "[INFO] IP Lokal terdeteksi: $ipAddress" -ForegroundColor Green
}

# Reverse port forward for physical devices connected via USB
try {
    adb reverse tcp:3000 tcp:3000 2>$null
} catch {}

$apiUrl = "http://${ipAddress}:3000/api/v1"
Write-Host "[RUN] Menjalankan Flutter dengan API_URL: $apiUrl" -ForegroundColor Cyan

# Run Flutter with the dynamically injected API URL
flutter run --dart-define=API_URL=$apiUrl $args
