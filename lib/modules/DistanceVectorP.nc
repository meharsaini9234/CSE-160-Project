#include "../../includes/packet.h"
#include "../../includes/channels.h"

module DistanceVectorP {
    provides interface RoutingTable;
    provides interface Routing;

    uses interface NeighborDiscovery;
    uses interface Timer<TMilli> as RoutingTimer;
}

implementation{

    enum{
        MAX_ROUTES = 32, //allocate space for 32 routing entries
        ROUTE_INFINITY = 16, //route  with cost 16 considered unreachable
        ROUTING_PERIOD = 3000, //timer fires every 3 seconds
        ROUTE_TIMEOUT = 4 //learned route expires after 12 seconds  
    };

    typedef struct{
        uint16_t destination;
        uint16_t nextHop;
        uint8_t cost; 
        bool valid; 
        uint8_t routeAge;
    } routeEntry; //data type that stores info about one destination 

    routeEntry routingTable[MAX_ROUTES]; //routing table array that can hold 32 routeEntry structures
    uint8_t routeCount = 0; //how many entries in use

    int8_t findRoute(uint16_t destination){ //function accepts dest node id
        uint8_t i;

        for (i = 0; i< routeCount; i++){ //loop through the table
            if(routingTable[i].destination == destination) { //if any entries match dest we're searching for 
                return i;
            }
        }

        return -1; // we didnt find dest 
    }

    uint8_t calculateCost(uint8_t advertisedCost){
        //cost 16 means dest is unreachable
        //adding one hop to cost 15 also makes it unreachable
        if (advertisedCost >= ROUTE_INFINITY - 1){
            return ROUTE_INFINITY;
        }
        //add one hop because we must first reach the neighbor
        return advertisedCost + 1;
    }

    bool isActiveNeighbor(uint16_t neighbor){
        uint8_t i;
        uint8_t count;

        count = call NeighborDiscovery.getNeighborCount();

        for(i = 0; i < count; i++){
            if(call NeighborDiscovery.getNeighbor(i)==neighbor){
                return TRUE;
            }
        }
        return FALSE;
    }
    void markRoutesUnreachable(uint16_t neighbor){
        uint8_t i;

        for(i=0; i < routeCount; i++){
            // Never invalidate own route
            if(routingTable[i].destination == TOS_NODE_ID){
                continue;
            }
            //check whether this route uses the failed neighbor
            if(routingTable[i].nextHop == neighbor && routingTable[i].valid){
                routingTable[i].cost = ROUTE_INFINITY;
                routingTable[i].valid = FALSE;

                dbg(ROUTING_CHANNEL,
                "Node %d invalidated route to %d through %d\n",TOS_NODE_ID,
                routingTable[i].destination,neighbor);
            }
        }
    }

    void checkFailedNeighbors(){
        uint8_t i;

        for(i = 0; i < routeCount; i++){
            uint16_t nextHop = routingTable[i].nextHop;

            //Skip own route
            if(routingTable[i].destination == TOS_NODE_ID){
                continue;
            }

            //skip already invalid routes
            if(!routingTable[i].valid){
                continue;
            }
            //if the next hop is no longer active, invalidate its routes
            if(!isActiveNeighbor(nextHop)){
                markRoutesUnreachable(nextHop);
            }
            }

        
    }

    void ageRoutes(){
        uint8_t i; 

        for(i=0; i< routeCount; i++){

            //never age own route own root should never expire
            if(routingTable[i].destination == TOS_NODE_ID){
                continue; 
            }
            //skip invalid routes for now
            if(!routingTable[i].valid){
                continue;
            }
            //direct neighbors maintained by nd because they have cost 1 and nd is responnsible for detecting if still reachable
            if(routingTable[i].destination == routingTable[i].nextHop && isActiveNeighbor(routingTable[i].destination)){
                continue;
            }
            //increase age of learned routes, counts how long we've gone without recieving new routing info
            routingTable[i].routeAge++;

            //Expire routes that havent been refreshed 
            if(routingTable[i].routeAge >= ROUTE_TIMEOUT){
                routingTable[i].cost = ROUTE_INFINITY;
                routingTable[i].valid = FALSE;

                dbg(ROUTING_CHANNEL,
                "Node %d route to %d expired\n",
                TOS_NODE_ID,
                routingTable[i].destination);
            }
        }
    }

    command bool RoutingTable.getRoute( //used for packet forwarding
        uint16_t destination, 
        uint16_t* nextHop, 
        uint8_t* cost
    ) {
        int8_t routeIndex;

        routeIndex = findRoute(destination); 

        if(routeIndex < 0){  //if route doesnt exist 
            return FALSE;
        }

        if(!routingTable[routeIndex].valid || routingTable[routeIndex].cost >= ROUTE_INFINITY) { //if route not valid or cost is too big 
            return FALSE;
        }

        *nextHop = routingTable[routeIndex].nextHop;
        *cost = routingTable[routeIndex].cost;

        return TRUE; //found a valid route and provided next hop and cost
    }
    command bool Routing.getRoute(
        uint16_t destination,
        uint16_t* nextHop,
        uint8_t* cost
    ){
        int8_t routeIndex = findRoute(destination);

    if(routeIndex < 0)
        return FALSE;

    if(!routingTable[routeIndex].valid ||
       routingTable[routeIndex].cost >= ROUTE_INFINITY)
        return FALSE;

        *nextHop = routingTable[routeIndex].nextHop;
        *cost = routingTable[routeIndex].cost;

        return TRUE;
}


    command void RoutingTable.printTable(){
        uint8_t i; //loop counter

        dbg(ROUTING_CHANNEL, "Node %d Routing Table:\n", TOS_NODE_ID); //print node id

        dbg(ROUTING_CHANNEL, "Dest NextHop Cost State\n"); //print column headings

        for(i=0; i< routeCount; i++){ //loop through and print each entry
            dbg(ROUTING_CHANNEL, "%d     %d      %d     %s\n" , 
            routingTable[i].destination, 
            routingTable[i].nextHop,
            routingTable[i].cost,
            routingTable[i].valid && routingTable[i].cost < ROUTE_INFINITY ? "VALID" : "INF");

        }
    }

    command void RoutingTable.start() {
    uint8_t i;

    // Clear all routing table entries
    for(i = 0; i < MAX_ROUTES; i++){
        routingTable[i].valid = FALSE;
        routingTable[i].routeAge = 0;
    }

    routeCount = 1;

    // Initialize route to ourselves
    routingTable[0].destination = TOS_NODE_ID;
    routingTable[0].nextHop = TOS_NODE_ID;
    routingTable[0].cost = 0;
    routingTable[0].valid = TRUE;
    routingTable[0].routeAge = 0;

    // Start the timer once
    call RoutingTimer.startPeriodic(ROUTING_PERIOD);

    dbg(GENERAL_CHANNEL,
        "Node %d initialized its routing table\n",
        TOS_NODE_ID);
}

    command void RoutingTable.updateDirectNeighbor(uint16_t neighbor){
        int8_t routeIndex;

        if(neighbor == TOS_NODE_ID){ //do not add self as neighbor
            return;
        }
        //only accepts neighbors currently in nd
        if(!isActiveNeighbor(neighbor)){
            return;
        }

        routeIndex = findRoute(neighbor); //check if this neighbor already exists in the routing table

        if(routeIndex >= 0){
            //Update existing route
            routingTable[routeIndex].nextHop = neighbor;
            routingTable[routeIndex].cost = 1;
            routingTable[routeIndex].valid = TRUE;
            routingTable[routeIndex].routeAge = 0;
        }
        else if(routeCount < MAX_ROUTES){ 
            //Add a new route
            routingTable[routeCount].destination = neighbor;
            routingTable[routeCount].nextHop = neighbor;
            routingTable[routeCount].cost = 1;
            routingTable[routeCount].valid = TRUE;
            routingTable[routeCount].routeAge = 0;

            routeCount++;
        }
        else{
            dbg(GENERAL_CHANNEL, 
            "Node %d routing table full, cannot add neighbor %d\n",
            TOS_NODE_ID, neighbor);
            return;
        }

        dbg(GENERAL_CHANNEL, "Node %d updated direct neighbor %d\n", TOS_NODE_ID, neighbor);
    }

    command void RoutingTable.updateFromNeighbor(
    uint16_t neighbor,
    uint16_t destination,
    uint8_t advertisedCost
) {
    int8_t routeIndex;
    uint8_t newCost;

    // Never change our route to ourselves
    if (destination == TOS_NODE_ID) {
        return;
    }
    //ignore routing updates from nodes that are not active neighbors
    if(!isActiveNeighbor(neighbor)){
        return;
    }
    //keep a direct neighbor's route at cost 1
    if(isActiveNeighbor(destination)){
        return;
    }
    // Calculate cost through this neighbor
    newCost = calculateCost(advertisedCost);

    // Look for destination in our routing table
    routeIndex = findRoute(destination);

    if (routeIndex < 0) {
        //only add new destination if reachable
        if (newCost >= ROUTE_INFINITY || routeCount >= MAX_ROUTES) {
            return;
        }

        routingTable[routeCount].destination = destination;
        routingTable[routeCount].nextHop = neighbor;
        routingTable[routeCount].cost = newCost;
        routingTable[routeCount].valid = TRUE;
        routingTable[routeCount].routeAge = 0;

        routeCount++;
    }
    else if (routingTable[routeIndex].nextHop == neighbor) {
        //current next hop tells us to accept better, worse, or unreachable cost
        routingTable[routeIndex].cost = newCost;
        routingTable[routeIndex].valid = (newCost < ROUTE_INFINITY);

        if (newCost < ROUTE_INFINITY) {
            routingTable[routeIndex].routeAge = 0;
        }
    }
    else if (newCost < ROUTE_INFINITY &&
             (!routingTable[routeIndex].valid ||
              newCost < routingTable[routeIndex].cost)) {
        // switch only if better or current route invalid
        routingTable[routeIndex].nextHop = neighbor;
        routingTable[routeIndex].cost = newCost;
        routingTable[routeIndex].valid = TRUE;
        routingTable[routeIndex].routeAge = 0;
    }
}
    event void RoutingTimer.fired(){
        checkFailedNeighbors();
        ageRoutes();
    }
}