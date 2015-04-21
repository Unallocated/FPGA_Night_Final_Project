from struct import pack
from serial import Serial
import sys

port = sys.argv[1]
rate = sys.argv[2]

scale = int(sys.argv[3], 2)
# ident msb mb lsb
s = Serial(port, rate)
s.write('\x55\x55\x04\x02')

cs = 0x04 ^ 0x02

dataBytes = bytearray(pack('<I', scale))
cs = cs ^ dataBytes[2]
s.write(pack('B', dataBytes[2]))
cs = cs ^ dataBytes[1]
s.write(pack('B', dataBytes[1]))
cs = cs ^ dataBytes[0]
s.write(pack('B', dataBytes[0]))

#for i in bytearray(pack('B3', scale)):
#	print i
#	cs = cs ^ i
#	s.write(pack('B', i))

s.write(pack('B', cs))
