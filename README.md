# Introduction
This project is part of CSE 160 and builds on the original TinyOS network skeleton code. For Project 2, we implemented Distance Vector routing to allow nodes to communicate across multiple hops.

Our implementation includes bidirectional neighbor discovery, routing tables, periodic Distance Vector advertisements, poison reverse, route expiration, IP forwarding, and ping requests and replies.

# General Information
## Data Structures
There are two data structures included into the project design to help with the
assignment. See dataStructures/interfaces/ for the header information of these
structures.

* **Hashmap** - This is for anything that needs to retrieve a value based on a key.

* **List** - The list is design to have pushfront, pushback capabilities. For the most part,
you can stick with an array or even a QueueC (FIFO) which are more robust.

* **Routing Table** - Stores information about reachable destinations. Each entry contains a destination, next hop, hop count, validity flag, and route age. The routing table supports up to 32 entries.

* **Neighbor Table** = Stores discovered neighbors and tracks whether communication has been confirmed in both directions.

## General Libraries
/lib/interfaces

* **CommandHandler** - CommandHandler is what interfaces with TOSSIM. Commands are
sent to this function, and based on the parameters passed, an event is fired.
* **SimpleSend** - This is a wrapper of the lower level sender in TinyOS. The features
included is a basic queuing mechanism and some small delays to prevent collisions. Do
not change the delays. You can duplicate SimpleSendC to use a different AM type or
possibly rewire it.
* **Transport** - Project 3 implements reliable transport, connection management, sliding-window transmission, Go-Back-N retransmission, receiver flow control, and graceful connection termination.
* **NeighborDiscovery** - Identifies directly connected neighbors using a HELLO, ACK, and CONFIRM handshake.
* **RoutingTable** - Maintains routing information, including destinations, next hops, costs, and route validity.
* **Routing** - Provides routing information to the IP module for forwarding packets.
* **IP** - Sends and forwards packets using the routing table and handles ping requests and replies.

## Noise
/noise/

This is the "noise" of the network. A heavy noised network will cause issues with
packet loss.

* **no_noise.txt** - Provides a low-loss environment for testing basic routing functionality.
* **lossy_noise.txt** - Simulates network conditions where packets may be lost.

## Topography
/topo/

This folder contains a few example topographies of the network and how they are
connected to each other. Be sure to try additional networks when testing your code
since additional ones will be added when grading.

* **long_line.topo** - this topography is a line of 19 motes that have bidirectional
links.
* **example.topo** - A slightly more complex connection.
* **dv_line4.topo** - A four-node line topology.
* **dv_alternate.topo** - A five-node topology used to test alternative routes.
* **dv_poison.topo** - Used to test poison reverse.
* **dv_capacity.topo** - Used to test routing tables and advertisements containing more than six routes.
* **dv_loss.topo** - Used to test routing under packet-loss conditions.

Each line has three values, the source node, the destination node, and the gain.
For now you can keep the gain constant for all of your topographies. A line written
as ```1 2 -53``` denotes a one-way connection from 1 to 2. To make it bidirectional
include also ```2 1 -53```.

# Running Simulations
The following is an example of a simulation script.
```
from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("long_line.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);

    # After sending a ping, simulate a little to prevent collision.
    s.runTime(1);
    s.ping(1, 2, "Hello, World");
    s.runTime(1);

    s.ping(1, 10, "Hi!");
    s.runTime(1);

if __name__ == '__main__':
    main()
```

* **Test 1 - Line Topology**
```
python tests/test1_line.py
```
* **Test 2 — Alternate Path**
```
python tests/test2_alternate.py
```
* **Test 3 — Network Partition**
```
python tests/test3_partition.py
```
* **Test 4 — Poison Reverse**
```
python tests/test4_poison.py
```
* **Test 5 — Routing Table Capacity**
```
python tests/test5_capacity.py
```
* **Test 6 — Packet Loss and TTL**
```
python tests/test6_loss.py
python tests/test6_ttl.py
```

# Test Results
* **Test 1** - Successfully routed a ping from node 1 to node 4 across three hops and received a reply.
* **Test 2** - Successfully changed the route from cost 2 to cost 3 after a link failure and restored the shorter route when the link recovered.
* **Test 3** - Includes network partition and recovery testing.
* **Test 4** - Includes poison reverse testing with advertised route costs.
* **Test 5** - Includes routing table capacity and multi-packet advertisement testing.
* **Test 6** - The packet-loss simulation recorded packet-loss events, and all three ping requests successfully received replies. The TTL simulation sent a ping from node 1 to node 4 with TTL 2 on a three-hop path; node 2 forwarded it with TTL 1 and node 3 dropped it as expired, so no reply was returned and the packet did not circulate.

---

# Project 3 - Reliable Transport

## Overview

Project 3 extends the Project 2 Distance Vector routing implementation with a reliable, connection-oriented transport protocol.

The implementation supports:

* Three-way connection establishment.
* Reliable multi-hop data transfer.
* Sliding-window transmission and cumulative acknowledgments.
* Go-Back-N retransmission.
* Receiver-advertised flow control.
* Zero-window probing and window reopening.
* Multiple independent connection records.
* Graceful connection termination.
* Retry limits and failed connection cleanup.
* Incremental data generation and application consumption.

## Main Implementation Files

* `lib/modules/TransportP.nc` - Transport protocol implementation.
* `lib/modules/IPP.nc` - IP forwarding and intentional packet-loss testing.
* `lib/interfaces/MidTransport.nc` - Transport interface.
* `includes/transportPacket.h` - Packet format and transport constants.
* `Node.nc` - Application commands and transport integration.
* `TestSim.py` - Simulation command helpers.

## Build Instructions

Run from the project root inside the TinyOS Docker environment.

```bash
make clean
make micaz sim
```

The normal build does not enable intentional packet dropping.

## Simulation Commands

```python
cmdTestServer(serverAddress, listenPort=20)

cmdTestClient(clientAddress, serverAddress=4,
              srcPort=10, destPort=20, transferBytes=1024)

cmdClientClose(clientAddress, serverAddress,
               srcPort, destPort)

cmdPauseReceiver(receiverAddress, clientAddress,
                 clientPort, serverPort)

cmdResumeReceiver(receiverAddress, clientAddress,
                  clientPort, serverPort)
```

The server command starts a listener on the specified port.

The client command establishes a connection and transfers the
specified number of bytes. Byte k contains k modulo 256.

The close command requests graceful connection termination.

The pause and resume commands control application consumption
for a specific receiver connection to test flow control.

## Transport Packet Format

| Field | Size |
|---|---:|
| Source port | 1 byte |
| Destination port | 1 byte |
| Flags | 1 byte |
| Sequence number | 2 bytes |
| Acknowledgment number | 2 bytes |
| Advertised window | 1 byte |
| Data length | 1 byte |
| Total transport header | 9 bytes |
| Maximum application data | 11 bytes |

The network packet has an 8-byte network header and a 20-byte
payload. The 9-byte transport header leaves 11 bytes for
application data within the 28-byte packet.

## Transport Constants

| Parameter | Value |
|---|---:|
| Send buffer | 128 bytes |
| Receive buffer | 128 bytes |
| Maximum sender window | 44 bytes |
| Maximum connection records | 2 |
| Maximum sequence number | 65535 |
| Client initial sequence number | 100 |
| Server initial sequence number | 500 |
| Maximum supported transfer | 65033 bytes |
| Transport timer interval | 250 ms |
| Retransmission timeout | 2000 ms |
| Maximum retransmission retries | 8 |
| Connection linger interval | 20000 ms |
| FIN wait interval | 40000 ms |
| Maximum probe retries | 8 |

The implementation uses bounded buffers rather than allocating
an array equal to the requested transfer size.

## Test Environment

Most transport tests use `dv_line4.topo`, a four-node line
topology. Communication from node 1 to node 4 crosses three hops.

* `no_noise.txt` - Standard low-loss test environment.
* `lossy_noise.txt` - Noisy network test environment.

## Standard Transport Tests

Compile using the normal build before running these tests.

```bash
python tests/test3_midreview.py
python tests/test3_parameters.py
python tests/test3_close.py
python tests/test3_flow_control.py
python tests/test3_multiple.py
python tests/test3_unreachable.py
python tests/test3_noisy.py
```

## Intentional Packet-Loss Tests

The following helper rebuilds the simulator with a selected
packet-loss test flag.

```bash
build_loss() {
    make clean
    make micaz sim CFLAGS="-DTOSH_DATA_LENGTH=28 -D$1 -IdataStructures -IdataStructures/interfaces/ -IdataStructures/modules -Ilib/interfaces -Ilib/modules"
}
```

Run each scenario separately:

### DATA Packet Loss

```bash
build_loss TEST_DROP_TCP_DATA
python tests/test3_packet_loss.py
```

### SYN Loss

```bash
build_loss TEST_DROP_SYN
python tests/test3_close.py
```

### SYN-ACK Loss

```bash
build_loss TEST_DROP_SYN_ACK
python tests/test3_close.py
```

### Handshake ACK Loss

```bash
build_loss TEST_DROP_HANDSHAKE_ACK
python tests/test3_close.py
```

### DATA ACK Loss

```bash
build_loss TEST_DROP_DATA_ACK
python tests/test3_close.py
```

### Closing ACK Loss

```bash
build_loss TEST_DROP_FINAL_ACK
python tests/test3_close_loss.py
```

### Lost Window Reopening Update

```bash
build_loss TEST_DROP_WINDOW_REOPEN
python tests/test3_flow_control.py
```

After packet-loss testing, restore the normal build:

```bash
make clean
make micaz sim
```

## Project 3 Validation Results

| Scenario | Result |
|---|---|
| Normal transfer | PASS - 1024 bytes, zero mismatches |
| Configurable addresses and ports | PASS - 1024 bytes, zero mismatches |
| Graceful connection close | PASS - both endpoints released |
| DATA packet loss | PASS - Go-Back-N recovery |
| SYN loss | PASS - handshake recovered |
| SYN-ACK loss | PASS - handshake recovered |
| Handshake ACK loss | PASS - transfer completed |
| DATA ACK loss | PASS - transfer completed |
| Closing ACK loss | PASS - connection cleanup completed |
| Zero-window flow control | PASS - zero window and probes observed |
| Lost window reopening update | PASS - window recovered through probing |
| Multiple connections | PASS - two independent 1024-byte transfers |
| Unreachable server | PASS - retry limit and failure cleanup |
| Noisy network | PASS - 1024 bytes, zero mismatches |

All successful transfer scenarios delivered 1024 bytes without
data mismatches.

The multiple-connection test delivered 1024 bytes from each
client to the same server, using different connection records.
All four endpoint records were successfully released.

The unreachable-server test attempted to connect to a node
without an active listener. After eight SYN retransmissions,
the client reported failure and released its connection record.
No application bytes were accepted.

The noisy-network test recorded 12 Go-Back-N segment
retransmissions and successfully delivered all 1024 bytes.
Both endpoints were released without failure.

## Example Validation Output

Successful transfer:

```text
APP_CONSUMED total=1024 expected=1024 mismatches=0
```

Successful client cleanup:

```text
CONNECTION_RELEASED state=8 failed=0 accepted=1024 acknowledged=1024 received=0 unread=0
```

Successful server cleanup:

```text
CONNECTION_RELEASED state=8 failed=0 accepted=0 acknowledged=0 received=1024 unread=0
```

Expected failure when no server is listening:

```text
CONNECTION_FAILED peer=4 retry limit reached
APP_TRANSFER_FAILED peer=4 accepted=0 expected=1024
CONNECTION_RELEASED state=9 failed=1 accepted=0 acknowledged=0 received=0 unread=0
```

## Limitations

The implementation uses fixed-size buffers, a maximum of two
connection records per node, and a bounded 16-bit sequence
number range. It uses a fixed sender window rather than
dynamic congestion-window adjustment.
