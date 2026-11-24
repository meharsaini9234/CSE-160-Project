
import sys
import os

sys.path.insert(0, os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..")
))

from TestSim import TestSim


def main():
    s = TestSim()

    # Four-node multi-hop network
    s.loadTopo("dv_line4.topo")
    s.loadNoise("no_noise.txt")
    s.bootAll()

    # Enable necessary output
    s.addChannel(s.COMMAND_CHANNEL)
    s.addChannel(s.ROUTING_CHANNEL)
    s.addChannel(s.TRANSPORT_CHANNEL)

    # Wait for routing to converge
    s.runTime(100)

    # Start server on node 4
    s.cmdTestServer(4)
    s.runTime(10)

    # Start client on node 1
    # Node.nc currently requests 1024 bytes
    s.cmdTestClient(1)

    # Allow time for lost packet recovery
    # and for the connection to close
    s.runTime(500)


if __name__ == "__main__":
    main()
