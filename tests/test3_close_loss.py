import sys
import os

sys.path.insert(0, os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..")
))

from TestSim import TestSim


def main():
    s = TestSim()

    s.loadTopo("dv_line4.topo")
    s.loadNoise("no_noise.txt")
    s.bootAll()

    s.addChannel(s.TRANSPORT_CHANNEL)
    s.addChannel(s.COMMAND_CHANNEL)

    s.runTime(100)

    # Server on node 4
    s.cmdTestServer(4, 25)
    s.runTime(10)

    # Transfer 1024 bytes
    s.cmdTestClient(1, 4, 15, 25, 1024)
    s.runTime(500)

    # Initiate closing after data transfer
    s.cmdClientClose(1, 4, 15, 25)

    # Allow FIN retransmission and cleanup
    s.runTime(300)


if __name__ == "__main__":
    main()
