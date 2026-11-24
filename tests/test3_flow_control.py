
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

    # Enable debug output
    s.addChannel(s.COMMAND_CHANNEL)
    s.addChannel(s.ROUTING_CHANNEL)
    s.addChannel(s.TRANSPORT_CHANNEL)

    # Allow distance-vector routing to converge
    s.runTime(100)

    # Start TCP server on Node 4
    s.cmdTestServer(4)
    s.runTime(10)

    # Start TCP client on Node 1
    # Current Node.nc transfers 1024 bytes
    s.cmdTestClient(1)

    # Longer run for delayed receiver consumption
    # and window reopening
    s.runTime(1000)


if __name__ == "__main__":
    main()
