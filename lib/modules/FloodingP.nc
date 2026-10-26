#include "../../includes/packet.h"
#include "../../includes/channels.h"

module FloodingP{
    provides interface Flooding;
    uses interface SimpleSend as Sender;
}

implementation{ 
    enum{
        FLOOD_HISTORY_SIZE = 32
    };

    typedef struct{
        uint16_t src;
        uint16_t seq;
    } floodRecord;

    floodRecord history[FLOOD_HISTORY_SIZE];

    uint8_t historySize = 0;
    uint8_t historyIndex = 0;

    uint16_t sequenceNumber = 0;

    bool hasSeen(uint16_t src, uint16_t seq){
        uint8_t i;

        for(i = 0; i < historySize; i++){
            if(history[i].src == src && history[i].seq == seq){
                return TRUE;
            }
        }
        return FALSE;
    }

    void rememberPacket(uint16_t src, uint16_t seq){
        history[historyIndex].src = src;
        history[historyIndex].seq = seq;

        historyIndex++;

        if(historyIndex >= FLOOD_HISTORY_SIZE){
            historyIndex = 0;
        }

        if(historySize < FLOOD_HISTORY_SIZE){
            historySize++;
        }
    }

    command void Flooding.send(pack msg){

        msg.src = TOS_NODE_ID;
        msg.seq = sequenceNumber;
        msg.TTL = MAX_TTL;

        sequenceNumber++;

        rememberPacket(msg.src, msg.seq);

        dbg(FLOODING_CHANNEL, "Node %d flooding packet: src=%d dest=%d seq=%d TTL=%d\n", TOS_NODE_ID, msg.src, msg.dest, msg.seq, msg.TTL);

        call Sender.send(msg, AM_BROADCAST_ADDR);
    }

    command void Flooding.receive(pack msg){

        dbg(FLOODING_CHANNEL, "Node %d received flooded packet: src=%d dest=%d seq=%d TTL=%d\n", TOS_NODE_ID, msg.src, msg.dest, msg.seq, msg.TTL);

        if(hasSeen(msg.src, msg.seq)){

            dbg(FLOODING_CHANNEL, "Node %d dropping duplicate packet src=%d seq=%d\n", TOS_NODE_ID, msg.src, msg.seq);
            return;
        }

        rememberPacket(msg.src, msg.seq);

        if(msg.dest == TOS_NODE_ID){

            if(msg.protocol == PROTOCOL_PING){

                pack reply;

                dbg(FLOODING_CHANNEL, "Node %d received PING from node %d: %s\n", TOS_NODE_ID, msg.src, msg.payload);
                reply.src = TOS_NODE_ID;
                reply.dest = msg.src;
                reply.seq = sequenceNumber;
                sequenceNumber++;

                reply.TTL = MAX_TTL;

                reply.protocol = PROTOCOL_PINGREPLY;

                memcpy(reply.payload, msg.payload, PACKET_MAX_PAYLOAD_SIZE);
                rememberPacket(reply.src, reply.seq);


                dbg(FLOODING_CHANNEL, "Node %d sending PING REPLY to node %d seq=%d\n", TOS_NODE_ID, reply.dest, reply.seq);
                call Sender.send(reply, AM_BROADCAST_ADDR);
            }

            else if(msg.protocol == PROTOCOL_PINGREPLY){
                dbg(FLOODING_CHANNEL, "Node %d received PING REPLY from node %d: %s\n", TOS_NODE_ID, msg.src, msg.payload);
            }
            return;
        }

        if(msg.TTL == 0){
            dbg(FLOODING_CHANNEL, "Node %d dropping packet because TTL expired\n",TOS_NODE_ID);
            return;
        }

        msg.TTL--;

        dbg(FLOODING_CHANNEL, "Node %d rebroadcasting packet src=%d dest=%d seq=%d TTL=%d\n", TOS_NODE_ID, msg.src, msg.dest, msg.seq, msg.TTL);
        call Sender.send(msg, AM_BROADCAST_ADDR);
    }
}