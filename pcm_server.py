#!/usr/bin/env python3
from serial.tools import list_ports
import serial
import time
import struct
import socket

COSMOS_SYNC = b'\xA5\x5A'
PCM_SYNC = b'\x05\x79\xB7'

A22_ID = 0x022A
A12_ID = 0x012A
A51_ID = 0x051A
A11_ID = 0x011A
A10_ID = 0x010A
DP22_ID = 0x022D
DP10_ID = 0x010D
DP11_ID = 0x011D
DP51_ID = 0x051D
DS51_ID = 0x0515
SRC_ID =  0x054C

def main():
    port = None
    devices = list_ports.comports()
    for dev in devices:
        if dev.vid == 0x0403 and dev.pid == 0x6010:
            port = dev.device

    s = serial.Serial(port, 115200, timeout=0.01)
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(('172.17.0.1', 8081))
    sock.settimeout(0.01)
    sock.listen(1)

    conn = None

    start = time.time()
    data = b''
    while True:
        if conn is None:
            try:
                conn,addr = sock.accept()
                print('Connected!')
            except:
                pass

        data += s.read(128)
        if not data:
            continue

        if not data.startswith(PCM_SYNC):
            data = data[data.find(PCM_SYNC):]

        num_frames = len(data)//128
        for i in range(num_frames):
            process_prime_frame(data[:128], conn)
            data = data[128:]


a22 = [0]*4
a12 = [0]*16
a51 = [0]*15
a11 = [0]*180
a10 = [0]*150
dp22 = [0]*2
dp51 = [0]*2
ds51 = [0]*5
dp11 = [0]*33
dp10 = [0]
src = [0]*2

def process_prime_frame(words, conn):
    print(words.hex())
    frame = (words[3] & 0x3F) - 1

    # Words 1-4
    dp51[0] = (words[0] << 24) | (words[1] << 16) | (words[2] << 8) | (words[3] << 0)

    # Words 5-8
    for i in range(4):
        a22[i] = words[4+i]

    send_22a(a22, conn)

    # Words 9-12
    for i in range(4):
        a11[(frame % 5)*36+i] = words[8+i]

    # Words 13-16
    for i in range(4):
        a12[i] = words[12+i]

    # Word 17
    a11[4+(frame % 5)*36] = words[16]

    # Words 18-19
    for i in range(2):
        dp22[i] = words[17+i]

    send_22dp(dp22, conn)

    # Word 20
    if (frame % 5) == 0:
        dp10[0] = words[19]
        send_10dp(dp10, conn)
    elif (frame % 5) == 1:
        src[0] = words[19]
    elif (frame % 5) == 2:
        src[1] = words[19]
        send_src(src, conn)

    # Words 21-24
    for i in range(4):
        a12[4+i] = words[20+i]

    # Words 25-28
    for i in range(4):
        a11[5+(frame % 5)*36+i] = words[24+i]

    # Words 29-31
    for i in range(3):
        a51[i] = words[28+i]

    # Words 32-36
    for i in range(5):
        ds51[i] = words[31+i]

    send_51ds(ds51, conn)

    # Words 37-40
    for i in range(4):
        a22[i] = words[36+i]

    send_22a(a22, conn)

    # Words 41-44
    for i in range(4):
        a11[9+(frame % 5)*36+i] = words[40+i]

    # Words 45-48
    for i in range(4):
        a12[8+i] = words[44+i]

    # Word 49
    a11[13+(frame % 5)*36] = words[48]

    # Words 50-51
    for i in range(2):
        dp22[i] = words[49+i]

    send_22dp(dp22, conn)

    # Word 52
    a10[frame*3] = words[51]

    # Words 53-56
    for i in range(4):
        a12[12+i] = words[52+i]

    send_12a(a12, conn)

    # Words 57-60
    for i in range(4):
        a11[14+(frame % 5)*36+i] = words[56+i]

    # Words 61-64
    for i in range(4):
        a51[3+i] = words[60+i]

    # Words 65-68
    if (frame % 5) == 0:
        dp11[1] = (words[64] << 24) | (words[65] << 16) | (words[66] << 8) | (words[67] << 0)
    else:
        for i in range(4):
            dp11[-2+(frame % 5)*7+i] = words[64+i]

    # Words 69-72
    for i in range(4):
        a22[i] = words[68+i]

    send_22a(a22, conn)

    # Words 73-76
    for i in range(4):
        a11[18+(frame % 5)*36+i] = words[72+i]

    # Words 77-80
    for i in range(4):
        a12[i] = words[76+i]

    # Word 81
    a11[22+(frame % 5)*36] = words[80]

    # Words 82-83
    for i in range(2):
        dp22[i] = words[81+i]

    send_22dp(dp22, conn)

    # Word 84
    a10[1+frame*3] = words[83]

    # Words 85-88
    for i in range(4):
        a12[4+i] = words[84+i]

    # Words 89-92
    for i in range(4):
        a11[23+(frame % 5)*36+i] = words[88+i]

    # Words 93-96
    for i in range(4):
        a51[7+i] = words[92+i]

    # Words 97-99
    for i in range(3):
        dp11[2+(frame % 5)*7+i] = words[96+i]

    if (frame % 5) == 4:
        send_11dp(dp11, conn)

    # Word 100
    dp51[1] = words[99]

    send_51dp(dp51, conn)

    # Words 101-104
    for i in range(4):
        a22[i] = words[100+i]

    send_22a(a22, conn)

    # Words 105-108
    for i in range(4):
        a11[27+(frame % 5)*36+i] = words[104+i]

    # Words 109-112
    for i in range(4):
        a12[8+i] = words[108+i]

    # Word 113
    a11[31+(frame % 5)*36] = words[112]

    # Words 114-115
    for i in range(2):
        dp22[i] = words[113+i]

    send_22dp(dp22, conn)

    # Word 116
    a10[2+frame*3] = words[115]

    if frame == 49:
        send_10a(a10, conn)

    # Words 117-120
    for i in range(4):
        a12[12+i] = words[116+i]

    send_12a(a12, conn)

    # Words 121-124 
    for i in range(4):
        a11[32+(frame % 5)*36+i] = words[120+i]

    if (frame % 5) == 4:
        send_11a(a11, conn)

    # Words 125-128
    for i in range(4):
        a51[11+i] = words[124+i]

    send_51a(a51, conn)

def send_22a(d, conn):
    packet = COSMOS_SYNC + struct.pack('>H4B', A22_ID, *d)
    if conn is not None:
        conn.sendall(packet)

def send_12a(d, conn):
    packet = COSMOS_SYNC + struct.pack('>H16B', A12_ID, *d)
    if conn is not None:
        conn.sendall(packet)

def send_51a(d, conn):
    packet = COSMOS_SYNC + struct.pack('>H15B', A51_ID, *d)
    if conn is not None:
        conn.sendall(packet)

def send_11a(d, conn):
    packet = COSMOS_SYNC + struct.pack('>H180B', A11_ID, *d)
    if conn is not None:
        conn.sendall(packet)

def send_10a(d, conn):
    packet = COSMOS_SYNC + struct.pack('>H150B', A10_ID, *d)
    if conn is not None:
        conn.sendall(packet)

def send_22dp(d, conn):
    packet = COSMOS_SYNC + struct.pack('>H2B', DP22_ID, *d)
    if conn is not None:
        conn.sendall(packet)

def send_10dp(d, conn):
    packet = COSMOS_SYNC + struct.pack('>HB', DP10_ID, *d)
    if conn is not None:
        conn.sendall(packet)

def send_11dp(d, conn):
    d2 = d[1:]
    packet = COSMOS_SYNC + struct.pack('>HI31B', DP11_ID, *d2)
    if conn is not None:
        conn.sendall(packet)

def send_51dp(d, conn):
    packet = COSMOS_SYNC + struct.pack('>HIB', DP51_ID, *d)
    if conn is not None:
        conn.sendall(packet)

def send_51ds(d, conn):
    packet = COSMOS_SYNC + struct.pack('>H5B', DS51_ID, *d)
    if conn is not None:
        conn.sendall(packet)

def send_src(d, conn):
    packet = COSMOS_SYNC + struct.pack('>H2B', SRC_ID, *d)
    if conn is not None:
        conn.sendall(packet)

if __name__ == "__main__":
    main()
