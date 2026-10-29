import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from TestSim import TestSim

def main():
    s = TestSim()

    s.loadTopo("dv_alternate.topo")
    s.loadNoise("no_noise.txt")
    s.bootAll()

    s.addChannel(s.COMMAND_CHANNEL)
    s.addChannel(s.GENERAL_CHANNEL)
    s.addChannel(s.ROUTING_CHANNEL)

    print "\n========== INITIAL ROUTING =========="
    s.runTime(100)
    s.routeDMP(1)
    s.runTime(5)

    print "\n========== LINK 2-4 FAILURE =========="
    s.r.remove(2, 4)
    s.r.remove(4, 2)

    s.runTime(100)
    s.routeDMP(1)
    s.runTime(5)

    s.ping(1, 4, "Alternate path test")
    s.runTime(20)

    print "\n========== LINK 2-4 RECOVERY =========="
    s.r.add(2, 4, -54.0)
    s.r.add(4, 2, -54.0)

    s.runTime(100)
    s.routeDMP(1)
    s.runTime(5)

    s.ping(1, 4, "Recovered path test")
    s.runTime(20)

    print "\n========== TEST 2 COMPLETE =========="

if __name__ == '__main__':
    main()
