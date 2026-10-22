#include "../../includes/packet.h"

configuration NeighborDiscoveryC{
    provides interface NeighborDiscovery;
}
implementation{
    components NeighborDiscoveryP;
    components new TimerMilliC() as NeighborTimerC;
    components new SimpleSendC(AM_PACK) as NeighborSender;

    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;
    NeighborDiscoveryP.NeighborTimer -> NeighborTimerC;
    NeighborDiscoveryP.Sender -> NeighborSender;
}