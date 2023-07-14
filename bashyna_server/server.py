# This is needed for Bashyna Receiver to work in ComputerCraft
# Using the Kiwiclient (https://github.com/jks-prv/kiwiclient)

import http.server
import urllib.parse
import subprocess
import threading
import os
import time

TIMER = 30 # This can probably be lower. Ill recommend 15 Seconds.
ALLOWED_IPS = ['127.0.0.1', '192.168.1.100', '10.0.0.1']  # Add your allowed IP addresses here. If you're running this on a Minecraft Multiplayer Server, the request will be made from your Server's IP anyways.
DOMAIN = "localhost" # Change this to your domain or IP


class RequestHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        client_ip = self.client_address[0]
        if client_ip not in ALLOWED_IPS:
            self.send_response(403)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Access denied. Your IP is not allowed.')
            return

        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length).decode('utf-8')
        parsed_data = urllib.parse.parse_qs(post_data)
        
        frequency = parsed_data.get('frequency', [''])[0]
        filename = parsed_data.get('filename', [''])[0]
        
        if not frequency or not filename:
            self.send_response(400)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Missing frequency or filename in the request.')
            return
        
        command = f'python kiwirecorder.py -s zubi.proxy.kiwisdr.com -p 8073 -f {frequency} -m usb --tlimit=5 --filename={filename}' # You can change this to any proxy you want
        try:
            subprocess.run(command, shell=True, check=True)
        except subprocess.CalledProcessError:
            self.send_response(500)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Error occurred while processing the request.')
            return
        
        wav_file_link = f'http://{DOMAIN}:7744/{filename}.wav'
        
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        self.wfile.write(wav_file_link.encode('utf-8'))
        
        # Schedule file deletion in a separate thread
        deletion_thread = threading.Thread(target=self.schedule_file_deletion, args=(filename,))
        deletion_thread.start()

    def do_GET(self):
        client_ip = self.client_address[0]
        if client_ip not in ALLOWED_IPS:
            self.send_response(403)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Access denied. Your IP is not allowed.')
            return

        parsed_url = urllib.parse.urlparse(self.path)
        filename = os.path.splitext(os.path.basename(parsed_url.path))[0]
        file_path = f'{filename}.wav'

        if not os.path.exists(file_path):
            print("ws")
            self.send_response(404)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'File not found.')
            return

        self.send_response(200)
        self.send_header('Content-type', 'audio/wav')
        self.end_headers()

        with open(file_path, 'rb') as file:
            self.wfile.write(file.read())

    def schedule_file_deletion(self, filename):
        print(f'Deleting {filename} in {TIMER} seconds!')
        time.sleep(TIMER)
        file_path = f'{filename}.wav'
        if os.path.exists(file_path):
            os.remove(file_path)
            print(f'Deletion of {filename} successful!')

if __name__ == '__main__':
    server_address = ('', 7744)
    httpd = http.server.HTTPServer(server_address, RequestHandler)
    httpd.serve_forever()
