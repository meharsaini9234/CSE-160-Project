
import sys
import os

sys.path.insert(0, os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..")
))

from TestSim import TestSim


def main():
    s = TestSim()

    # Set up the four-node network
    s.loadTopo("dv_line4.topo")
    s.loadNoise("no_noise.txt")
    s.bootAll()

    # Enable logging
    s.addChannel(s.TRANSPORT_CHANNEL)
    s.addChannel(s.COMMAND_CHANNEL)

    # Allow neighbor discovery and DV routing
    s.runTime(100)

    # Start server on node 4, port 25
    s.cmdTestServer(4, 25)
    s.runTime(10)

    # Pause node 4's receiver for client 1:15
    s.cmdPauseReceiver(4, 1, 15, 25)
    s.runTime(5)

    # Start 1024-byte transfer
    s.cmdTestClient(1, 4, 15, 25, 1024)

    # Keep receiver paused so its buffer fills
    s.runTime(200)

    # Resume application consumption
    s.cmdResumeReceiver(4, 1, 15, 25)

    # Allow transfer to finish
    s.runTime(500)

    # Request graceful close
    s.cmdClientClose(1, 4, 15, 25)
    s.runTime(200)


if __name__ == "__main__":
    main()
