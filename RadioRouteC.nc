
/*
*	IMPORTANT:
*	The code will be avaluated based on:
*		Code design  
*
*/
 
 
#include "Timer.h"
#include "RadioRoute.h"


#define MAX_ROUTING_TABLE_SIZE 6
#define INFINITE_COST 255
#define INVALID_NODE_ID 0



module RadioRouteC @safe() {
  uses {
  
    /****** INTERFACES *****/
	interface Boot;

  //interfaces for communication
  interface Packet;
  interface SplitControl as AMControl;
  interface Receive;
  interface AMSend;

	//interface for timers
  interface Timer<TMilli> as Timer0;
  interface Timer<TMilli> as Timer1;

	//interface for LED
  interface Leds;

  //other interfaces, if needed

  }
}
implementation {

  message_t packet;
  
  // Variables to store the message to send
  message_t queued_packet;
  uint16_t queue_addr;
  uint16_t time_delays[7]={61,173,267,371,479,583,689}; //Time delay in milli seconds
  
  
  bool route_req_sent=FALSE;
  bool route_rep_sent=FALSE;
  bool data_sent=FALSE;
  
  bool locked;
  
  bool actual_send (uint16_t address, message_t* packet);
  bool generate_send (uint16_t address, message_t* packet, uint8_t type);

  
  // Person code
  const uint8_t person_code [8]= {1,0,9,2,8,5,0,6};

  // Current person code digit
  uint16_t person_code_digit;

  //recived msg counter 
  uint16_t recived_msg_counter = 0;  
  
  // Routing table entry
  typedef struct {
    uint16_t destination;
    uint16_t nextHop;
    uint8_t cost;
  } RoutingTableEntry;

  // Routing table
  RoutingTableEntry routingTable[MAX_ROUTING_TABLE_SIZE];

  bool isRouteAvailable(uint16_t destination);
  bool isCostLower(uint16_t destination, uint16_t cost);
  void updateRoutingTable(uint16_t destination, uint16_t nextHop, uint16_t cost);
  uint16_t getNextHop(uint16_t destination);
  uint16_t getCost(uint16_t destination);

  
  
  bool generate_send (uint16_t address, message_t* packet, uint8_t type){
  /*
  * 
  * Function to be used when performing the send after the receive message event.
  * It store the packet and address into a global variable and start the timer execution to schedule the send.
  * It allow the sending of only one message for each REQ and REP type
  * @Input:
  *		address: packet destination address
  *		packet: full packet to be sent (Not only Payload)
  *		type: payload message type
  *
  * MANDATORY: DO NOT MODIFY THIS FUNCTION
  */
  	if (call Timer0.isRunning()){
  		return FALSE;
  	}else{
  	if (type == 1 && !route_req_sent ){
  		route_req_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 2 && !route_rep_sent){
  	  	route_rep_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 0){
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;	
  	}
  	}
  	return TRUE;
  }
  
  event void Timer0.fired() {
  	/*
  	* Timer triggered to perform the send.
  	* MANDATORY: DO NOT MODIFY THIS FUNCTION
  	*/
  	actual_send (queue_addr, &queued_packet);
  }
  
  bool actual_send (uint16_t address, message_t* packet){
	/*
	* Implement here the logic to perform the actual send of the packet using the tinyOS interfaces
	*/  

  radio_route_msg_t * payload = (radio_route_msg_t*)call Packet.getPayload(packet, sizeof(radio_route_msg_t));

  if (locked){
    dbgerror("radio_send", "Radio is locked\n");
    return FALSE;
  }

  switch(payload->type){

    //DATA_MESSAGE
    case 0:
      dbg("radio_pack", ">>>Sending DATA_MESSAGE to next hop\n");
      dbg_clear("radio_pack", "\t\t sender: %hu \n ", payload->sender);
      dbg_clear("radio_pack", "\t\t destination: %hu \n ", payload->destination);

      if (call AMSend.send(getNextHop(payload->destination), packet, sizeof(radio_route_msg_t)) == SUCCESS){
        locked = TRUE;
        dbg("radio_send", "DATA_MESSAGE sent to %d\n", getNextHop(payload->destination));
        return TRUE;
      }
      else{
        dbg("radio_send", "DATA_MESSAGE not sent to %d\n", getNextHop(payload->destination));
        return FALSE;
      }
      break;


    //ROUTE_REQUEST
    case 1:
      dbg_clear("radio_pack", "\n-------------------------------------------\n\n");
      dbg("radio_pack", ">>>Sending ROUTE_REQ to broadcast \n");
      dbg_clear("radio_pack", "\t\t node requested: %hu \n ", payload->nodeRequested);

      if (call AMSend.send(AM_BROADCAST_ADDR, packet, sizeof(radio_route_msg_t)) == SUCCESS){
        locked = TRUE;
        dbg("radio_send", "ROUTE_REQ sent to broadcast\n");
        return TRUE;
      }
      else{
        dbgerror("radio_send", "ROUTE_REQ not sent to broadcast\n");
        return FALSE;
      }
      
      break;


    //ROUTE_REPLY
    case 2:
      dbg_clear("radio_pack", "\n-------------------------------------------\n\n");
      dbg("radio_pack", ">>>Sending ROUTE_REP to broadcast \n");
      dbg_clear("radio_pack", "\t\t sender: %hu \n ", payload->sender);
      dbg_clear("radio_pack", "\t\t node requested: %hu \n ", payload->nodeRequested);
      dbg_clear("radio_pack", "\t\t cost: %hu \n ", payload->cost);

      if (call AMSend.send(AM_BROADCAST_ADDR, packet, sizeof(radio_route_msg_t)) == SUCCESS){
        locked = TRUE;
        dbg("radio_send", "ROUTE_REP sent to broadcast\n");
        return TRUE;
      }
      else{
        dbgerror("radio_send", "ROUTE_REP not sent to broadcast\n");
        return FALSE;
      }

      break;


    //INVALID_MESSAGE
    default:
      dbgerror("radio_send", "Trying to send an invalid message type\n");
      return FALSE;
      break;      
  }
}

  
  
  event void Boot.booted() {
    dbg("boot","Application booted.\n");
    /* Fill it ... */
    call AMControl.start(); // Start the radio
  }

  event void AMControl.startDone(error_t err) {
    uint8_t i;

    if (err == SUCCESS) {
      dbg("radio", "Radio successfully started\n");

      // Initialize the routing table
      for ( i = 0; i < MAX_ROUTING_TABLE_SIZE; i++) {
        routingTable[i].destination = INVALID_NODE_ID;
        routingTable[i].nextHop = INVALID_NODE_ID;
        routingTable[i].cost = INFINITE_COST;
      }

      // Start the timer
      call Timer1.startOneShot(5000); 
    } else {
      dbg("radio", "Radio failed to start, Trying again\n");
      call AMControl.start(); // Try to start the radio again
    }
  }

  event void AMControl.stopDone(error_t err) {
    /* Fill it ... */
    dbg("radio", "Radio stopped\n");
  }
  
  event void Timer1.fired() {
    /*
     * Implement here the logic to trigger the Node 1 to send the first REQ packet
     */
    dbg("timer", "Timer1 fired\n");
    if (TOS_NODE_ID == 1) {
      radio_route_msg_t * payload = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      if (payload == NULL) {
        // Failed to obtain payload pointer, handle the error
        dbgerror("radio_pack", "Failed to obtain payload\n");
      } else {
        payload -> type = 1; 
        payload -> nodeRequested = 7;

        // Generate and schedule the message transmission
        if (!generate_send(payload -> destination, &packet, payload -> type)) {
          // Failed to schedule the message transmission, handle the error
          dbgerror("radio_send", "Failed to schedule message transmission\n");
        } else {
          dbg("radio_send", "Scheduled Route request for Node %hu from Node %hu\n", payload -> nodeRequested, TOS_NODE_ID);
        }
      }

    }
  }

event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
  /*
  * Parse the receive packet.
  * Implement all the functionalities
  * Perform the packet send using the generate_send function if needed
  * Implement the LED logic and print LED status on Debug
  */

  uint8_t type;
  uint16_t sender;
  uint16_t destination;
  uint16_t node_requested;
  uint8_t cost;

  if (len != sizeof(radio_route_msg_t)) {
    return bufPtr;
  } else {
    radio_route_msg_t* receivedMsg = (radio_route_msg_t*)payload;

    dbg_clear("radio_rec", "\n-------------------------------------------\n\n");
    dbg("radio_rec", "Received packet at time %s\n", sim_time_string());


    // Access the fields of the received message
    type = receivedMsg->type;
    sender = receivedMsg->sender;
    destination = receivedMsg->destination;

    // Perform actions based on the message type
    switch (type) {
      case 0:
        // Data message
        // Process the data message fields (sender, destination, value)

        dbg("radio_rec", "Node %hu received a Data message\n", TOS_NODE_ID);
        dbg("radio_pack", ">>>Pack \n");
        dbg_clear("radio_pack", "\t\t Payload Received\n");
        dbg_clear("radio_pack", "\t\t sender: %hu \n ", receivedMsg->sender);
        dbg_clear("radio_pack", "\t\t destination: %hu \n ", receivedMsg->destination);
        dbg_clear("radio_pack", "\t\t value: %hu \n ", receivedMsg->value);


        if(isRouteAvailable(destination)){
            if (!generate_send(getNextHop(destination), bufPtr, receivedMsg->type)) {
            // Failed to schedule the message transmission, handle the error
            dbg("radio_send", "Failed to schedule message transmission\n");
          } else {
            dbg("radio_send", "Scheduled Data message transmission from Node %hu\n", TOS_NODE_ID);
          }
        }

        break;
      case 1:
        // Route Request message
        // Process the route request message fields (node requested)
        dbg("radio_rec", "Node %hu received a Route Request message\n", TOS_NODE_ID);
        dbg("radio_pack", ">>>Pack \n");
        dbg_clear("radio_pack", "\t\t Payload Received\n");
        dbg_clear("radio_pack", "\t\t node requested: %hu \n ", receivedMsg->nodeRequested);

        // Parse node requested
        node_requested = receivedMsg->nodeRequested;

        // If I'm the requested node, send a Route Reply message
        if (node_requested == TOS_NODE_ID) {

          // Allows for only one Route Reply message to be sent
          if (route_rep_sent==TRUE){
          dbg("radio_rec", "Node %hu already sent a Route Reply message\n", TOS_NODE_ID);
          break;
          }

          dbg("radio_rec", "Node %hu received a Route Request message for itself\n", TOS_NODE_ID);
          // Create a Route Reply message
          receivedMsg->type = 2;
          receivedMsg->sender = TOS_NODE_ID;
          receivedMsg->cost = 1;

          // Generate and schedule the message transmission
          if (!generate_send(sender, bufPtr, receivedMsg->type)) {
            // Failed to schedule the message transmission, handle the error
            dbgerror("radio_send", "Failed to schedule message transmission\n");
          } else {
            dbg("radio_send", "Scheduled message Route Reply from Node %hu\n", TOS_NODE_ID);
          }
        } else if(isRouteAvailable(node_requested)){ // If I know the route to the requested node, send a Route Reply message 

          // Allows for only one Route Reply message to be sent
          if (route_rep_sent==TRUE){
          dbg("radio_rec", "Node %hu already sent a Route Reply message\n", TOS_NODE_ID);
          break;
          }

          receivedMsg->type = 2;
          receivedMsg->sender = TOS_NODE_ID;
          receivedMsg->cost = getCost(node_requested) + 1;

          // Generate and schedule the message transmission
          if (!generate_send(sender, bufPtr, receivedMsg->type)) {
            // Failed to schedule the message transmission, handle the error
            dbgerror("radio_send", "Failed to schedule message transmission\n");
          } else {
            dbg("radio_send", "Scheduled message Route Reply from Node %hu\n", TOS_NODE_ID);
          }

        }
        else{// Forward the Route Request message

          // Allows for only one Route Request message to be sent
          if (route_req_sent==TRUE){
            dbg("radio_rec", "Node %hu already sent a Route Request message\n", TOS_NODE_ID);
            break;
          }

          receivedMsg->type = 1;
          if (!generate_send(AM_BROADCAST_ADDR, bufPtr, receivedMsg->type)) {
            // Failed to schedule the message transmission, handle the error
            dbgerror("radio_send", "Failed to schedule message transmission\n");
          } else {
            dbg("radio_send", "Scheduled message Route Request Forward from Node %hu\n", TOS_NODE_ID);
          }
        }
        
        break;
      case 2:
        // Route Reply message
        dbg("radio_rec", "Node %hu received a Route Reply message\n", TOS_NODE_ID);
        dbg("radio_pack", ">>>Pack \n");
        dbg_clear("radio_pack", "\t\t Payload Received\n");
        dbg_clear("radio_pack", "\t\t sender: %hu \n ", receivedMsg->sender);
        dbg_clear("radio_pack", "\t\t node requested: %hu \n ", receivedMsg->nodeRequested);
        dbg_clear("radio_pack", "\t\t cost: %hhu \n ", receivedMsg->cost);

        // Parse node requested and cost
        node_requested = receivedMsg->nodeRequested;
        cost = receivedMsg->cost;


        // If I'm the requested node, do nothing
        if (node_requested == TOS_NODE_ID) {
          dbg("radio_rec", "Node %hu received a Route Reply message for itself\n", TOS_NODE_ID);
          break;
        }else if(!isRouteAvailable(node_requested) || isCostLower(node_requested, cost)){

          // Update the routing table
          updateRoutingTable(node_requested, sender, cost);
          dbg("radio_rec", "Node %hu updated the routing table with destination %hu, next hop %hu and cost %hhu\n", TOS_NODE_ID, node_requested, sender, cost);

          // Allows for only one Route Reply message to be sent
          if (route_rep_sent==TRUE){
          dbg("radio_rec", "Node %hu already sent a Route Reply message\n", TOS_NODE_ID);
          break;
          }

          // Forward the Route Reply message incrementing the cost by 1
          receivedMsg->cost = cost + 1;
          receivedMsg->sender = TOS_NODE_ID;
          if (!generate_send(AM_BROADCAST_ADDR, bufPtr, type)) {
            // Failed to schedule the message transmission, handle the error
            dbgerror("radio_send", "Failed to schedule route_reply transmission\n");
          } else {
            dbg("radio_send", "Scheduled route_reply transmission from Node %hu\n", TOS_NODE_ID);
          }

        }else if(TOS_NODE_ID==1 && !data_sent){
          // generate send value 5 destination 7
          receivedMsg->type = 0;
          receivedMsg->sender = TOS_NODE_ID;
          receivedMsg->destination = 7;
          receivedMsg->value = 5;

          if (!generate_send(getNextHop(receivedMsg->destination), bufPtr, receivedMsg->type)) {
            // Failed to schedule the message transmission, handle the error
            dbgerror("radio_send", "Failed to schedule message transmission\n");
          } else {
            dbg("radio_send", "Scheduled message Data from Node %hu\n", TOS_NODE_ID);
          }
        }

        // ...
        break;
      default:
        // Unknown message type
        dbgerror("radio_rec", "Unknown message type %hhu\n", type);
        break;
    }

    // Led logic

    person_code_digit = recived_msg_counter % 8;

    switch (person_code[person_code_digit] % 3) {
      case 0:
        call Leds.led0Toggle();
        dbg("led_0","Received packet %hu, person code digit %hu, activating LED 0\n", recived_msg_counter, person_code[person_code_digit]);
        break;
      case 1:
        call Leds.led1Toggle();
        dbg("led_1","Received packet %hu, person code digit %hu, activating LED 1\n", recived_msg_counter, person_code[person_code_digit]);
        break;
      case 2:
        call Leds.led2Toggle();
        dbg("led_2","Received packet %hu, person code digit %hu, activating LED 2\n", recived_msg_counter, person_code[person_code_digit]);
        break;
    }

    dbg("led_status","LED status: %d%d%d\n", (call Leds.get() & LEDS_LED0) , (call Leds.get() & LEDS_LED1)/2, (call Leds.get() & LEDS_LED2)/4);

    dbg_clear("radio_rec", "\n-------------------------------------------\n\n");
    
    recived_msg_counter++;

    return bufPtr;
  }

  dbgerror("radio_rec", "Receiving error \n");

  return bufPtr;
}


  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	/* This event is triggered when a message is sent 
	*  Check if the packet is sent 
	*/ 
    radio_route_msg_t * payload = (radio_route_msg_t*)call Packet.getPayload(bufPtr, sizeof(radio_route_msg_t));

    if (error == SUCCESS) {

      // Unlocked the radio
      locked = FALSE;

      dbg("radio_send", "Packet sent...");
      dbg_clear("radio_send", " at time %s \n", sim_time_string());

      // Allow only one data message to be sent from node 1
      if (payload->type == 0 && TOS_NODE_ID == 1) {
      data_sent = TRUE;
      dbg("radio_send", "Node %hu will not send any more data messages\n", TOS_NODE_ID);
      }

    }
    else{
      dbgerror("radio_send", "Send done error!\n");
    }
  }

  bool isRouteAvailable(uint16_t destination) {
  // Iterate through the routing table and check if a route exists for the destination
  
  uint8_t i;
  for ( i = 0; i < MAX_ROUTING_TABLE_SIZE; i++) {
    if (routingTable[i].destination == destination) {
      return TRUE; // Route found
    }
  }
  
  return FALSE; // Route not found
}

bool isCostLower(uint16_t destination, uint16_t cost) {
  // Iterate through the routing table and check if the cost is lower than the current one

  uint8_t i;
  for ( i = 0; i < MAX_ROUTING_TABLE_SIZE; i++) {
    if (routingTable[i].destination == destination) {
      if (routingTable[i].cost > cost) {
        return TRUE; // Cost is lower
      }
    }
  }
  
  return FALSE; // Cost is not lower
}

void updateRoutingTable(uint16_t destination, uint16_t nextHop, uint16_t cost) {
  // Iterate through the routing table and update the entry if it exists, otherwise add a new entry

  uint8_t i;
  
  for (i = 0; i < MAX_ROUTING_TABLE_SIZE; i++) {
    if (routingTable[i].destination == destination) {
      routingTable[i].nextHop = nextHop;
      routingTable[i].cost = cost;
      return;
    }
  }
  
  for (i = 0; i < MAX_ROUTING_TABLE_SIZE; i++) {
    if (routingTable[i].destination == INVALID_NODE_ID) {
      routingTable[i].destination = destination;
      routingTable[i].nextHop = nextHop;
      routingTable[i].cost = cost;
      return;
    }
  }
}

uint16_t getNextHop(uint16_t destination) {
  // Iterate through the routing table and return the next hop for the destination

  uint8_t i;
  for ( i = 0; i < MAX_ROUTING_TABLE_SIZE; i++) {
    if (routingTable[i].destination == destination) {
      return routingTable[i].nextHop;
    }
  }
  
  return INVALID_NODE_ID;
}

uint16_t getCost(uint16_t destination) {
  // Iterate through the routing table and return the cost for the destination

  uint8_t i;
  for ( i = 0; i < MAX_ROUTING_TABLE_SIZE; i++) {
    if (routingTable[i].destination == destination) {
      return routingTable[i].cost;
    }
  }
  
  return INFINITE_COST;
}
}
