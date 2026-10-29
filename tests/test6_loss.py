from TestSim import TestSim

def main():
    s = TestSim()

    s.loadTopo("dv_loss.topo")
    s.loadNoise("lossy_noise.txt")
    s.bootAll()

    s.addChannel(s.GENERAL_CHANNEL)
    s.addChannel(s.ROUTING_CHANNEL)
    s.addChannel(s.NEIGHBOR_CHANNEL)
    s.addChannel("Csma")
    s.addChannel("Packet")
    s.addChannel("Acks")
    s.addChannel("SNRLoss")
    s.addChannel("CpmModelC")

    print "\n========== TEST 6: LOSSY NETWORK =========="

    s.runTime(150)

    print "\n========== NODE 1 ROUTING TABLE =========="
    s.routeDMP(1)
    s.runTime(5)

    print "\n========== FIRST PING =========="
    s.ping(1, 4, "Loss test 1")
    s.runTime(30)

    print "\n========== SECOND PING =========="
    s.ping(1, 4, "Loss test 2")
    s.runTime(30)

    print "\n========== THIRD PING =========="
    s.ping(1, 4, "Loss test 3")
    s.runTime(30)

    print "\n========== TEST 6 COMPLETE =========="

if __name__ == '__main__':
    main()
