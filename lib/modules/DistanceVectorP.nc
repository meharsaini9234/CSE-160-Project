#include "../../includes/packet.h"
#include "../../includes/channels.h"

module DistanceVectorP {
    provides interface RoutingTable;
}

implementation{

    enum{
        MAX_ROUTES = 32, 
        ROUTE_INFINITY = 16
    };

    typedef struct{
        uint16_t destination;
        uint16_t nextHop;
        uint8_t cost; 
        bool valid; 
        uint8_t routeAge;
    } routeEntry;

    routeEntry routingTable[MAX_ROUTES];
    uint8_t routeCount = 0;

    int8_t findRoute(uint16_t destination){
        uint8_t i;

        for (i = 0; i< routeCount; i++){
            if(routingTable[i].destination == destination) {
                return i;
            }
        }

        return -1;
    }

    command bool RoutingTable.getRoute(
        uint16_t destination, 
        uint16_t* nextHop, 
        uint8_t* cost
    ) {
        int8_t routeIndex;

        routeIndex = findRoute(destination); 

        if(routeIndex < 0){ 
            return FALSE;
        }

        if(!routingTable[routeIndex].valid || routingTable[routeIndex].cost >= ROUTE_INFINITY) {
            return FALSE;
        }

        *nextHop = routingTable[routeIndex].nextHop;
        *cost = routingTable[routeIndex].cost;

        return TRUE;
    }

    command void RoutingTable.printTable(){
        uint8_t i; 

        dbg(GENERAL_CHANNEL, "Node %d Routing Table:\n", TOS_NODE_ID);

        dbg(GENERAL_CHANNEL, "Dest NextHop Cost State\n");

        for(i=0; i< routeCount; i++){
            dbg(GENERAL_CHANNEL, "%d     %d      %d     %s\n" , 
            routingTable[i].destination, 
            routingTable[i].nextHop,
            routingTable[i].cost,
            routingTable[i].valid && routingTable[i].cost < ROUTE_INFINITY ? "VALID" : "INF");

        }
    }
}