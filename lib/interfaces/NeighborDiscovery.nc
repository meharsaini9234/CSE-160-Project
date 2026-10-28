#include "../../includes/packet.h"

interface NeighborDiscovery{
    command void start();
    command void receive(pack msg);
    command void print();

    command uint8_t getNeighborCount();
    command uint16_t getNeighbor(uint8_t index);
    command bool isConfirmed(uint16_t neighbor);
}