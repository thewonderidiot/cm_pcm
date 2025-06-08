import csv
import re

groups = {}

groups['22A'] = [0]*4
groups['12A'] = [0]*16
groups['51A'] = [0]*15
groups['11A'] = [0]*180
groups['10A'] = [0]*150
groups['22DP'] = [0]*2
groups['51DP'] = [0]*2
groups['11DP'] = [0]*33

for i in range(1,18):
    if i == 16:
        continue

    with open('j%u.csv' % i, 'r', newline='') as f:
        r = csv.reader(f)
        for row in r:
            net = row[1]
            if not net or not net[0].isdigit() or 'cal' in net:
                continue
            parts = re.match(r'(\d*[A-Z]+)(\d+)(.*)', net)

            group = parts[1]
            pin = int(parts[2]) - 1
            bit = parts[3].strip()
            bit = int(bit[4:]) if 'bit' in bit else 0

            if groups[group][pin] & (1 << bit):
                if 'D' in group:
                    print('%s%u bit %u - DUPLICATE' % (group, pin+1, bit))
                else:
                    print('%s%u - DUPLICATE' % (group, pin+1))

            groups[group][pin] |= 1 << bit

for group, pins in groups.items():
    for pin,found in enumerate(pins):
        if group in ('51DP', '11DP') and pin == 0:
            continue

        if 'D' in group:
            channel = '%s%u' % (group, pin+1)
            if channel == '11DP2':
                bits = 32
            else:
                bits = 8

            for bit in range(bits):
                if not (found & (1 << bit)):
                    print('%s bit %u' % (channel, bit))

        else:
            if not found:
                print('%s%u' % (group, pin+1))
