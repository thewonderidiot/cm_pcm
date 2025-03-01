#!/usr/bin/env python3
from serial.tools import list_ports
from pathlib import Path
import argparse
import serial
import time
import struct
import socket
import csv
import re

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
AGC_BASE_ID = 0x1000

class TableEntry:
    def __init__(self, channel, group, index, byte):
        self.channel = channel
        self.group = group
        self.index = index
        self.byte = byte
        self.final = False

    def __eq__(self, other):
        return self.channel == other.channel

    def __gt__(self, other):
        if self.group != other.group:
            return False
        if self.index != other.index:
            return self.index > other.index
        elif self.byte is not None:
            return self.byte > other.byte if other.byte is not None else True
        else:
            return False

def load_table(fn):
    table = []
    maxes = {}
    with open(fn, 'r', newline='') as f:
        reader = csv.reader(f)
        for row in reader:
            entries = []
            for channel in row:
                if not channel:
                    break
                parts = re.match(r'(\d*)([A-Z]+)(\d+)([A-E]?)', channel)
                group = (parts[2]+parts[1]).lower()
                index = int(parts[3])
                if group not in ('src', 'nul'):
                    index -= 1
                byte = ord(parts[4])-ord('A') if parts[4] else None

                entry = TableEntry(channel, group, index, byte)
                entries.append(entry)
                if group not in maxes or entry > maxes[group]:
                    maxes[group] = entry

            table.append(entries)

    max_values = list(maxes.values())
    for row in table:
        for entry in row:
            if entry in max_values:
                entry.final = True

    return table

def load_agc_downlists(program):
    downlists = []
    word_data = {}

    csvs = list(Path(program).glob('**/*.csv'))
    for list_id,fn in enumerate(sorted(csvs)):
        downlist = []
        downlists.append(downlist)

        with open(fn, 'r', newline='') as f:
            reader = csv.reader(f)
            for i,row in enumerate(reader):
                if not row[1]:
                    dp = True
                    row.pop(1)
                else:
                    dp = False

                words = []
                downlist.append(words)
                for word in row:
                    words.append({
                        'name': word,
                        'packet': None,
                        'index': None
                    })
                    if word not in word_data:
                        word_data[word] = {
                            'dp': dp,
                            'counts': [0]*len(csvs)
                        }

                    word_data[word]['counts'][list_id] += 1

    packet_defs = {}
    for word,data in word_data.items():
        if word == 'GARBAGE':
            continue

        counts = data['counts']
        max_count = max(counts)
        counts = [min(c, 1) for c in counts]
        counts.append(max_count)
        counts = tuple(counts)

        if counts not in packet_defs:
            packet_defs[counts] = {
                'words': [],
                'fmt': ''
            }

        packet_defs[counts]['words'].append(word)
        packet_defs[counts]['fmt'] += 'I' if data['dp'] else 'H'

    word_mapping = {}
    for pkt_idx, counts in enumerate(packet_defs):
        pkt_def = packet_defs[counts]
        for word_idx, word in enumerate(pkt_def['words']):
            word_mapping[word] = (pkt_idx, word_idx)

    for downlist in downlists:
        for word_idx, words in enumerate(downlist):
            for word in words:
                if word['name'] == 'GARBAGE':
                    continue
                pkt_data = word_mapping[word['name']]
                word['packet'] = pkt_data[0]
                word['index'] = pkt_data[1]

    return downlists, [pkt_def['fmt'] for pkt_def in packet_defs.values()]

class LockState:
    UNLOCKED = 0
    TRACKING = 1
    HBR = 2
    LBR = 3

class PCMStreamer:
    def reset_data(self):
        self.a22 = [0]*4
        self.a12 = [0]*16
        self.a51 = [0]*15
        self.a11 = [0]*180
        self.a10 = [0]*150
        self.dp22 = [0]*2
        self.dp51 = [0]*2
        self.ds51 = [0]
        self.dp11 = [0]*33
        self.dp10 = [0]*1
        self.src = [0]*2
        self.nul = [0]*1

    def __init__(self, downlists):
        self.reset_data()

        self.hbr_table = load_table('hbr.csv')
        self.lbr_table = load_table('lbr.csv')

        self.agc_packets = []
        self.agc_downlist = None
        self.agc_idx = 0

        self.downlists, self.agc_pkt_fmts = load_agc_downlists(downlists)
        for fmt in self.agc_pkt_fmts:
            self.agc_packets.append([0]*len(fmt))

        self.state = LockState.UNLOCKED
        self.offset = 0
        self.frame = 0
        self.buffer = b''

        port = None
        devices = list_ports.comports()
        for dev in reversed(devices):
            if dev.vid == 0x0403 and dev.pid == 0x6010:
                port = dev.device

        # if port is None:
        #     raise RuntimeError('No FPGA found')

        # self.serial = serial.Serial(port, 115200, timeout=0.01)
        self.serial = open('skylark_p63.bin', 'rb')
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind(('172.17.0.1', 8081))
        self.sock.settimeout(0.01)
        self.sock.listen(1)

        self.conn = None

    def main_loop(self):
        while True:
            if self.conn is None:
                try:
                    self.conn,addr = self.sock.accept()
                    print('Connected!')
                except:
                    pass

            word = self.serial.read(1)
            if word:
                self.process_word(word)
                # print(word.hex())
                # time.sleep(0.00015625)

    def process_word(self, new_word):
        self.buffer += new_word

        if self.state == LockState.UNLOCKED:
            if len(self.buffer) > 3:
                self.buffer = self.buffer[-3:]

            if self.buffer == PCM_SYNC:
                self.state = LockState.TRACKING

        if self.state == LockState.TRACKING:
            if len(self.buffer) == 131 and self.buffer[128:131] == PCM_SYNC:
                self.offset = 0
                self.frame = 0
                self.state = LockState.HBR

            elif len(self.buffer) == 203:
                if self.buffer[200:203] == PCM_SYNC:
                    self.offset = 0
                    self.frame = 0
                    self.state = LockState.LBR
                    self.reset_data()
                else:
                    self.buffer = self.buffer[self.buffer.find(PCM_SYNC):]

        if self.state in (LockState.LBR, LockState.HBR):
            table = self.lbr_table if self.state == LockState.LBR else self.hbr_table

            for word in self.buffer:
                if self.offset == 0:
                    print('')
                print('%02x' % word, end='')
                slot = table[self.offset]
                self.offset += 1
                if self.offset >= len(table):
                    self.offset = 0
                index = self.frame % len(slot)
                entry = slot[index]

                if ((entry.channel == '51DP1A' and word != PCM_SYNC[0]) or
                    (entry.channel == '51DP1B' and word != PCM_SYNC[1]) or
                    (entry.channel == '51DP1C' and word != PCM_SYNC[2])):
                    self.state = LockState.UNLOCKED
                    break

                if entry.channel == '51DP1D':
                    self.frame = (word & 0x3F) - 1

                group_data = getattr(self, entry.group)
                if entry.byte is None:
                    group_data[entry.index] = word
                else:
                    group_data[entry.index] &= ~(0xFF << (8*entry.byte))
                    group_data[entry.index] |= word << (8*entry.byte)

                if entry.final:
                    fn = getattr(self, 'pack_' + entry.group)
                    pkt = fn()

                    if pkt is not None and self.conn is not None:
                        self.conn.sendall(pkt)

            self.buffer = b''

    def pack_a22(self):
        packet = COSMOS_SYNC + struct.pack('>H4B', A22_ID, *self.a22)
        return packet

    def pack_a12(self):
        packet = COSMOS_SYNC + struct.pack('>H16B', A12_ID, *self.a12)
        return packet

    def pack_a51(self):
        packet = COSMOS_SYNC + struct.pack('>H15B', A51_ID, *self.a51)
        return packet

    def pack_a11(self):
        packet = COSMOS_SYNC + struct.pack('>H180B', A11_ID, *self.a11)
        return packet

    def pack_a10(self):
        packet = COSMOS_SYNC + struct.pack('>H150B', A10_ID, *self.a10)
        return packet

    def pack_dp22(self):
        packet = COSMOS_SYNC + struct.pack('>H2B', DP22_ID, *self.dp22)
        return packet

    def pack_dp10(self):
        packet = COSMOS_SYNC + struct.pack('>HB', DP10_ID, *self.dp10)
        return packet

    def pack_dp11(self):
        d2 = self.dp11[1:]
        packet = COSMOS_SYNC + struct.pack('>H', DP11_ID) + struct.pack('<I31B', *d2)
        return packet

    def pack_dp51(self):
        packet = COSMOS_SYNC + struct.pack('>H', DP51_ID) + struct.pack('<IB', *self.dp51)
        return packet

    def pack_ds51(self):
        ds51 = struct.unpack('>Q', struct.pack('<Q', *self.ds51))[0] >> 24
        wo = ds51 >> 39
        word = [((ds51 >> 24) & 0o77777), ((ds51 >> 8) & 0o77777)]
        agc_packet = b''

        if wo == 0 and word[1] == 0o77340:
            self.agc_index = 0
            self.agc_downlist = 0o77777 - word[0]
            if self.agc_downlist == 0o76000:
                self.agc_downlist_len = 129
            else:
                self.agc_downlist_len = 100

        if self.agc_downlist is None:
            return None

        word_data = self.downlists[self.agc_downlist][self.agc_index]
        if len(word_data) == 1:
            word[0] = (word[0] << 15) | word[1]

        for w,d in zip(word, word_data):
            pkt = d['packet']
            if pkt is None:
                continue
            idx = d['index']
            self.agc_packets[pkt][idx] = w
            if (idx + 1) == len(self.agc_pkt_fmts[pkt]):
                agc_packet += COSMOS_SYNC + struct.pack('>H', AGC_BASE_ID + pkt) + struct.pack('>' + self.agc_pkt_fmts[pkt], *self.agc_packets[pkt])

        self.agc_index += 1
        if self.agc_index >= self.agc_downlist_len:
            self.agc_downlist = None

        # _51ds1 = struct.pack('<Q', *self.ds51)[:5]
        # packet = COSMOS_SYNC + struct.pack('>H', DS51_ID) + _51ds1
        # return packet
        if len(agc_packet) == 0:
            return None
        else:
            # print(agc_packet.hex())
            pass
        return agc_packet

    def pack_src(self):
        packet = COSMOS_SYNC + struct.pack('>H2B', SRC_ID, *self.src)
        return packet

    def pack_nul(self):
        return None


def main():
    parser = argparse.ArgumentParser(description='CM PCM streaming deframer')
    parser.add_argument('downlists', help='Directory containing AGC downlist CSVs')
    args = parser.parse_args()
    streamer = PCMStreamer(args.downlists)
    streamer.main_loop()

if __name__ == "__main__":
    main()
