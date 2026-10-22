#include "../../includes/packet.h"

interface Flooding{
    command void send(pack msg);
    command void receive(pack msg);
}
