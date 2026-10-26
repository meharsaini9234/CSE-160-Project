#include "../../includes/packet.h"

interface IP{
    command void send(pack msg);
    command void receive(pack msg);

    event void delivered(pack msg);
}