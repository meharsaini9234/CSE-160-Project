#ifndef TRANSPORT_PACKET_H
#define TRANSPORT_PACKET_H

#include <stdint.h>
#include "packet.h"
#include <stdbool.h>

enum{
    TCP_HEADER_SIZE = 9,
    TCP_MAX_DATA = PACKET_MAX_PAYLOAD_SIZE - TCP_HEADER_SIZE,

    TCP_SYN  = 1,
    TCP_ACK  = 2,
    TCP_FIN  = 4,
    TCP_DATA = 8,
    TCP_PROBE = 16,

    TCP_BUFFER_SIZE = 128,
    TCP_SEND_WINDOW = 44,
    TCP_MAX_CONNECTIONS = 2,

    TCP_MAX_SEQUENCE = 65535,
    TCP_CLIENT_ISN = 100,
    TCP_SERVER_ISN = 500,
    TCP_MAX_TRANSFER = 65033,

    TCP_TIMER_MS = 250,
    TCP_RTO_TICKS = 8,
    TCP_MAX_RETRIES = 8,
    TCP_LINGER_TICKS = 80,
    TCP_FIN_WAIT_TICKS = 160,
    TCP_MAX_PROBE_RETRIES = 8,

    TCP_TEST_BYTES = 33
};

typedef struct tcp_segment{
    uint8_t srcPort;
    uint8_t destPort;
    uint8_t flags;
    uint16_t seq;
    uint16_t ack;
    uint8_t window;
    uint8_t length;
    uint8_t data[TCP_MAX_DATA];
} tcp_segment_t;

void tcpEncode(pack* packet, tcp_segment_t* seg){
    uint8_t i;

    packet->payload[0] = seg->srcPort;
    packet->payload[1] = seg->destPort;
    packet->payload[2] = seg->flags;

    packet->payload[3] = (seg->seq >> 8) & 0xFF;
    packet->payload[4] = seg->seq & 0xFF;

    packet->payload[5] = (seg->ack >> 8) & 0xFF;
    packet->payload[6] = seg->ack & 0xFF;

    packet->payload[7] = seg->window;
    packet->payload[8] = seg->length;

    for(i = 0; i < TCP_MAX_DATA; i++){
        packet->payload[TCP_HEADER_SIZE + i] = i < seg->length ? seg->data[i] : 0;
    }
}

uint8_t tcpDecode(pack* packet, tcp_segment_t* seg){
    uint8_t i;

    seg->srcPort = packet->payload[0];
    seg->destPort = packet->payload[1];
    seg->flags = packet->payload[2];

    seg->seq = ((uint16_t) packet->payload[3] << 8) | packet->payload[4];

    seg->ack = ((uint16_t) packet->payload[5] << 8) | packet->payload[6];

    seg->window = packet->payload[7];
    seg->length = packet->payload[8];

    if(seg->length > TCP_MAX_DATA){
        return 0;
    }

    for(i = 0; i < seg->length; i++){
        seg->data[i] = packet->payload[TCP_HEADER_SIZE + i];
    }

    return 1;
}

#endif