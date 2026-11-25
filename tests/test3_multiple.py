import sys
import os

sys.path.insert(0, os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..")
))

from TestSim import TestSim

s = TestSim()
s.loadTopo("dv_line4.topo")
s.loadNoise("no_noise.txt")
s.bootAll()

s.addChannel(s.COMMAND_CHANNEL)
s.addChannel(s.TRANSPORT_CHANNEL)

s.runTime(100)

s.cmdTestServer(4, 25)
s.runTime(10)

s.cmdTestClient(1, 4, 15, 25, 1024)
s.runTime(5)
s.runTime(5)
s.cmdTestClient(2, 4, 16, 25, 1024)

s.runTime(500)

s.cmdClientClose(1, 4, 15, 25)
s.runTime(5)
s.cmdClientClose(2, 4, 16, 25)

s.runTime(200)
