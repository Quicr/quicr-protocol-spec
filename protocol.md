# QUICR Protocol Design

QUICR supports delivering media over QUIC Streams as well as over 
QUIC Datagrams as choosen by the application.
/// TODO : Add api to pick in order or out of order delivery

Media delivery in QUICR is started by the pubisher/subscriber setting
up a Control Channel for a given QuicR name. The control channel, which
is based on QUIC straeam, is used to configure and setup properties for 
the Media channel. Media data is delivered over the Media Channel setup 
as QUIC streams or QUIC datagrams based on the application settings. 
The Control Channel can also be used to configure in-session parameter.

/// TODO - add call flow diagram



## Control Channel

When a client or relay begins a transaction with the relay/origin, 
the client starts by opening a new bilateral stream. This stream will act as the "control channel" for the exchange of data, carrying a series of control messages
in both directions. The same channel can be used for carrying "fragment" 
messages if the media data is sent in "stream" mode.

The control stream will remain open as long as the peers are still
sending or receiving the media. If either peer closes the control
stream, the other peer will close its end of the stream and discard the state
associated with the media transfer. 

Streams are "one way". If a peer both sends and receive media, there will
be different control streams for sending and receiving.

## QUICR Control Messages 

The control channel carry series of messages, encoded as a length followed by a message value:

```
quicr_message {
    length(16),
    value(...)
}
```

The length is encoded as a 16 bit number in big endian network order.


### Subscribe Message

Entities that intend to receive named objects will do so via 
subscriptions to the named objects. Subscriptions are sent from 
the QUICR clients to the origin server(s) (via relays, if present) 
and are typically processed by the relays. See {#relay_behavior} 
for further details. All the subsriptions MUST be authorized at
the Origin server.
 
Subscriptions are typically long-lived transactions and they stay 
active until one of the following happens 

   - a client local policy dictates expiration of a subscription.
   - optionally, a server policy dicates subscription expiration.
   - the underlying transport is disconnected.

When an explicit indication is preferred to indicate the  expiry of 
subscription, it is indicated via `SUBSCRIPTION_EXPIRY` message.

While the subscription is active for a given name, the Relay(s) 
must send named objects it receives to all the matching subscribers. 
A QUICR client can renew its subscrptions at any point by sending a 
new `SUBSCRIBE` message. Such subscriptions 
MUST refresh the existing subscriptions for that name. A renewal
period of 5 seconds is RECOMMENDED.


```
enum subscribe_intent 
{
  immediate(0),
  catch_up(1),
  wait_up(2),
}

quicr_subscribe_message {
 *     message_type(i),
 *     name_length(i),
 *     name(...),
 *     mask(7)
 *     subscribe_intent intent,
 *     [datagram_stream_id(i)]
 * }
```

The message type will be set to SUBSCRIBE_STREAM (1) if the client wants to receive the media in stream mode (via QUIC streams), or SUBSCRIBE_DATAGRAM (2) if receiving in datagram mode. If in datagram mode, the client must select a datagram stream id that is not yet used for any other media stream.

The origin field in the name identifies the Origin server for which this 
subscrption is targetted.  `name` identified the fully formed
name or wildcarded name along with the approporiate bitmask length.

The `intent` field specifies how the Relay Function should provided the
named objects to the client. Following options are defined for 
the `intent` 

- immediate: Deliver any new objects it receives that match the name 

- catch_up: Deliver any new objects it receives and in addition send any previous
objects it has received that matches the name.

- wait_up: Wait until an object that has a objectId that matches the name is
received then start sending any objects that match the name.


#### Aggregating Subscriptions

Subscriptions are aggregated at entities that perform Relay Function. 
Aggregating subscriptions helps reduce the number of subscriptions 
for a given named object in transit and also enables efficient 
disrtibution of published media with minimal copies between the 
client and the origin server, as well as reduce the latencies when 
there are multiple subscribers for a given named object behind a 
given cloud server.

#### Wildcarded Names

The names used in `subscribe` can be truncated by skipping the right 
most segments of the name that is application specific, in which case it 
will act as a wildcard subscription to all names that match the provided 
part of the name. The same is indicated via bitmask associated 
with the name in `subscribe` messages. Wildcard search on Relay(s) thus
turns into a bitmask at the appropriate bit location of the hashed name. 

### SUBSCRIBE_REPLY Message

A `SUBSCRIBE_REPLY` provides result of the subsciption.

```
enum reponse 
{
  ok(0),
  expired(1)
  fail(2),
  redirect(2)
}

quicr_subscribe_reply
{
    Response response
    [Reason Phrase Length (i)=,
    [Reason Phrase (..)],
}
```

A reponse of `ok` indicates successful subscription, for `failed` 
or `expired` reponses, "Reason Phrase" shall be populated 
with appropriate reason. An reponse of `redirec` informs 
the client that relay shall no longer is serving the subscriptions
and client should retry to the alternate relay provided in the
redirect message.


### PUBLISH_INTENT Message. 

The `publish_intent` message indicates the names chosen by a Publisher 
for transmitting named objects within a session. This message is sent to 
the Origin Server whenever a given publisher intends to publish on 
a new name (which can be at the beginning of the session or during mid session). 
This message is authorized at the Origin server and thus requires a mechanism 
to setup the initial trust (via out of band) between the publisher and 
the origin server.

```
quicr_publish_intent_message { 
 *     message_type(i),
 *     name_length(i),
 *     name(...)
 *     datagram_capable(i)
 * }
```
The message type will be set to PUBLISH_INTENT (6).
The `datagram_capable` flag is set to 0 if the client can only 
publish/post data in stream mode, to 1 if the client is also capable 
of posting media fragments as datagrams.


 On a successful validation at the Origin server, a 
 `publish_intent_ok` message is returned by the Origin server. 
 The `publish_intent_ok` message is sent in response to the PUBLISH_INTENT message, on the server side of the QUIC control stream. This message indicates the publisher is authorized for using the intended name provided in the `PUBLISH_INTENT` message.

```
quicr_publish_intent_ok_message { 
  *     message_type(i),
  *     use_datagram(i),
  *     [datagram_stream_id(i)]
}
```

The message id is set to PUBLISH_INTENT_OK (7). The `use_datagram` flag is set to 0 if the server wants to receive data in stream mode, and to 1 if the server selects to
receive data fragments as datagrams. In that case, the server must select a
datagram stream id that is not yet used to receive any other media stream.

This message enables cloud relays to know the authorized names from a 
given Publisher. This helps to make caching decisions, deal with collisions 
and so on. 
 
 `A>A cloud relay could start caching the data associated with the names that has 
 not been validated yet by the origin server and decide to flush its cache 
 if no PUBLISH_INTENT_OK is received within a given implementation defined
 timeout. This is an optimization that would allow publishers to start 
 transmitting the data without needing to wait a RTT.`

### Start Point Message
 
The Start Point message indicates the begin of message to be sent for 
the media. They correspond to Group ID and Object ID of the first object 
that will be sent for the media. It may be sent by the server that received a SUBSCRIBE message, or by the client that sent a PUBLISH_INTENT message. 
This message is optional: by default, media streams start with Group ID and 
Object ID set to 0.

```
 * quicr_start_point_message {
 *     message_type(i),
 *     start_group_id(i),
 *     start_object_id(i)
 * }
```

The message id is set to START_POINT (8). 

### Fragment Message

The Fragment message is used to convey the content of a media stream as a series
of fragments:

```
quicr_fragment_message {
 *     message_type(i),
 *     group_id(i),
 *     object_id(i),
 *     offset_and_fin(i),
 *     length(i),
 *     data(...)
 }
```

The message type will be set to FRAGMENT (5). The `offset_and_fin` field encodes
two values, as in:
```
offset_and_fin = 2*offset + is_last_fragment
```

The flag `is_last_fragment` is set to 1 if this fragment is the last one of an object.
The offset value indicates where the fragment data starts in the object designated by `group_id` and `object_id`. Successive messages
are sent in order, which means one of the following three conditions must be verified:

* The group id and object id match the group id and object id of the previous fragment, the
  previous fragment is not a `last fragment`, and the offset
  matches the previous offset plus the previous length.
* The group id matches the group id of the previous message, the object id is equal to the object id of the previous fragment plus 1, the offset is 0, and
  the previous message is a `last fragment`.
* The group id matches the group id of the previous message plus 1, the object id is 0, the offset is 0, and the previous message is a `last fragment`.

NOTE: yes, this is not optimal. Breaking the objects in individual fragments is fine,
  but the group ID, object ID and offset could be inferred from the previous fragments.
  The message could be simplified by carrying just two flags, "is_last_fragment" and
  "is_fist_of_group". A Start Point message could be inserted at the beginning of the
  stream to indicate the initial value of group ID and object ID. Doing that would remove
  6 to 8 bytes of overhead per message.

### Fin Message

The Fin message indicates the final point of a media stream. 

```
 * quicr_fin_message {
 *     message_type(i),
 *     final_group_id(i),
 *     final_object_id(i)
 * }
```

The message type will be set to FIN (3). The final `group_id` is set to the `group_id` of the last fragment sent. The final `object_id` is set to the 
object_id of the last fragment sent, plus 1. This message is not sent when 
fragments are sent on stream.


### SUBSCRIBE_CANCEL Message

A `SUBSCRIBE_CANCEL` message indicates a given subscription is no 
longer valid. This message is an optional message and is sent to indicate 
the peer about discontinued interest in a given named data. 

name_length(i),
 *     name(...)

```
 * quicr_fin_message {
 *     message_type(i),
 *     name_length(i),
 *     name(...)
 *     Reason Phrase Length (i),
 *     Reason Phrase (..),
 * }
```

### RELAY_REDIRECT MESSAGE

`RELAY_REDIRECT` message enables relay failover scenarios that is sent 
in response to PUBLISH, PUBLISH_INTENT and SUBSCRIBE messages indicating the new relay to the clients.

```
quicr_relay_redirect
{
  relay_address_length(i),
  relay_address(...)
}
```

## Sending Media as Datagrams

If transmission as datagram is negotiated, the media fragments are sent as
QUIC Datagram frames.

### Datagram Header

The datagram frames are encoded as a datagram header, followed by the bytes in
the fragment:

```
datagram_frame_content {
    datagram_header,
    datagram_content
}
```


The datagram header is defined as:

```
 * quicrq_datagram_header { 
 *     datagram_stream_id (i),
 *     group_id (i),
 *     object_id (i),
 *     offset_and_fin (i),
 *     best_before(i),
 *     flags (8),
 *     [nb_objects_previous_group (i)]
 * }

 flags := Reserved (3) | IsDiscardable (1) | Priority (3)

```

The datagram_stream_id identifies a specific media stream. The ID is chosen by the receiver of the media stream, and conveyed by the Request or Accept messages.

The `offset_and_fin` field encodes two values, as in:
```
offset_and_fin = 2*offset + is_last_fragment
```

The `flags` idenitifes the relative `priority` of this object and if the object
can be discarded. This can help Relay to make  dropping/caching decisions.

The `nb_objects_previous_group` is present if and only if this is the first fragment of the first object in a group, i.e., `object_id` and `offset` are both zero. The number indicates how many objects were sent
in the previous groups. It enables receiver to check whether all these objects have been received.

Relays may forward fragments even if they arrive out of order.

## Fragmentation and Reassembly

Application data may need to be fragmented to fit the underlying transport 
packet size requirements. QuicR protocol is responsbile for performing necessary 
fragmentation and reassembly. Each fragment needs to be small enough to 
send in a single transport packet. The low order bit is also a Last 
Fragment Flag to know the number of Fragments. The upper bits are used 
as a fragment counter with the frist fragment starting at 1.
The `FRAGMENT_ID` with in the `PUBLISH` message identfies the individual
fragments.
