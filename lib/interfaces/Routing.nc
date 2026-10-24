#include <stdint.h>

interface Routing{
    command bool getRoute(uint16_t destination, uint16_t *nextHop, uint8_t *cost);
}