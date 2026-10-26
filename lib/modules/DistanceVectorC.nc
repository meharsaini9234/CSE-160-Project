configuration DistanceVectorC {
    provides interface RoutingTable;
}

implementation {
    components DistanceVectorP;
    components NeighborDiscoveryC;
    components new TimerMilliC() as RoutingTimerC;

    RoutingTable = DistanceVectorP.RoutingTable;

    DistanceVectorP.NeighborDiscovery ->
        NeighborDiscoveryC.NeighborDiscovery;

    DistanceVectorP.RoutingTimer ->
        RoutingTimerC;
}