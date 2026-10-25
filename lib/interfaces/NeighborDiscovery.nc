#include "../../includes/packet.h"

interface NeighborDiscovery{
    command void start();
    command void receive(pack msg);
    command void print();
    command uint8_t getNeighborCount(); //return number of currently discovered neighbors
    command uint16_t getNeighbor(uint8_t index); //return ID of a neighbor at given index
}