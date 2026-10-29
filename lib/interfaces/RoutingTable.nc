interface RoutingTable {
    command void start();

    command bool getRoute(
        uint16_t destination, 
        uint16_t* nextHop, 
        uint8_t* cost
    );
    command void printTable();

    command void updateDirectNeighbor(uint16_t neighbor);

    //process routing information recieved from a neighbor
    command void updateFromNeighbor(
        uint16_t neighbor,
        uint16_t destination, 
        uint8_t advertisedCost
    );
}