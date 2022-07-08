# Relay Function and Relays {#relay_behavior}

Clients may be configured to connect to a local relay which then does a 
Publish/Subscribe for the appropriate named data towards the origin  or 
towards another Relay. These relays can aggregate the subscriptions of 
multiple clients. This allows a relay in the LAN to aggregate request from 
multiple clients in subscription to the same data such that only one copy of 
the data flows across the WAN. In the case where there is only one client, 
this may still provides benefit in that a client that is experiencing loss 
on WIFI WAN has a very short RTT to the local relay so can recover the lost 
data much faster, and with less impact on end user QoE, than having to go 
across the LAN to recover the data.

Relays can also be deployed in classic CDN cache style for large scale 
streaming applications yet still provide much lower latency than traditional 
CDNs using Dash or HLS. Moving these relays into the 5G network close to 
clients may provide additional increase in QoE.

At a high level, Relay Function within QuicR architecture support store and 
forward behavior. Relay function can be realized in any component of the 
QuicR architecture depending on the application. Typical use-cases might 
require the intermediate servers (caches) and the origin server to implement 
the relay function. However the endpoint themselves can implement the Relay 
function in a Isomorphic deployment, if needed.

Non normatively, the Relay function is responsible carryout the following 
actions to enable the QuicR protocol:

1. On reception of ``` SUBSCRIBE ``` message, forward the message to the 
Origin server, and on the receipt of ``` SUBSCRIBE_REPLY ```, store the 
subscriber info against the names in the NAMES_SUCCESS field of the 
``` SUBSCRIBE ``` message. If an entry for the name exists already, add the 
new subscriber to the list of Subscibers. [ See Subscribe Aggregations]. 

2. If there exists a matching named object for a subscription in the cache, 
forward the data to the subscriber(s) based on the Subscriber INTENT. 

3. On reception of ```PUBLISH_INTENT``` message, forward the
 message to the Origin server, and on the receipt of 
 ``` PUBLISH_INTENT_OK ```, store the names as authorized against a 
 given publisher.

4. If a named object arrives at the relay via ```PUBLISH``` message , 
cache the name and the associated data, also distribute the same to 
all the active subscribers, if any, matching the given name.

The payload associated with a given ``` PUBLISH ``` message MUST not be 
cached longer than the __BESTBEFORE__ time specified. Also to note, the 
local policies dicatated by the caching service provider can always 
overwrite the caching duration for the published data.

Relays MUST NOT modify the either the ```Name``` or the contents of 
``` PUBLISH/SUBSCRIBE``` messags expect for performing the necessary 
forwarding and caching operations as described above.

## Relay fail over

A relay that wants to shutdown and use the redirect message to move traffic 
to a new relay. If a relay has failed and restarted or been load balanced 
to a different relay, the client will need to resubscribe to the new relay 
after setting up the connection.

TODO: Cluster so high reliable relays should share subscription info and 
publication to minimize of loss of data during a full over.

## Relay Discovery

Local relays can be discovered via MDNS query to TODO. Cloud relays 
are discovered via application defined ways that is out of scope 
of this document. A Relay can send a message to client with the 
address of new relay. Client moves to the new relay with all of its 
Subscriptions and then Client unsubscribes from old relay and closes 
connection to it.

This allows for make before break transfer from one relay to another 
so that no data is lost during transition. One of the uses of this 
is upgrade of the Relay software during operation.

## Implications of Fragmentation and Reassembly

TODO - Not sure if we need this.

Relay function MUST cache named-data objects items post  assembling the 
fragmented procedures. The choice of such caching is influence by 
attributes on the named object - discardable  or is_sync_point, 
for example. A given Relay implementation MAY also stored a few 
of the most recent full named objects regardless of the attributes 
to support quick sync up to the new subscribers or to support fast 
catchup functionalities.

When performing the relay function (forwarding), following 2 steps 
needs to be carried out:

1. The fragments are relayed to the subscriber as they arrive

2. The fully assembled fragments are stored based on attrbutes
 associated with the data and cache local policies.

It is up to the applications to define the right sized fragments 
as it can influence the latency of the delivery.