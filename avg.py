from struct import pack
from serial import Serial
import sys
# python avg.py COM6 500000 255
port = sys.argv[1]
rate = sys.argv[2]

weight = int(sys.argv[3])

s = Serial(port, rate)
s.write('\x55\x55\x02\x01')

cs = 0x02 ^ 0x01

for i in bytearray(pack('B', weight)):
	print i
	cs = cs ^ i
	s.write(pack('B', i))

s.write(pack('B', cs))
