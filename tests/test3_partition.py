import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from TestSim import TestSim

def main():
    s = TestSim()

    s.loadTopo("dv_line4.topo")
    s.loadNoise("no_noise.txt")
    s.bootAll()

    s.addChannel(s.COMMAND_CHANNEL)
    s.addChannel(s.GENERAL_CHANNEL)
    s.addChannel(s.ROUTING_CHANNEL)

    print "\n========== TEST 3: INITIAL NETWORK =========="
    s.runTime(100)
    s.routeDMP(1)
    s.runTime(5)

    print "\n========== TEST 3: PARTITION LINK 2-3 =========="
    s.r.remove(2, 3)
    s.r.remove(3, 2)

    s.runTime(150)
    s.routeDMP(1)
    s.runTime(5)

    print "\n========== TEST 3: PING DURING PARTITION =========="
    s.ping(1, 4, "Partition test")
    s.runTime(20)

    print "\n========== TEST 3: RESTORE LINK 2-3 =========="
    s.r.add(2, 3, -54.0)
    s.r.add(3, 2, -54.0)

    s.runTime(150)
    s.routeDMP(1)
    s.runTime(5)

    print "\n========== TEST 3: PING AFTER RECOVERY =========="
    s.ping(1, 4, "Recovery test")
    s.runTime(20)

    print "\n========== TEST 3 COMPLETE =========="

if __name__ == '__main__':
    main()