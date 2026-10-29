import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from TestSim import TestSim

def main():
    s = TestSim()

    s.loadTopo("dv_line4.topo")
    s.loadNoise("no_noise.txt")
    s.bootAll()

    s.addChannel(s.GENERAL_CHANNEL)
    s.addChannel(s.ROUTING_CHANNEL)

    print "\n========== TEST 6: TTL EXPIRATION =========="

    s.runTime(100)

    print "\n========== PING NODE 1 TO NODE 4 WITH TTL 2 =========="
    s.ping(1, 4, "TTL test")
    s.runTime(30)

    print "\n========== TEST 6 TTL COMPLETE =========="

if __name__ == '__main__':
    main()