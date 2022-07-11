# Relay Function and Relays {#relay_behavior}

Clients may be configured to connect to a local relay which then does a 
Publish/Subscribe for the appropriate named data towards the origin or 
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

The relays are capable of receiving data in stream mode or in datagram mode. In both modes, relays will cache fragments as they arrive.

In all modes, the relays maintain a list of connections that will receive new fragments when they are ready: connections from clients that have subscribed to the stream through this relay; and, if the media was received from a client, a connection to the origin to pass the content of the client-posted media to the origin. When new fragments are received, they are posted on the relevant connections as soon as the flow control and congestion control of the underlying QUIC connections allow.


## Cache and Relaying {#cache-and-relaying}

The prototype relays maintain a separate cache of received fragments for each media stream that it is processing. If fragments are received in stream mode, they will arrive in order. If fragments are received in datagram mode, fragments may arrive out of order.

The cache is created the first time a client connection refers to the media URL. This might be:

* A client connection requesting the name, in which case the relay will ask a copy of the media from the origin or the next hop relay towards the origin.

* A client connection publishing named data, in which case the relay will post a copy of the media towards the origin.

Once the media is available, the relay will learn the starting group ID and object ID.


Fragments are received from the "incoming" connection. If fragments are received in stream mode, they will arrive in order. If fragments are received in datagram mode, fragments may arrive out of order. When receiving in datagram mode, the media order is used to remove incoming duplicate fragments. When a non duplicate fragment is received, it is added to the cache and posted to corresponding subscribers over streams or datagrams,
when flow and congestion control allow transmissions

In stream mode, the transmission may be delayed until fragments are received in order. If the last fragment received "fills a hole", that fragment and the next available fragments in media order will be forwarded.

## Out of order relaying

As noted in (#cache-and-relaying), fragments that arrive out of order are relayed immediately. 

This design was arrived after trying two alternatives:

-  insisting on full order before relaying, as is done for stream mode;  OR

-  insisting on full reception of all fragments making an object.

Full order would introduce the same head-of-line blocking also visible in stream-based relays. In theory, relaying full objects without requiring that objects be ordered would avoid some of the head-of-line blocking, but in practice we see that some streams contain large and small objects, and that losses affecting fragments of large objects cause almost the same head of line blocking delays as full ordering. Moreover, if losses happen at several places in the relay graph, the delays will accumulate. Out of order relaying avoids these delays.

## Cache cleanup

Relays store objects no more than `best_before` time associated with the 
object. Congestion/Rate control feedback can further influence what 
gets cached based on the relative priority and rate at which data 
can be delivered. Local cache policies can also limit the amount and 
duration of data that can be cached.


## Relay fail over

A relay that wants to shutdown shall use the redirect message to move traffic 
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

