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
* **Transport** - There is only the interface of Transport included. The actual
implementation of the Transport layer is left to the student as an exercise. For
CSE160 this will be Project 3 so don't worry about it now.
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
* **Test 6** - The packet-loss simulation recorded packet-loss events, and all three ping requests successfully received replies. The TTL simulation successfully forwarded a ping across three hops.