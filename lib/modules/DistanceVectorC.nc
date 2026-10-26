configuration DistanceVectorC {
    provides interface RoutingTable;
    provides interface Routing;
}

implementation {
    components DistanceVectorP;
    components NeighborDiscoveryC;
    components new TimerMilliC() as RoutingTimerC;

    RoutingTable = DistanceVectorP.RoutingTable;
    Routing = DistanceVectorP.Routing;

    DistanceVectorP.NeighborDiscovery ->
        NeighborDiscoveryC.NeighborDiscovery;

    DistanceVectorP.RoutingTimer ->
        RoutingTimerC;
}