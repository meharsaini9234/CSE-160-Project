#include "../../includes/packet.h"

interface IP{
    command error_t send(pack msg);
    command void receive(pack msg);

    event void delivered(pack msg);
}