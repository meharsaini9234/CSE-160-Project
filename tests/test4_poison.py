import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from TestSim import TestSim

def main():
    s = TestSim()

    s.loadTopo("dv_poison.topo")
    s.loadNoise("no_noise.txt")
    s.bootAll()

    s.addChannel(s.ROUTING_CHANNEL)
    s.addChannel(s.GENERAL_CHANNEL)

    print "\n========== TEST 4: POISON REVERSE =========="

    s.runTime(100)

    print "\n========== NODE 1 ROUTING TABLE =========="
    s.routeDMP(1)
    s.runTime(5)

    print "\n========== TEST 4 COMPLETE =========="

if __name__ == '__main__':
    main()