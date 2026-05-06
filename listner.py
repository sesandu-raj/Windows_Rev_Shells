#!/usr/bin/env python3
import socket
import sys
import time

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', 4444))
    server.listen(1)
    
    print("[*] Listening on 0.0.0.0:4444")
    print("[*] Waiting for connection...")
    
    conn, addr = server.accept()
    print(f"[+] Connection from {addr[0]}:{addr[1]}")
    
    # Receive initial message
    data = conn.recv(4096)
    print(data.decode('utf-8', errors='ignore'), end='')
    
    while True:
        try:
            # Wait for prompt
            data = conn.recv(4096).decode('utf-8', errors='ignore')
            if not data:
                break
            print(data, end='')
            
            # Get user input
            cmd = input()
            
            # Send command with newline
            conn.send((cmd + "\n").encode('utf-8'))
            
            # Small delay for command to execute
            time.sleep(0.1)
            
        except KeyboardInterrupt:
            print("\n[*] Exiting")
            break
        except Exception as e:
            print(f"[-] Error: {e}")
            break
    
    conn.close()
    server.close()
    print("[*] Connection closed")

if __name__ == "__main__":
    main()