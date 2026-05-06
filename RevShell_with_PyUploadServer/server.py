#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import sys

class UploadHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        # Save the file
        filename = "received_file.png"
        with open(filename, 'wb') as f:
            f.write(post_data)
        
        print(f"[+] Saved {content_length} bytes to {filename}")
        
        # Send response
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(b"OK")
    
    def log_message(self, format, *args):
        # Cleaner output
        print(f"[{self.address_string()}] {args[0]}")

def main():
    host = '0.0.0.0'
    port = 8000
    
    server = HTTPServer((host, port), UploadHandler)
    print(f"[*] Upload server running on {host}:{port}")
    print("[*] Waiting for file upload...")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[*] Shutting down...")
        server.server_close()

if __name__ == "__main__":
    main()