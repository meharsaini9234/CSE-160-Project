#include "../../includes/packet.h"

configuration FloodingC{
    provides interface Flooding;
}
implementation{
    components FloodingP;
    components new SimpleSendC(AM_PACK) as FloodSender;
    Flooding = FloodingP.Flooding;
    FloodingP.Sender -> FloodSender;

}