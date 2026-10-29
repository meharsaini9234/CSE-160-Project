
#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include <string.h>

module NeighborDiscoveryP{
    provides interface NeighborDiscovery;

    uses interface Timer<TMilli> as NeighborTimer;
    uses interface SimpleSend as Sender;
}

implementation{
    enum{
        MAX_NEIGHBORS = 20,
        NEIGHBOR_TIMEOUT = 3,
        NEIGHBOR_PERIOD = 3000,

        ND_HELLO = 'H',
        ND_ACK = 'A',
        ND_CONFIRM = 'C'
    };

    uint16_t neighbors[MAX_NEIGHBORS];
    uint8_t neighborAge[MAX_NEIGHBORS];

    uint8_t confirmationAge[MAX_NEIGHBORS];
    uint16_t pendingSequence[MAX_NEIGHBORS];
    bool pendingConfirm[MAX_NEIGHBORS];

    uint8_t neighborCount = 0;
    uint16_t sequenceNumber = 0;

    uint16_t lastHelloSequence = 0;
    bool helloSent = FALSE;

    int8_t findNeighbor(uint16_t node){
        uint8_t i;

        for(i = 0; i < neighborCount; i++){
            if(neighbors[i] == node){
                return i;
            }
        }
        return -1;
    }

    int8_t updateNeighbor(uint16_t node){
        int8_t index;

        index = findNeighbor(node);

        if(index >= 0){
            neighborAge[index] = 0;
            return index;
        }

        if(neighborCount >= MAX_NEIGHBORS){
            dbg(NEIGHBOR_CHANNEL, "Node %u neighbor table full\n", TOS_NODE_ID);
            return -1;
        }

        index = neighborCount;
        neighbors[index] = node;
        neighborAge[index] = 0;

        confirmationAge[index] = NEIGHBOR_TIMEOUT;
        pendingConfirm[index] = FALSE;
        pendingSequence[index] = 0;

        neighborCount++;

        dbg(NEIGHBOR_CHANNEL, "Node %u discovered possible neighbor %u\n", TOS_NODE_ID, node);

        return index;
    }

    void ageNeighbors(){
        uint8_t i;
        uint8_t j;

        i = 0;

        while(i < neighborCount){
            if(neighborAge[i] < NEIGHBOR_TIMEOUT){
                neighborAge[i]++;
            }

            if(confirmationAge[i] < NEIGHBOR_TIMEOUT){
                confirmationAge[i]++;
            }

            if(neighborAge[i] >= NEIGHBOR_TIMEOUT){
                dbg(NEIGHBOR_CHANNEL, "Node %u removing neighbor %u\n", TOS_NODE_ID, neighbors[i]);

                for(j = i; j < neighborCount - 1; j++){
                    neighbors[j] = neighbors[j + 1];
                    neighborAge[j] = neighborAge[j + 1];
                    confirmationAge[j] = confirmationAge[j + 1];
                    pendingSequence[j] = pendingSequence[j + 1];
                    pendingConfirm[j] = pendingConfirm[j + 1];
                }

                neighborCount--;
            }
            else{
                i++;
            }
        }
    }

    error_t sendND(uint16_t destination, uint8_t type, uint16_t seq){
        pack msg;

        msg.src = TOS_NODE_ID;
        msg.dest = destination;
        msg.seq = seq;
        msg.TTL = 1;
        msg.protocol = PROTOCOL_CMD;

        memset(msg.payload, 0, PACKET_MAX_PAYLOAD_SIZE);

        msg.payload[0] = 'N';
        msg.payload[1] = 'D';
        msg.payload[2] = type;

        return call Sender.send(msg, destination);
    }

    void sendDiscovery(){
        error_t result;
        uint16_t seq;

        seq = sequenceNumber++;

        result = sendND(AM_BROADCAST_ADDR, ND_HELLO, seq);

        if(result == SUCCESS){
            lastHelloSequence = seq;
            helloSent = TRUE;

            dbg(NEIGHBOR_CHANNEL, "Node %u broadcasting HELLO seq=%u\n", TOS_NODE_ID, seq);
        }
        else{
            dbg(NEIGHBOR_CHANNEL, "Node %u failed to queue HELLO\n", TOS_NODE_ID);
        }
    }

    command void NeighborDiscovery.start(){
        dbg(NEIGHBOR_CHANNEL, "Node %u starting neighbor discovery\n", TOS_NODE_ID);
        call NeighborTimer.startPeriodic(NEIGHBOR_PERIOD);
    }

    event void NeighborTimer.fired(){
        ageNeighbors();
        sendDiscovery();
    }

    command void NeighborDiscovery.receive(pack msg){
        int8_t index;
        error_t result;
        uint8_t type;

        if(msg.src == TOS_NODE_ID){
            return;
        }

        if(msg.protocol != PROTOCOL_CMD){
            return;
        }

        if(msg.payload[0] != 'N' || msg.payload[1] != 'D'){
            return;
        }

        if(msg.TTL == 0){
            return;
        }

        type = msg.payload[2];

        //receive HELLO
        if(type == ND_HELLO){
            if(msg.dest != AM_BROADCAST_ADDR){
                return;
            }

            index = updateNeighbor(msg.src);

            if(index < 0){
                return;
            }

            dbg(NEIGHBOR_CHANNEL, "Node %u received HELLO from %u\n", TOS_NODE_ID, msg.src);

            result = sendND(msg.src, ND_ACK, msg.seq);

            if(result == SUCCESS){
                pendingSequence[index] = msg.seq;
                pendingConfirm[index] = TRUE;

                dbg(NEIGHBOR_CHANNEL, "Node %u sent ACK to %u\n", TOS_NODE_ID, msg.src);
            }
        }

        //receive ACK
        else if(type == ND_ACK){
            if(msg.dest != TOS_NODE_ID){
                return;
            }

            if(!helloSent || msg.seq != lastHelloSequence){
                return;
            }

            index = updateNeighbor(msg.src);

            if(index < 0){
                return;
            }

            confirmationAge[index] = 0;

            dbg(NEIGHBOR_CHANNEL, "Node %u confirmed bidirectional neighbor %u\n", TOS_NODE_ID, msg.src);

            result = sendND(msg.src, ND_CONFIRM, msg.seq);

            if(result != SUCCESS){
                dbg(NEIGHBOR_CHANNEL, "Node %u failed to queue CONFIRM to %u\n", TOS_NODE_ID, msg.src);
            }
        }

        //receive CONFIRM
        else if(type == ND_CONFIRM){
            if(msg.dest != TOS_NODE_ID){
                return;
            }

            index = findNeighbor(msg.src);

            if(index < 0){
                return;
            }

            if(!pendingConfirm[index] || pendingSequence[index] != msg.seq){
                return;
            }

            pendingConfirm[index] = FALSE;
            neighborAge[index] = 0;
            confirmationAge[index] = 0;

            dbg(NEIGHBOR_CHANNEL, "Node %u confirmed bidirectional neighbor %u\n", TOS_NODE_ID, msg.src);
        }
    }

    command bool NeighborDiscovery.isConfirmed(uint16_t neighbor){
        int8_t index;

        index = findNeighbor(neighbor);

        if(index < 0){
            return FALSE;
        }

        return neighborAge[index] < NEIGHBOR_TIMEOUT && confirmationAge[index] < NEIGHBOR_TIMEOUT;
    }

    command uint8_t NeighborDiscovery.getNeighborCount(){
        uint8_t i;
        uint8_t count = 0;

        for(i = 0; i < neighborCount; i++){
            if(neighborAge[i] < NEIGHBOR_TIMEOUT && confirmationAge[i] < NEIGHBOR_TIMEOUT){
                count++;
            }
        }

        return count;
    }

    command uint16_t NeighborDiscovery.getNeighbor(uint8_t index){
        uint8_t i;
        uint8_t confirmedIndex = 0;

        for(i = 0; i < neighborCount; i++){
            if(neighborAge[i] < NEIGHBOR_TIMEOUT && confirmationAge[i] < NEIGHBOR_TIMEOUT){
                if(confirmedIndex == index){
                    return neighbors[i];
                }
                confirmedIndex++;
            }
        }

        return 0;
    }

    command void NeighborDiscovery.print(){
        uint8_t i;

        dbg(NEIGHBOR_CHANNEL, "Node %u confirmed neighbors:\n", TOS_NODE_ID);

        for(i = 0; i < neighborCount; i++){
            if(neighborAge[i] < NEIGHBOR_TIMEOUT && confirmationAge[i] < NEIGHBOR_TIMEOUT){
                dbg(NEIGHBOR_CHANNEL, "Neighbor: %u\n", neighbors[i]);
            }
        }
    }
   
}
