interface RoutingTable {
    command bool getRoute(
        uint16_t destination, 
        uint16_t* nextHop, 
        uint8_t* cost
    );
    command void printTable();
}