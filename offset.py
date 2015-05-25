from struct import pack
from serial import Serial
import sys

port = sys.argv[1]
rate = sys.argv[2]

offset = int(sys.argv[3])

s = Serial(port, rate)
s.write('\x55\x55\x02\x04')

cs = 0x02 ^ 0x04

print 'hi'

for i in bytearray(pack('B', offset)):
	print i
	cs = cs ^ i
	s.write(pack('B', i))

s.write(pack('B', cs))
