import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from TestSim import TestSim

def main():
    s = TestSim()

    s.loadTopo("dv_capacity.topo")
    s.loadNoise("no_noise.txt")
    s.bootAll()

    s.addChannel(s.COMMAND_CHANNEL)
    s.addChannel(s.GENERAL_CHANNEL)
    s.addChannel(s.ROUTING_CHANNEL)

    print "\n========== TEST 5: PACKET CAPACITY =========="

    s.runTime(150)

    print "\n========== NODE 1 ROUTING TABLE =========="
    s.routeDMP(1)
    s.runTime(5)

    print "\n========== NODE 8 ROUTING TABLE =========="
    s.routeDMP(8)
    s.runTime(5)

    print "\n========== PING NODE 1 TO NODE 8 =========="
    s.ping(1, 8, "Capacity test")
    s.runTime(30)

    print "\n========== TEST 5 COMPLETE =========="

if __name__ == '__main__':
    main()