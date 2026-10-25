#include "../../includes/packet.h"
#include "../../includes/channels.h"

module NeighborDiscoveryP{
    provides interface NeighborDiscovery;

    uses interface Timer<TMilli> as NeighborTimer;
    uses interface SimpleSend as Sender;
}

implementation{
    enum{
        MAX_NEIGHBORS = 20,
        NEIGHBOR_TIMEOUT = 3,
        NEIGHBOR_PERIOD = 3000
    };

    uint16_t neighbors[MAX_NEIGHBORS];
    uint8_t neighborAge[MAX_NEIGHBORS];

    uint8_t neighborCount = 0;
    uint16_t sequenceNumber = 0;

    int8_t findNeighbor(uint16_t node){
        uint8_t i;
        for(i = 0; i < neighborCount; i++){
            if(neighbors[i] == node){
                return i;
            }
        }
        return -1;
    }

    void updateNeighbor(uint16_t node){
        int8_t index;

        index = findNeighbor(node);

        if(index >= 0){
            neighborAge[index] = 0;
            return;
        }

        if(neighborCount < MAX_NEIGHBORS){
            neighbors[neighborCount] = node;
            neighborAge[neighborCount] = 0;
            neighborCount++;

            dbg(NEIGHBOR_CHANNEL, "Node %d discovered neighbor %d\n", TOS_NODE_ID, node);
        }
    }

    void ageNeighbors(){
        uint8_t i;
        uint8_t j;

        i = 0;

        while(i < neighborCount){
            neighborAge[i]++;
            if(neighborAge[i] >= NEIGHBOR_TIMEOUT) {
                dbg(NEIGHBOR_CHANNEL, "Node %d removing neighbor %d\n", TOS_NODE_ID, neighbors[i]);

                for(j = i; j < neighborCount - 1; j++){
                    neighbors[j] = neighbors[j + 1];
                    neighborAge[j] = neighborAge[j + 1];
                }
                neighborCount--;
            }
            else{
                i++;
            }
        }
    }

    void sendDiscovery(){

        pack discovery;

        discovery.src = TOS_NODE_ID;
        discovery.dest = AM_BROADCAST_ADDR;

        discovery.seq = sequenceNumber;
        sequenceNumber++;

        discovery.TTL = 1;

        discovery.protocol = PROTOCOL_CMD;

        memset(discovery.payload, 0, PACKET_MAX_PAYLOAD_SIZE);

        discovery.payload[0] = 'N';
        discovery.payload[1] = 'D';

        dbg(NEIGHBOR_CHANNEL, "Node %d broadcasting neighbor discovery\n", TOS_NODE_ID);
        call Sender.send(discovery, AM_BROADCAST_ADDR);
    }

    command void NeighborDiscovery.start(){
        dbg(NEIGHBOR_CHANNEL, "Node %d starting neighbor discovery\n", TOS_NODE_ID);
        call NeighborTimer.startPeriodic(NEIGHBOR_PERIOD);
    }

    event void NeighborTimer.fired(){
        ageNeighbors();
        sendDiscovery();
    }

    command void NeighborDiscovery.receive(pack msg){
        if(msg.src == TOS_NODE_ID){
            return;
        }

        if(msg.protocol != PROTOCOL_CMD){
            return;
        }

        if(msg.payload[0] != 'N' || msg.payload[1] != 'D'){
            return;
        }

        updateNeighbor(msg.src);
        dbg(NEIGHBOR_CHANNEL, "Node %d heard neighbor %d\n", TOS_NODE_ID, msg.src);
    }

    command void NeighborDiscovery.print(){
        uint8_t i;

        dbg(NEIGHBOR_CHANNEL, "Node %d neighbors:\n", TOS_NODE_ID);
        for(i = 0; i < neighborCount; i++){
            dbg(NEIGHBOR_CHANNEL, "Neighbor: %d\n", neighbors[i]);
        }
    }
    command uint8_t NeighborDiscovery.getNeighborCount(){
        return neighborCount; //return how many neighbors currently stored
    }

    command uint16_t NeighborDiscovery.getNeighbor(uint8_t index){
        //make sure the index exists in neighbor array
        if(index >= neighborCount){
            return 0;
        }

        //return node ID at this position 
        return neighbors[index];
    }
}