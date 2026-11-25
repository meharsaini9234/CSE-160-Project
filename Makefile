COMPONENT=NodeC


INCLUDE=-IdataStructures
INCLUDE+=-IdataStructures/interfaces/ -IdataStructures/modules
INCLUDE+=-Ilib/interfaces -Ilib/modules
CFLAGS += -DTOSH_DATA_LENGTH=28
CFLAGS+=$(INCLUDE)

#########Packet loss test##############
#CFLAGS += -DTEST_DROP_TCP_DATA

#########Flow control test#############
#CFLAGS += -DTEST_ZERO_WINDOW
#CFLAGS += -DTEST_DROP_WINDOW_REOPEN

#########Connection close loss test#######
#CFLAGS += -DTEST_DROP_FINAL_ACK

include $(TINYOS_ROOT_DIR)/Makefile.include

CommandMsg.py: CommandMsg.h
	nescc-mig python -python-classname=CommandMsg CommandMsg.h CommandMsg -o $@

packet.py: packet.h
	nescc-mig python -python-classname=pack packet.h pack -o packet.py
