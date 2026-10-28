configuration DistanceVectorC {
    provides interface RoutingTable;
    provides interface Routing;
    provides interface DVRecieve;
}

implementation {
    components DistanceVectorP;
    components NeighborDiscoveryC;
    components new TimerMilliC() as RoutingTimerC;
    components new SimpleSendC(AM_PACK) as DVSender;

    RoutingTable = DistanceVectorP.RoutingTable;
    Routing = DistanceVectorP.Routing;
    DVRecieve = DistanceVectorP.DVRecieve;

    DistanceVectorP.NeighborDiscovery ->
        NeighborDiscoveryC.NeighborDiscovery;

    DistanceVectorP.RoutingTimer ->
        RoutingTimerC;
    
    DistanceVectorP.Sender -> DVSender;
}