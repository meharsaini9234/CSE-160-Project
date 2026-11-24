#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/channels.h"
#include "../../includes/transportPacket.h"


module IPP{
    provides interface IP;
    uses interface Routing;
    uses interface SimpleSend as Sender;
}

implementation{
    uint8_t testDataDropped = FALSE;
    void forward(pack msg){
        uint16_t nextHop;
        uint8_t cost;
        error_t result;

        #ifdef TEST_DROP_TCP_DATA
    // Drop the second DATA segment from Node 1 to Node 4
    if(TOS_NODE_ID == 1 &&
       !testDataDropped &&
       msg.protocol == PROTOCOL_TCP &&
       msg.src == 1 &&
       msg.dest == 4 &&
       msg.payload[2] == TCP_DATA &&
       msg.payload[3] == 0 &&
       msg.payload[4] == 112){

        testDataDropped = TRUE;

        dbg(TRANSPORT_CHANNEL,
            "node=%u TEST_DROP_DATA seq=112\n",
            TOS_NODE_ID);

        return;
    }
#endif

        if(!call Routing.getRoute(msg.dest, &nextHop, &cost) || cost >= 16 || nextHop == AM_BROADCAST_ADDR || nextHop == TOS_NODE_ID){
            dbg(ROUTING_CHANNEL, "Node %u dropping packet src=%u dest=%u seq=%u: no valid route\n", TOS_NODE_ID, msg.src, msg.dest, msg.seq);
            return;
        }

        result = call Sender.send(msg, nextHop);

        if(result == SUCCESS){
            dbg(ROUTING_CHANNEL, "Node %u Routing Packet - src: %u, dest: %u, seq: %u, next hop: %u, cost: %u\n", TOS_NODE_ID, msg.src, msg.dest, msg.seq, nextHop, cost);
        }
        else{
            dbg(ROUTING_CHANNEL, "Node %u dropping packet src=%u dest=%u seq=%u: send error=%u\n", TOS_NODE_ID, msg.src, msg.dest, msg.seq, result);
        }
    }

    void deliver(pack msg){
        if (msg.TTL == 0) {
            dbg(ROUTING_CHANNEL, "Node %u dropping packet: TTL=0\n", TOS_NODE_ID);
            return;
        }

        if(msg.protocol == PROTOCOL_PING){
            pack reply;
            uint8_t i;

            dbg(ROUTING_CHANNEL, "Node %u received routed PING from %u seq=%u\n", TOS_NODE_ID, msg.src, msg.seq);

            reply.src = TOS_NODE_ID;
            reply.dest = msg.src;
            reply.seq = msg.seq;
            reply.TTL = MAX_TTL;
            reply.protocol = PROTOCOL_PINGREPLY;

            for(i = 0; i < PACKET_MAX_PAYLOAD_SIZE; i++){
                reply.payload[i] = msg.payload[i];
            }

            if(reply.dest == TOS_NODE_ID){
                signal IP.delivered(reply);
            }
            else{
                forward(reply);
            }
        }
        else if(msg.protocol == PROTOCOL_PINGREPLY){
            dbg(ROUTING_CHANNEL, "Node %u received routed PING REPLY from %u seq=%u\n", TOS_NODE_ID, msg.src, msg.seq);
        }

        signal IP.delivered(msg);
    }

    command void IP.send(pack msg){
        if(msg.src != TOS_NODE_ID || msg.TTL == 0){
            dbg(ROUTING_CHANNEL, "Node %u refusing invalid IP packet\n", TOS_NODE_ID);
            return;
        }

        if(msg.dest == TOS_NODE_ID){
            deliver(msg);
            return;
        }

        forward(msg);
    }

    command void IP.receive(pack msg){

        if(msg.TTL > 0 && msg.dest == TOS_NODE_ID){
            deliver(msg);
            return;
        }

        if(msg.TTL <= 1){
            dbg(ROUTING_CHANNEL, "Node %u dropping packet src=%u dest=%u seq=%u: TTL expired\n", TOS_NODE_ID, msg.src, msg.dest, msg.seq);
            return;
        }

        msg.TTL--;
        forward(msg);
    }
}
