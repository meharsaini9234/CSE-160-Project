interface MidTransport{
    command void listen(uint8_t port);
    command error_t connect(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort, uint16_t transferBytes);    command void close(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort);
    command uint8_t write(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort, uint8_t* data, uint8_t length);
    event void connected(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort);
    event void writeReady(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort);
    command uint8_t read(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort, uint8_t* buffer, uint8_t maxLength);
    event void dataReady(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort);
    event void connectionFailed(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort);
    event void connectionClosed(uint16_t remoteAddress, uint8_t localPort, uint8_t remotePort);
}