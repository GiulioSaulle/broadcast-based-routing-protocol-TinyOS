<h1>Broadcast-based Routing Protocol in TinyOS</h1>
    <h2>Overview</h2>
    <p>This project implements a broadcast-based routing protocol for wireless sensor networks (WSNs) using TinyOS. The protocol focuses on efficient message dissemination and routing, ensuring scalability and energy efficiency by minimizing unnecessary message retransmissions across the network.</p>
    <h2>Key Features</h2>
    <ul>
        <li><strong>Routing Table Implementation</strong>: Each node maintains a routing table with entries for the destination, next hop, and associated cost.</li>
        <li><strong>Broadcast-Based Routing</strong>: Messages are broadcasted across the network, with different message types (data, route request, route reply) handled appropriately.</li>
        <li><strong>Cost Optimization</strong>: Routes are selected based on cost, and routing tables are updated dynamically to ensure the lowest cost paths are used.</li>
        <li><strong>Error Handling</strong>: Mechanisms to detect and handle transmission errors, message type mismatches, and routing issues.</li>
        <li><strong>LED Logic</strong>: A visual indication of message receipt using the device's LEDs to track message handling by nodes.</li>
    </ul>
    <h2>Message Format and Routing Table</h2>
    <p>The protocol uses a unified message structure to represent all types of network messages, including data and routing requests. The routing table is used to store and manage routes between nodes.</p>
    <h3>Routing Table Structure</h3>
    <pre><code>
typedef struct {
  uint16_t destination;
  uint16_t nextHop;
  uint8_t cost;
} RoutingTableEntry;

RoutingTableEntry routingTable[MAX_ROUTING_TABLE_SIZE];
    </code></pre>
    <h3>Message Structure</h3>
    <pre><code>
typedef nx_struct radio_route_msg {
  nx_uint8_t type;
  nx_uint16_t sender;
  nx_uint16_t destination;
  nx_uint16_t value;
  nx_uint16_t nodeRequested;
  nx_uint8_t cost;
} radio_route_msg_t;
    </code></pre>
    <h2>Core Functions</h2>
    <ul>
        <li><strong>Route Availability</strong>: <code>bool isRouteAvailable(uint16_t destination)</code> checks if a route exists.</li>
        <li><strong>Cost Comparison</strong>: <code>bool isCostLower(uint16_t destination, uint16_t cost)</code> checks if a new route offers a lower cost.</li>
        <li><strong>Routing Table Updates</strong>: <code>void updateRoutingTable(uint16_t destination, uint16_t nextHop, uint16_t cost)</code> updates the routing table with new routing information.</li>
        <li><strong>Next Hop Retrieval</strong>: <code>uint16_t getNextHop(uint16_t destination)</code> retrieves the next hop for a given destination.</li>
        <li><strong>Cost Retrieval</strong>: <code>uint16_t getCost(uint16_t destination)</code> retrieves the route cost for a specific destination.</li>
    </ul>
    <h2>Boot Sequence</h2>
    <p>During the boot sequence, the protocol initializes the radio and the routing table. If the radio fails to start, it will attempt to restart. After the radio is active, the protocol initializes the routing table and sets timers to schedule routing requests and manage message transmissions.</p>
    <h2>Message Transmission</h2>
    <ul>
        <li><strong>Route Request Messages (REQ)</strong>: Broadcast to all nodes to find routes to a specific destination.</li>
        <li><strong>Route Reply Messages (REP)</strong>: Sent in response to route requests, indicating a route to the requested node.</li>
        <li><strong>Data Messages</strong>: Used to deliver information to the destination using the routing table.</li>
    </ul>
    <h2>LED Status Indicator</h2>
    <p>The LED logic provides visual feedback for message receipt, toggling LEDs based on node activity and message reception.</p>
    <pre><code>
person_code_digit = received_msg_counter % 8;
switch (person_code[person_code_digit] % 3) {
  case 0: call Leds.led0Toggle(); break;
  case 1: call Leds.led1Toggle(); break;
  case 2: call Leds.led2Toggle(); break;
}
    </code></pre>
    <h2>Simulations with TOSSIM</h2>
    <p>The protocol can be simulated using TOSSIM with debug channels to monitor node activity and message flow. The network topology is set with bidirectional links, and various metrics like LED status are logged during the simulation.</p>
    <h2>Installation</h2>
    <h3>Prerequisites</h3>
    <ul>
        <li>TinyOS installed and configured</li>
        <li>TOSSIM (for simulations)</li>
    </ul>
    <h3>Steps</h3>
    <ol>
        <li>Clone the repository:
            <pre><code>git clone https://github.com/GiulioSaulle/broadcast-based-routing-protocol-TinyOS.git</code></pre>
        </li>
        <li>Compile the code for your platform:
            <pre><code>make micaz</code></pre>
        </li>
        <li>Install and run on nodes:
            <pre><code>make micaz install,<node_id></code></pre>
        </li>
        <li>Run simulations with TOSSIM (optional).</li>
    </ol>
    <h2>License</h2>
    <p>This project is licensed under the MIT License. See the <a href="LICENSE">LICENSE</a> file for more details.</p>
    <h2>Contributors</h2>
    <p>
      <li><strong>Giulio Saulle</strong></li>
      <li><strong>Mirko Bitetto</strong></li></p>
</html>
