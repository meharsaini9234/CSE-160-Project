
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

    s.addChannel(s.COMMAND_CHANNEL)
    s.addChannel(s.TRANSPORT_CHANNEL)

    # Allow routing to converge
    s.runTime(100)

    # Node 4 listens on port 25
    s.cmdTestServer(4, 25)
    s.runTime(10)

    # Node 1 sends 300 bytes:
    # source port 15 -> destination port 25
    s.cmdTestClient(1, 4, 15, 25, 1024)

    # Allow the entire transfer
    s.runTime(500)

    # Explicitly close the connection
    s.cmdClientClose(1, 4, 15, 25)

    # Allow FIN teardown and cleanup
    s.runTime(200)


if __name__ == "__main__":
    main()
