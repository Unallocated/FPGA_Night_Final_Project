from struct import pack
from serial import Serial
import sys

port = sys.argv[1]
rate = sys.argv[2]

flags = int(sys.argv[3], 2)

s = Serial(port, rate)
s.write('\x55\x55\x04\x02')

cs = 0x04 ^ 0x02

byteValues = bytearray(pack('>I', flags))

for i in range(1, 4):
	print i
	cs = cs ^ byteValues[i]
	s.write(pack('B', byteValues[i]))

#for i in bytearray(pack('>H', angle_inc)):
#	print i
#	cs = cs ^ i
#	s.write(pack('B', i))

s.write(pack('B', cs))
