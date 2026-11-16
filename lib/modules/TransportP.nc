#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/transportPacket.h"
#include "../../includes/channels.h"
#include <Timer.h>
#include <string.h>

module TransportP{
    provides interface MidTransport;

    uses interface IP;
    uses interface Timer<TMilli> as RetryTimer;
}

implementation{

    enum{
        ST_FREE = 0,
        ST_SYN_SENT,
        ST_SYN_RCVD,
        ST_ESTABLISHED,
        ST_FIN_WAIT_1,
        ST_FIN_WAIT_2,
        ST_CLOSE_WAIT,
        ST_LAST_ACK,
        ST_LINGER
    };

    typedef struct connection{
        uint8_t used;
        uint8_t state;

        uint16_t remoteAddress;
        uint8_t localPort;
        uint8_t remotePort;

        uint16_t sndUna;
        uint16_t sndNext;
        uint16_t rcvNext;

        uint16_t dataOffset;
        uint16_t receivedTotal;

        uint8_t recvBuffer[TCP_BUFFER_SIZE];
        uint8_t recvLength;

        uint8_t waiting;
        uint8_t pendingFlags;
        uint16_t pendingSeq;
        uint16_t pendingAck;
        uint8_t pendingLength;
        uint8_t pendingData[TCP_MAX_DATA];

        uint8_t retries;
        uint8_t elapsed;
        uint8_t lingerTicks;
    }connection_t;

    connection_t connections[TCP_MAX_CONNECTIONS];

    uint8_t listening = 0;
    uint8_t listeningPort = 0;

    uint8_t timerStarted = 0;
    uint16_t networkPacketId = 0;

    task void consumeTask();
    void transmit(connection_t* c, uint8_t flags, uint16_t seq, uint16_t ack, uint8_t* data, uint8_t length, uint8_t remember);
    void sendAck(connection_t* c);
    void sendNextData(connection_t* c);
    void sendFin(connection_t* c);
    void handleSegment(pack* packet, tcp_segment_t* seg);

    void startTimer(){
        if(!timerStarted){
            timerStarted = TRUE;
            call RetryTimer.startPeriodic(TCP_TIMER_MS);
        }
    }

    void clearConnection(connection_t* c){
        memset(c, 0, sizeof(connection_t));
        c->state = ST_FREE;
    }

    connection_t* allocateConnection(){
        uint8_t i;

        for(i = 0; i < TCP_MAX_CONNECTIONS; i++){
            if(!connections[i].used){
                clearConnection(&connections[i]);
                connections[i].used = TRUE;
                return &connections[i];
            }
        }

        return NULL;
    }

    connection_t* findConnection(uint16_t remote, uint8_t localPort, uint8_t remotePort){
        uint8_t i;
        for(i = 0; i < TCP_MAX_CONNECTIONS; i++){
            connection_t* c = &connections[i];
            if(c->used && c->remoteAddress == remote && c->localPort == localPort && c->remotePort == remotePort){
                return c;
            }
        }
        return NULL;
    }

    void transmit(connection_t* c, uint8_t flags, uint16_t seq, uint16_t ack, uint8_t* data, uint8_t length,uint8_t remember){
        pack packet;
        tcp_segment_t seg;
        uint8_t i;

        if(length > TCP_MAX_DATA){
            return;
        }

        memset(&packet, 0, sizeof(packet));
        memset(&seg, 0, sizeof(seg));

        packet.src = TOS_NODE_ID;
        packet.dest = c->remoteAddress;
        packet.TTL = MAX_TTL;
        packet.protocol = PROTOCOL_TCP;

        packet.seq = networkPacketId++;

        seg.srcPort = c->localPort;
        seg.destPort = c->remotePort;
        seg.flags = flags;
        seg.seq = seq;
        seg.ack = ack;
        seg.window = TCP_BUFFER_SIZE - c->recvLength;
        seg.length = length;

        for(i = 0; i < length; i++){
            seg.data[i] = data[i];
        }

        tcpEncode(&packet, &seg);

        dbg(TRANSPORT_CHANNEL, "t=%lu node=%u TCP_TX peer=%u state=%u flags=%u seq=%u ack=%u len=%u wnd=%u\n", (unsigned long) call RetryTimer.getNow(), TOS_NODE_ID, c->remoteAddress, c->state, flags, seq, ack, length, seg.window);

        call IP.send(packet);

        if(remember){
            c->waiting = TRUE;
            c->pendingFlags = flags;
            c->pendingSeq = seq;
            c->pendingAck = ack;
            c->pendingLength = length;

            for(i = 0; i < length; i++){
                c->pendingData[i] = data[i];
            }

            c->retries = 0;
            c->elapsed = 0;
        }
    }

    void resendPending(connection_t* c){
        if(!c->waiting){
            return;
        }

        dbg(TRANSPORT_CHANNEL, "t=%lu node=%u RETRANSMIT peer=%u flags=%u seq=%u retry=%u\n", (unsigned long) call RetryTimer.getNow(), TOS_NODE_ID,c->remoteAddress, c->pendingFlags, c->pendingSeq, c->retries);

        transmit(c, c->pendingFlags, c->pendingSeq, c->pendingAck, c->pendingData, c->pendingLength, FALSE);
    }

    void sendAck(connection_t* c){
        transmit(c, TCP_ACK, c->sndNext, c->rcvNext, NULL, 0, FALSE);
    }

    void sendNextData(connection_t* c){
        uint8_t buffer[TCP_MAX_DATA];
        uint8_t length;
        uint8_t i;
        uint16_t remaining;

        if(c->state != ST_ESTABLISHED || c->waiting || c->localPort != 10){
            return;
        }

        if(c->dataOffset >= TCP_TEST_BYTES){
            sendFin(c);
            return;
        }
        remaining = TCP_TEST_BYTES - c->dataOffset;

        length = remaining > TCP_MAX_DATA ? TCP_MAX_DATA : remaining;

        for(i = 0; i < length; i++){
            buffer[i] = (uint8_t)((c->dataOffset + i) % 256);
        }

        transmit(c, TCP_DATA, c->sndNext, c->rcvNext, buffer, length, TRUE);
        c->sndNext += length;
    }

    void sendFin(connection_t* c){
        uint16_t seq;

        if(c->waiting){
            return;
        }

        seq = c->sndNext;

        if(c->state == ST_ESTABLISHED){
            c->state = ST_FIN_WAIT_1;
        }
        else if(c->state == ST_CLOSE_WAIT){
            c->state = ST_LAST_ACK;
        }
        else{
            return;
        }

        transmit(c, TCP_FIN, seq, c->rcvNext, NULL, 0, TRUE);

        c->sndNext++;

        dbg(TRANSPORT_CHANNEL, "node=%u FIN_SENT peer=%u state=%u\n", TOS_NODE_ID, c->remoteAddress, c->state);
    }

    void enterLinger(connection_t* c){
        c->state = ST_LINGER;
        c->waiting = FALSE;
        c->lingerTicks = 0;
        dbg(TRANSPORT_CHANNEL, "node=%u CONNECTION_CLOSING peer=%u\n", TOS_NODE_ID, c->remoteAddress);
    }

    command void MidTransport.listen(uint8_t port){
        listening = TRUE;
        listeningPort = port;

        startTimer();

        dbg(TRANSPORT_CHANNEL, "node=%u LISTEN port=%u\n", TOS_NODE_ID, port);
    }

    command void MidTransport.connect(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort){
        connection_t* c;

        startTimer();

        if(findConnection(remoteAddress, localPort, remotePort) != NULL){
            return;
        }

        c = allocateConnection();

        if(c == NULL){
            dbg(TRANSPORT_CHANNEL, "node=%u CONNECT_FAILED no sockets\n", TOS_NODE_ID);
            return;
        }

        c->remoteAddress = remoteAddress;
        c->localPort = localPort;
        c->remotePort = remotePort;
        c->state = ST_SYN_SENT;
        c->sndUna = 100;
        c->sndNext = 101;

        dbg(TRANSPORT_CHANNEL, "node=%u SYN_SENT peer=%u\n", TOS_NODE_ID, remoteAddress);
        transmit(c, TCP_SYN, 100, 0, NULL, 0, TRUE);
    }

    void handleSegment(pack* packet, tcp_segment_t* seg){
        connection_t* c;
        uint8_t i;

        c = findConnection(packet->src, seg->destPort, seg->srcPort);

        if(c == NULL){
            if(seg->flags != TCP_SYN || !listening || seg->destPort != listeningPort || seg->length != 0){
                return;
            }

            c = allocateConnection();

            if(c == NULL){
                return;
            }

            c->remoteAddress = packet->src;
            c->localPort = seg->destPort;
            c->remotePort = seg->srcPort;
            c->state = ST_SYN_RCVD;
            c->rcvNext = seg->seq + 1;
            c->sndUna = 500;
            c->sndNext = 501;

            dbg(TRANSPORT_CHANNEL, "node=%u SYN_RECEIVED peer=%u\n", TOS_NODE_ID, packet->src);

            transmit(c, TCP_SYN | TCP_ACK, 500, c->rcvNext, NULL, 0, TRUE);
            return;
        }

        if(seg->flags == (TCP_SYN | TCP_ACK)){
            if(c->state == ST_SYN_SENT && seg->ack == c->sndNext && seg->length == 0){
                c->rcvNext = seg->seq + 1;
                c->sndUna = seg->ack;
                c->waiting = FALSE;
                c->state = ST_ESTABLISHED;

                dbg(TRANSPORT_CHANNEL, "node=%u ESTABLISHED client peer=%u\n", TOS_NODE_ID, packet->src);

                sendAck(c);
                sendNextData(c);
            }
            else if(c->state == ST_ESTABLISHED && seg->seq + 1 == c->rcvNext && seg->ack == c->sndUna){
                sendAck(c);
            }

            return;
        }

        if(seg->flags == TCP_SYN){
            if (c->state == ST_SYN_RCVD && seg->seq + 1 == c->rcvNext){
                resendPending(c);
            }

            return;
        }

        if(c->state == ST_SYN_RCVD){
            if (seg->flags == TCP_ACK && seg->ack == c->sndNext && seg->length == 0){
                c->sndUna = seg->ack;
                c->waiting = FALSE;
                c->state = ST_ESTABLISHED;
                dbg(TRANSPORT_CHANNEL, "node=%u ESTABLISHED server peer=%u\n", TOS_NODE_ID, packet->src);
            }
            return;
        }

        if(seg->flags == TCP_DATA){
            if(c->state != ST_ESTABLISHED && c->state != ST_CLOSE_WAIT){
                return;
            }

            if(seg->length == 0){
                return;
            }

            if(seg->seq == c->rcvNext && seg->length <= TCP_BUFFER_SIZE - c->recvLength){
                for (i = 0; i < seg->length; i++){
                    c->recvBuffer[c->recvLength + i] = seg->data[i];
                }
                c->recvLength += seg->length;
                c->rcvNext += seg->length;

                dbg(TRANSPORT_CHANNEL, "node=%u DATA_RECEIVED peer=%u seq=%u len=%u nextExpected=%u\n", TOS_NODE_ID, packet->src, seg->seq, seg->length, c->rcvNext);
                post consumeTask();
            }
            else{
                dbg(TRANSPORT_CHANNEL, "node=%u DUPLICATE_OR_OUT_OF_ORDER seq=%u expected=%u\n", TOS_NODE_ID, seg->seq, c->rcvNext);
            }
            sendAck(c);
            return;
        }

        if(seg->flags == TCP_ACK){
            if(!c->waiting){
                return;
            }

            if(seg->ack != c->sndNext || seg->ack <= c->sndUna){
                return;
            }

            if(c->pendingFlags == TCP_DATA && c->state == ST_ESTABLISHED){
                c->sndUna = seg->ack;
                c->dataOffset += c->pendingLength;
                c->waiting = FALSE;

                dbg(TRANSPORT_CHANNEL, "node=%u DATA_ACKNOWLEDGED bytes=%u ack=%u\n", TOS_NODE_ID, c->dataOffset, seg->ack);
                sendNextData(c);
            }
            else if(c->pendingFlags == TCP_FIN){
                c->sndUna = seg->ack;
                c->waiting = FALSE;

                if(c->state == ST_FIN_WAIT_1){
                    c->state = ST_FIN_WAIT_2;
                    dbg(TRANSPORT_CHANNEL, "node=%u FIN_WAIT_2 peer=%u\n", TOS_NODE_ID, packet->src);
                }
                else if (c->state == ST_LAST_ACK) {
                    enterLinger(c);
                }
            }

            return;
        }

        if(seg->flags == TCP_FIN){
            if(seg->seq == c->rcvNext){
                c->rcvNext++;
                sendAck(c);
                
                dbg(TRANSPORT_CHANNEL, "node=%u FIN_RECEIVED peer=%u\n", TOS_NODE_ID, packet->src);

                if(c->state == ST_ESTABLISHED){
                    c->state = ST_CLOSE_WAIT;
                    sendFin(c);
                }
                else if(c->state == ST_FIN_WAIT_2){
                    enterLinger(c);
                }
            }
            else{
                sendAck(c);
            }
            return;
        }
    }

    event void IP.delivered(pack packet){
        tcp_segment_t seg;

        if(packet.protocol != PROTOCOL_TCP){
            return;
        }

        if(!tcpDecode(&packet, &seg)){
            dbg(TRANSPORT_CHANNEL, "node=%u MALFORMED_TCP_PACKET\n", TOS_NODE_ID);
            return;
        }

        dbg(TRANSPORT_CHANNEL, "node=%u TCP_RX peer=%u flags=%u seq=%u ack=%u len=%u\n", TOS_NODE_ID, packet.src, seg.flags, seg.seq, seg.ack, seg.length);
        handleSegment(&packet, &seg);
    }


    task void consumeTask(){
        uint8_t i;
        uint8_t j;

        for(i = 0; i < TCP_MAX_CONNECTIONS; i++){
            connection_t* c = &connections[i];

            if(!c->used || c->recvLength == 0){
                continue;
            }

            for(j = 0; j < c->recvLength; j++){
                uint8_t expected =(uint8_t)(c->receivedTotal % 256);

                if (c->recvBuffer[j] != expected) {
                    dbg(TRANSPORT_CHANNEL, "node=%u DATA_MISMATCH offset=%u got=%u expected=%u\n", TOS_NODE_ID, c->receivedTotal, c->recvBuffer[j], expected);
                }
                c->receivedTotal++;
            }

            dbg(TRANSPORT_CHANNEL, "node=%u APP_CONSUMED total=%u\n", TOS_NODE_ID, c->receivedTotal);

            c->recvLength = 0;

            if(c->state == ST_ESTABLISHED){
                sendAck(c);
            }
        }
    }

    event void RetryTimer.fired(){
        uint8_t i;

        for(i = 0; i < TCP_MAX_CONNECTIONS; i++){
            connection_t* c = &connections[i];
            if(!c->used){
                continue;
            }

            if(c->state == ST_LINGER){
                c->lingerTicks++;
                if (c->lingerTicks >= TCP_LINGER_TICKS && c->recvLength == 0){
                    dbg(TRANSPORT_CHANNEL, "node=%u CONNECTION_CLOSED peer=%u\n",TOS_NODE_ID, c->remoteAddress);
                    clearConnection(c);
                }
                continue;
            }

            if(!c->waiting){
                continue;
            }

            c->elapsed++;

            if(c->elapsed < TCP_RTO_TICKS){
                continue;
            }

            c->elapsed = 0;

            if(c->retries >= TCP_MAX_RETRIES){
                dbg(TRANSPORT_CHANNEL, "node=%u CONNECTION_FAILED peer=%u " "retry limit reached\n", TOS_NODE_ID, c->remoteAddress);

                clearConnection(c);
                continue;
            }
            c->retries++;
            resendPending(c);
        }
    }
}