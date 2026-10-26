#include "../../includes/packet.h"

configuration IPC{
    provides interface IP;
    uses interface Routing;
}

implementation{
    components IPP;
    components new SimpleSendC(AM_PACK) as IPSender;

    IP = IPP.IP;
    Routing = IPP.Routing;
    
    IPP.Sender -> IPSender;
}