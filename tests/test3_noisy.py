
import sys
import os

sys.path.insert(0, os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..")
))

from TestSim import TestSim


def main():
    s = TestSim()

    s.loadTopo("dv_line4.topo")
    s.loadNoise("lossy_noise.txt")
    s.bootAll()

    s.addChannel(s.COMMAND_CHANNEL)
    s.addChannel(s.ROUTING_CHANNEL)
    s.addChannel(s.TRANSPORT_CHANNEL)

    # Wait for routing convergence
    s.runTime(100)

    # Start server on node 4
    s.cmdTestServer(4)
    s.runTime(10)

    # Tell receiver to expect 1024 bytes
    s.cmdExpectTransfer(4, 1, 10, 20, 1024)
    s.runTime(5)

    # Start client
    s.cmdTestClient(1, 4, 10, 20, 1024)

    # Allow transfer to progress
    s.runTime(500)

    # Explicitly close the connection
    s.cmdClientClose(1, 4, 10, 20)

    # Process FIN/ACK exchange and cleanup
    s.runTime(200)


if __name__ == "__main__":
    main()
