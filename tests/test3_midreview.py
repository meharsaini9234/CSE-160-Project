import sys
import os

# Allow Python to import TestSim.py from the project root
sys.path.insert(0, os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..")
))

from TestSim import TestSim


def main():
    s = TestSim()

    # -----------------------------------
    # 1. Set up the network
    # -----------------------------------
    s.loadTopo("dv_line4.topo")
    s.loadNoise("no_noise.txt")

    s.bootAll()

    # Enable logging
    s.addChannel(s.COMMAND_CHANNEL)
    s.addChannel(s.ROUTING_CHANNEL)
    s.addChannel(s.TRANSPORT_CHANNEL)

    # Allow Project 2 distance-vector routing to converge
    s.runTime(100)

    # -----------------------------------
    # 2. Test multi-hop routing
    # -----------------------------------
    print("Testing routing from Node 1 to Node 4")

    s.ping(1, 4, "Routing Check")
    s.runTime(30)

    # -----------------------------------
    # 3. Start TCP server
    # -----------------------------------
    print("Starting server on Node 4")

    s.cmdTestServer(4)
    s.runTime(10)

    # -----------------------------------
    # 4. Start TCP client
    # -----------------------------------
    print("Starting client on Node 1")

    s.cmdTestClient(1)

    # -----------------------------------
    # 5. Run handshake, data, teardown
    # -----------------------------------
    s.runTime(200)


if __name__ == "__main__":
    main()
