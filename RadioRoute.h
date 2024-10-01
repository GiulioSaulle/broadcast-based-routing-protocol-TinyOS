

#ifndef RADIO_ROUTE_H
#define RADIO_ROUTE_H

typedef nx_struct radio_route_msg {
  nx_uint8_t type;
  nx_uint16_t sender;
  nx_uint16_t destination;
  nx_uint16_t value;
  nx_uint16_t nodeRequested;
  nx_uint8_t cost;
} radio_route_msg_t;

enum {
  AM_RADIO_COUNT_MSG = 10,
};

#endif
