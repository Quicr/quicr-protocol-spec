# Introduction

Recently new usecases have emerged requiring higher scalability of
delivery for interactive realtime applications and much lower latency
for streaming applications and a combination thereof. On one side are
use cases such as normal web conferences wanting to distribute out to
millions of viewers and allow viewers to instantly move to
being a presenter. On the other side are usescases such as streaming a
soccer game to millions of people including people in the stadium
watching the game live. Viewers watching an e-sports event want to be
able to comment with low latency to ensure the interactivity aspects
between what different viewers are seeing. All of these usescases 
push towards latencies that are in the order of 100ms over the 
natural latency the network causes.

The architecture for this specificaiton is outlines in
draft-jennings-moq-arch and this specification does not make sense
without first reading that.
Client endpoints publish and subscribe to named objects that is sent to, and
received from, relays that forms an overlay delivery network similar to
what CDN provides today.

# Contributing

All significant discussion of development of this protocol is in the
GitHub issue tracker at: ```
https://github.com/fluffy/draft-jennings-moq-proto ```

# Terminology

* Relay Function: Functionality of the QuicR architecture, that
  implements store and forward behavior at the minimum. Such a function
  typically receives subscriptions and publishes data to the other
  endpoints that have subscribed to the named data. Such functions may
  cache the data as well for optimizing the delivery experience.

* Relay: Server component (physical/logical) in the cloud that
  implements the Relay Function.

* Publisher: An endpoint that sends named objects to a
  Relay. [ also referred to as producer of the named object]

* Subscriber: An endpoint that subscribes and receives the named
  objects. Relays can act as subscribers to other relays. Subscribers
  can also be referred to as consumers.

* Client/QuicR Client: An endpoint that acts as a Publisher, Subscriber,
  or both. May also implement a Relay Function in certain contexts.

* Named Object: Application level chunk of Data that has a unique Name,
  a limited lifetime, priority and is transported via this protocol.

* Origin server: Component managing the QuicR namespace for a specific
  application and is responsible for establishing trust between clients
  and relays. Origin servers can implement other QuicR functions.

# QuicR Protocol
## Publish API and PUBLISH  Message

Entities the want to send named objects will use Publish API to 
trigger `PUBLISH` messages from a QuicR client to Origin server
(via Relay(s) if present). The publish message identies active flow 
of named objects, such a data can be originating from a given QuicR 
endpoint client or a might be relayed by other entities. In the latter 
case, the relaying entitiy MUST NOT change the name associated with 
the object being published unless the intermediary is a publisher.
All the publishes MUST be authorized.
 
TODO Add details end to end integrity protected and e2ee protected 
parts of the message 

In general, the Publish API specifices following thing about 
the named objects being published.

```
  NAME           (String)
  RELIABLE       (Boolean)
  PRIORITY       (Enumeration)
  BESTBEFORE     (Number)
  TIMESTAMP      (Number)
  DISCARDABLE    (Boolean)
  Payload        (Bytes)
```

__NAME__: Every `PUBLISH` message MUST have a name to identify the 
object to the QuicR components (relays/origin-server/other clients). 

__PAYLOAD__: End-to-End encrtpyted application data assciated with 
the named object to be published (e.g audio sample, video frame, 
game move), which are typically timestamped buffers of application data. 

__RELIABLE__: Boolean flag to indicate the if QuicR should use 
QUIC Streams (true value) or QUIC datagrams (false value).

__BESTBEFORE__:  Time to live defines the time after which the named 
object can be discarded from the caches.

__PRIORITY__: Enumeration specifying relative priority of named objects 
being published by this end-point. This can help Relay to make 
dropping/caching decisions.

__DISCARDABLE__: Provides an hint to the relays for making drop decisions.


The QuicR `PUBLISH` message(s) are represented as below and 
are encapsulated in QUIC packets.

`A> All the integer fields are variable length encoded`
```
PUBLISH {
  ORIGIN            (String) 
  NAME              (Number128)
  FLAGS             (Byte)
  FRAGMENT_ID       (Number16)
  BESTBEFORE        (Number64)
  TIMESTAMP         (Number64)
  Payload           (ByteArray)
}

Flags := Reserved (3) | IsDiscardable (1) | Priority (3)
```

## Subscribe API and SUBSCRIBE Message

Entities that intend to receive named objects will do so via 
subscriptions to the named objects. The Subscribe API triggers 
sending `SUBSCRIBE` messages. Subscriptions are sent from 
the QuicR clients to the origin server(s) (via relays, if present) 
and are typically processed by the relays. See {#relay_behavior} 
for further details. All the subsriptions MUST be authorized.
 
Subscriptions are typically long-lived transcations and they stay 
active until one of the following happens 

   - a client local policy dictates expiration of a subscription.
   - optionally, a server policy dicates subscription expiration.
   - the underlying transport is disconnected.

When an explicit indication is preferred to indicate the  expiry of 
subscription, it is indicated via `SUBSCRIPTION_EXPIRY` message.

While the subscription is active for a given name, the Relay(s) 
should send named objects it receives to all the matching subscribers. 
A QuicR client can renew its subscrptions at any point by sending a 
new `SUBSCRIBE` message to the origin server. Such subscriptions 
MUST refresh the existing subscriptions for that name. A renewal
period of 5 seconds is RECOMMENDED.

```
SUBSCRIBE {
  ORIGIN             (String) 
  SUBSCRIPTION_ID    (Number64) 
  NAMES              [NAME..]
  INTENT             [Enumeration] 
}

NAME {
 name               [Number128]
 mask               [Number7]
}

```

The `ORIGIN` field identifies the Origin server for which this 
subscrption is targetted. `SUBSCRIPTION_ID` is a randomly chosen
to identify the subscription by a given client and is
local to the client's session. `NAMES` identify the fully formed
names or wildcarded names along with the approporiate bitmask length.

The `INTENT` field specifies how the Relay should provided the
named objects to the client. Following options are defined for 
the `INTENT` 

IMMEDIATE: Deliver any new objects it receives that match the name 

CATHCH_UP: Deliver any new objects it receives and in addition send any previous
objects it has received that are in the same group that matches the name.

WAIT_UP: Wait until an object that has a objectId that matches the name is
received then start sending any objects that match the name.

MOST_RECENT: Deliver any new objects it receives and in addition send
the most recent object it has received that is in the same group that 
matches the name.


### Aggregating Subscriptions

Subscriptions are aggregated at entities that perform Relay Function. 
Aggregating subscriptions helps reduce the number of subscriptions 
for a given named objects in transit and also enables efficient 
disrtibution of published media with minimal copies between the 
client and the origin server , as well as reduce the latencies when 
there are multiple subscribers for a given named object behind a 
given cloud server.

### Wildcarded Names

The names used in `SUBSCRIBE` can be truncated by skipping the right 
most segments of the name that is application specific, in which case it 
will act as a wildcard subscription to all names that match the provided 
part of the name. The same is indicated via bitmask associated 
with the name in `SUBSRIBE` messages. Wildcard search on Relay(s) thus
turns into a bitmask at the appropriate bit location of the hashed name. 

For example, in an web conferencing use case, the client 
may subscribe to just the origin and meetingID to get all the media for a 
particular conference. 


## PUBLISH\_INTENT and PUBLISH\_INTENT\_OK Message

The `PUBLISH_INTENT` message indicates the names chosen by a Publisher 
for transmitting named objects within a session. This message is sent to 
the Origin Server whenever a given publisher intends to publish on 
a new name (which can be at the beginning of the session or during mid session). 
This message is authorized by the Origin server and thus requires a mechanism 
to setup the initial trust (via out of band) between the publisher and 
the origin server.

 A `PUBLISH_INTENT` message is represented as below:
 
 ```
 PUBLISH_INTENT {
  ORIGIN         [String]
  PUBLISHER_ID   (Number64)
  NAMES          [Number64Array]
 }
 ```

 The `ORIGIN` field is used by the cloud Relays to choose the Origin 
 server to forward the `PUBLISH_INTENT` message.
 
 On a successful validation at the Origin server, a 
 `PUBLISH_INTENT_OK` message is returned by the Origin server. 
 
 ```
 PUBLISH_INTENT_OK {
  PUBLISHER_ID   (Number64)
  NAMES          [Number64Array]
 }
 ```

 This message enables cloud relays to know the authorized names from a 
 given Publisher. This helps to make caching decisions, deal with collisions 
 and so on. 
 
 `A>A cloud relay could start caching the data associated with the names that has 
 not been validated yet by the origin server and decide to flush its cache 
 if no PUBLISH_INTENT_OK is received within a given implementation defined
 timeout. This is an optimization that would allow publishers to start 
 transmitting the data without needing to wait a RTT.`

 TODO add a note on allowing these messages to piggybacked with other 
 messages to avoid RTT mid session when there is an intent to publish new names.

 `A> Names chosen by the publishers MUST be unique with in a given session 
 to avoid collisions. It is upto the application define the necessary rules to 
 ensure the uniqueness constraint. Cloud entities like Relays are agnostic 
 to these rules and handle collisions by either overriding or dropping 
 the associated data.` 

## SUBSCRIBE_REPLY Message

A ```SUBSCRIBE_REPLY``` provides result of the subsciptions. It lists the 
names that were successful in subscrptions and ones that failed to do so.

```
SUBSCRIBE_REPLY
{
    SUBSCRIPTION_ID     (Number64)
    NAMES_SUCCESS       [Number128..]
    NAMES_FAIL          [Numbwe128..]
}
```

Field SUBSCRIPTION_ID MUST match the equivalent field in 
the `SUBSCRIBE` message to which this reply applies.

CJ - I think we probably need some way for the Relay to send a redirect
to PUB, PUB INTENT, and SUB

## SUBSCRIBE_CANCEL Message

A ```SUBSCRIBE_CANCEL``` message indicates a given subscription is no 
longer valid. This message is an optional message and is sent to indicate 
the peer about discontinued interest in a given named data. 

```
SUBSCRIBE_CANCEL
{
    SUBSCRIPTION_ID (Number64)
    Reason       (Optional String)
}
```
Field SUBSCRIPTION_ID MUST match the equivalent field in 
the `SUBSCRIBE` message to which this reply applies. 
The Reason is an optional string provided for application
consumption. `SUBSCRIBE_CANCEL` message implies canceling 
of all the subscriptions for the given SUBSCRIPTION_ID.
  
## Fragmentation and Reassembly

Application data may need to be fragmented to fit the underlying transport 
packet size requirements. QuicR protocol is responsbile for performing necessary 
fragmentation and reassembly. Each fragment needs to be small enough to 
send in a single transport packet. The low order bit is also a Last 
Fragment Flag to know the number of Fragments. The upper bits are used 
as a fragment counter with the frist fragment starting at 1.
The `FRAGMENT_ID` with in the `PUBLISH` message identfies the individual
fragments.

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


# Origin Server 

The Origin server within the QuicR architecture performs the following 
logical roles

CJ - do we need and this next thing ? Lets talk about it

 - NamedDataIndex Server : NameDataIndex is an authorized server for a 
 given Origin and can be a logical component of the Origin server. This 
 component enables discovery, authorization and distribution of names within the 
 QuicR architecture. Names and the associated application specific metadata are 
 distributed via containers called Manifests. See {#Naming} for further detials 
 on names and manifests.

 - Relay Function - Optionally an Origin server can support relay functionality.

 - Application specific functionality that is out of scope for this specification.

# QuicR Manifest

Names can be optionally discovered via manifests. In such cases, the
role of the manifest is to identify the names as well as aspects
pertaining to the associated data in a given usage context of the
application.

* Typically a manifest identifies the domain and application aspects for
  the set of names that can be published.

* The content of Manifest is application defined and end-to-end
  encrypted.

* The manifest is owned by the application's origin server and are
  accessed as a protected resources by the authorized QuicR clients.

* The QuicR protocol treats Manifests as a named object, thus allowing
  for clients to subscribe for the purposes of bootstrapping into the
  session as well as to follow manifest changes during a session
  [ new members joining a conference for example].

* The manifest has well known name on the Origin server.

Also to note, a given application might provide non QuicR mechanisms to
retrieve the manifest. 

Below is a sample manifest for streaming application where a media 
presentation server describes media streams available for 
distribution. For downstream distribution of media data to clients 
with varying requirements, the central server (along with the source) 
generate different quality media representations. Each such quality is 
represented with a unique name and subscribers are made know of 
the same via the Manifest.

```
{
  "liveSessionID" : "jon.doe.music.live.tv",
  "streams: [
      {    
      "id": "1234",
      "codec": "av1",
      "quality": "1280x720_30fps",
      "bitrate": "1200kbps",
      "crypto": "aes128-gcm",
      },
      {    
      "id": "5678",
      "codec": "av1",
      "quality": "3840x2160_30fps",
      "bitrate": "4000kbps",
      "crypto": "aes256-gcm",
      },
      {    
      "id": "9999",
      "codec": "av1",
      "quality": "640x480_30fps",
      "crypto": "aes128-gcm",
      },
  ]
}

```

Given the above manifest, a subscriber who is capable of 4K stream
shall subscribe to the name

`quicr://jon.doe.music.live.tv/video/5678/*`

# QUIC Mapping

## Streams vs Datagrams

Publishers of the named-data can specify the reliability gaurantees that is 
expected from the QUIC transport. Setting of `IS_RELIABLE` flag to true 
enables sending the application data as QUIC streams, otherwise as QUIC Datagrams.

`SUBSCRIBE` for manifest always happens over QUIC Stream. Each new 
`SUBSCRIBE` will be sent on a new QUIC Stream or as QUIC DATAGRAMs 
based on the setting of `IS_RELIABLE` flag.

`PUBLISH` messages per name are sent over their own QUIC Stream or as 
QUIC DATAGRAM based on `IS_RELILABLE` setting. When using QUIC 
streams, all the objects belonging to a group are sent on 
the same QUIC Stream, whereas, different groups are sent in their
own QUIC Streams.

## Congestion Control

Based on the application profile in use, the transport needs to be able to 
choose the appropriate for detecting and adapting to the network congestion. 
A realtime application is more sensitive to congestion and the underlying 
mechanism needs to quickly adapt compared to, say, an application that is 
playing a recorded streaming media for example.

QUIC's congestion control mechanisms needs to be evaluated for efficacy 
real-time contexts. There needs to be way to negotiate the congestion 
control algorithm to be used per connection  to allow algorithms that 
support different workloads.


## Recovery and Error Correction

It is important for the underlying transport to provide necessary error 
recovery mechanisms like retransmissions and possibly a suitable forward 
error correction mechanism. This is especially true for packet loss 
sensitive applications to be resilient against these losses.

QUIC support ACK & Retranmission for QUIC Streams, but just ACKs for 
QUIC DATAGRAMs. To embrace realtime flows, QUIC's receiver-ts and/or 
one-way-delay efforts needs to be evaluated within the context 
of QuicR work.

This work should evaluate support of forward error correction mechanisms for 
QUIC DATAGRAMs at the minimum to allow realtime flows to be resilient under 
losses. The same may be exposed to QUIC Streams as well if deemed necessary.


# QuicR Usages

## Real-time Conferencing Application

This subsection expands on using QuicR as the media delivery protocol for a 
real-time multiparty A/V conferencing applications.

### Naming

Objects/Data names are formed by concatenation of the domain and application 
components. Below provides one possible way to subdivide the application 
component portion of the data names for a conferencing scenario.

* ResourceID: A identifier for the context of a single group session. Is unique 
withthing scope of Origin. The is a variable length encoded 40 bit integer. 
Example: conferences number

CJ - perhaps meetingID would be better that resoruce id

* SenderID: Identifies a single endpoint client within that ResourceID that 
publishes data. This is a variable length encoded 30 bit integer. 
Example: Unique ID for user logged into the origin application.

* SourceID: Identifies a stream of media or content from that Sender. 
Example: A client that was sending media from a camera, a mic, and 
screen share might use a different sourceID for each one. A scalable 
codec with multiple layers or simulcast streams each would use a 
different sourceID for each quality representation. This is a 
variable length encoded 14 bit integer.

CJ - do we need to talk about resoltuions

CJ - we can probably get rid of bit lengths stuff

* MediaTime: Identifies an immutable chunk of media in a stream. 
The TAI (International Atomic Time) time in milliseconds after 
the unix epoch when the last sample of the chunk of media was 
recorded. When formatted as a string, it should be formatted as 
1990-12-31T23-59.601Z with leading zeros. The is a variable length 
encoded 44 bit integer.Example: For an audio stream, this could be 
the media from one frame of the codec representing 20 ms of audio.

CJ - I think we need to talk about video group of frames and object id
stuff. We could probably just get rid of Media time

A conforming name is formatted as URLs like:

``` quicr://domain:port/ResourceID/SenderID/SourceID/MediaTime/ ```


### Manifest

As a prerequisite step, participants exchange their transmit and 
receive capabilities like sources, qualities, media types and so on, 
with application server (can be origin server). This is done 
out-of-band and is not in the scope of QuicR protocol. 

However, as a outcome of this step is generation of the manifest data 
that describes the names, qualities and other information that aid in 
carrying out media delivery with QuicR protocol. This would for example 
setup unique SourceID sub-part of the application component for each media 
source or quality layers or a combination thereof. Similarly the SenderID 
may get mapped from a roster equivalent for the meetng. Also to note, 
for a given meeting, the static sub-part of the application component is 
set to the ResourceID that represents a identifier for that meeting.

A manifest may get updated several times during a session - either due to 
capabilities updates from existing participants or new participants joinings 
or so on.

Participants who wish to receive media from a given meeting in a web conference 
will do so by subscribing to the meeting's manifest. The manifest will list 
the name of the active publishers. 

### API Considerations

CJ - could we get rid of this seciton ?

QuicR client participating in a realtime conference has few options at the 
API level to choose when published data :

* When sending video IDR data, ```IS_SYNC_POINT``` is set to true.
* When sending data for a layer video codec, ```IS_RELIABLE``` option can 
be set to true for certain layers. Also the priority levels between the 
layer may be adjusted to report relative importance.
* Selectively retranmissions can be enbaled based on the importance of 
the data.
*  todo add more flows

### Example 

Below picture depicts a simplified QuicR Publish/Subscribe protocol flow 
where participants exchange audio in a 3-party realtime audio conference.


TODO ADD FIGURE  Realtime Conference   conference.png

In the depicted protocol flow, Alice is the publisher while Bob and Carl 
are the subscribers. As part of joining into the conference, Bob and Carl 
subscribe to the name __quicr://acme.meetings.com/meeting123/*__  to receive 
all the media streams being published for the meeting instance __meeting123__. 
Their subscriptions are sent to Origin Server via a Relay.The Relay aggregates 
the subscriptions from Bob and Carl forwarding one subscribe message. On 
Alice publishing her media stream fragments from a camera source to the 
Origin server, identified via the names 
__quicr://acme.meetings.com/meeting123/alice/cam5/t1000/, the same is 
forwaded to Relay. the relay will in turn forward the same to Alice and Bob 
based on their subscriptions.

Here is another scenario, where Alice has 2 media sources (mic, camera) and 
is able to send 2 simulast streams for video (corresponding to 2 
quality lelves) and audio encoded via 2 different 
codecs, might have different sourceIDs as listed below



```
Source       --> SourceID
------------------------
mic_codec_1  --> audio_opus
mic_codec_2  --> audio_lyra
vid_simul_1  --> video_hi
vid_simul_2  --> video_low

Alice's SenderID -> Alice and she is joining meeting with id 
meeting123

Names that Alice can publish includes:

quicr://acme.meetings.com/meeting123/Alice/audio_opus/...
quicr://acme.meetings.com/meeting123/Alice/audio_lyra/...
quicr://acme.meetings.com/meeting123/Alice/video_hi/...
quicr://acme.meetings.com/meeting123/Alice/video_low/...

```

Manifest encoded as json objects might capture the information as below. 
[This encoded is for information purposes only.]

```
{
    "origin": "acme.meetings.com"
    "meeting": "meeting123",
    publisher {
        id: "Alice",
        source: [
            {
                "type" : "audio",
                "streams": [
                    {
                        "id": "audio_opus,
                        "codec": "opus",
                        "quality": "48khz",
                    }, {
                        "id" : "audio_lyra",
                        ....
                    }
                ]
            }, {
            "type": "video",
            "streams": [
                {
                    "id": "video_hi",
                    "codec:" : "av1",
                    "quality" : "1920x720_60fps"
                },
                {
                    "id": "video_lo",
                    "codec:" : "av1",
                    "quality" : "640x480_30fps"
                }
            ],
            },
        ]
    }
}

```

With the names as above, any subscriber retrieving the manifest has the 
necessary information to send `SUBSCRIBE` for the named data of interest. 
The same happens when the manifest is updated once the session is in progress.


`A>The details on security/trust relationship established between the endpoints,
the relay and the Origin server is ignored from the depiction for simplicity purposes.`


## Push To Talk Media Delivery Application

Frontline communications application like Push To Talk have close semblances 
with the publish/subscribe metaphor. In a typical setup, say a retail store, 
there are mutiple channels (bakery, garden) and retail workers with PTT 
communication devices access the chatter over such channels by tuning into 
them. In a typical use-case, the retails workers might want to tune into one 
or more channels of their interest and expect the media delivery system to 
deliver the media asynchornusly as talk spurts.

In general such a system needs the following:

* A way for the end users to tune to their channels of interest and have 
these interests be longlived transactions.
* A way for system to efficiently distribute the media to all the tuned in 
end users per channel.
* A way for end user to catch up and playback when switching the channels.

### Naming

One can model naming for PTT applications very similar to the design used 
for "Realtime conferencing applications".

A conforming name is formatted as URLs like:

``` quicr://domain:port/ResourceID/SenderID/SourceID/MediaTime/ ```

In the case of PTT, the following mappings can be considered for the 
application subcomponents

* ResourceID - Each PTT channel represents its own high level resource
* SenderID   - Authenticated user's Id who is actively checked in a given 
frontline workspace (ex: retail store)
* MediaTime  - Same as in the case of "Realtime Conferencing Application"

CJ - seems like we need names more like
wallmart.com/store22/ch3/sender5/group/message

CJ - THis is a good example where we might want to wilder car at the
ch3/* level ...


### Manifest

For PTT application, a manifest describes various active PTT channels as 
the main resource.
Subsribers who tune into channels typically get the names from the manifest 
to do so. Publshers publish their media to channels that they are authorized to. 

### Example

An example retail store scenario where users Alice, Bob subscribe to the 
bakery channel and Carl subscribes to the gardening channel. Also an 
annoucement from the store manager Tom, on bakery channel gets 
delivered to Alice and Bob but not Carl.


```

Bakery -> Alice and she is authorized to talk/listen on 
Channel Bakery.
Bob's SenderID -> Bob and he is authorized to talk/listen on 
Channel Bakery.
Carl's SenderID -> carl and he is authorized to talk/listen on 
Channel Gardening.
Tom's SenderID -> Tom and he is authorized to talk/listen on 
channels Bakery and Gardening

Bakery Channel Id -> 1234
Gardening Channel Id -> 5678

```

Manifest encoded as json objects might capture the information as below. 
[This encoded is for information purposes only.]

```
{
    "origin": "retail19012.sjc.acme.com"
    "channel": [
        {
            "name": "bakery",
            "id" : "1234"
        },
        {
            "name": "gardening",
            "id" : "5678"
        },
    ]
}

```
Alice and Bob shall send ```SUBSCRIBE``` to channel Bakery and Carl does 
the same for channel Gardening.

## Low Latency Streaming Applications

A typical streaming application can be divided into 2 halves - media ingest 
and media distribution. Media ingestion is done via pushing one or more 
streams of different qualities to a central server. Media Distribution 
downstream is customized (via quality/rate adapation) per consumer by 
the central server.

One can model ingestion as sending ```PUBLISH``` mesages and the 
associated sources as publishers. Similarly, the consumers/end 
clients of the streaming media ```SUBSCRIBE``` to the media elements 
whose names are defined in the manifest. Manifest describes the 
name and qualities associated with media being published. The central 
severs (Origin) themselves act as publisher for producing streams 
with different qualities.

Streaming use-cases requiring lower latencies and high degree of 
realtime interactivity (chat for example) can fit into QuicR's media 
delivery protocol over the QUIC transport. 

Lower latencies can be achieved by the relay forwarding the data as 
they arrive to the subscribed clients. 

Catch up or quiclk sync can be supported via cache storing fully 
assembled frames along with the same distribting the fragments 
as they come in. This will allow clients to get the sync point 
as well as the data corresponding to the live edge. 

Few sample scenarios that have such constrainsts are listed below:

* Professional streamers (gamers/musicians) interacting with a 
live audience on social media, often via a directly coupled chat 
function in the viewing app/environment.  A high degree of 
interactivity between the performer and the audience is required 
to enable engagement.

* Live Auctions are another category of applications where an 
auction is hroadcasted to serveral participants. The content must be 
delivered with low latency and more importantly within a well-defined 
sync across endpoints so customers trust the auction is fair. 

Visual and aural quality are secondary in priority in these scenarios to 
sync and latency. This in turn increases revenue potential from a 
game/event.

### Naming and Manifest Considerations

For downstream distribution of media data to clients with varying 
requirements, the central server (along with the source) generate 
different quality media representations. Each such quality is 
represented with a unique name and subscribers are made know of 
the same via the Manifest.

```
{
  "resource" : "jon.doe.music.live.tv",
  "streams: [
      {    
      "id": "1234",
      "codec": "av1",
      "quality": "1920x720_60fps"
      },
      {    
      "id": "5678",
      "codec": "av1",
      "quality": "3840x2160_30fps"
      },
      {    
      "id": "9999",
      "codec": "av1",
      "quality": "640x480_30fps"
      },
  ]
}

```
Consumers end points subscribe to one or more names representing the 
quality based on their capabilities. This enables the relay to forward 
the ingested data to be sent as they arrive to the subscribers. 

TODO Manifest need not be as complicated as HLS/DASH support for 
the streaming use-cases supported by QuicR

TODO probably we need to add  a note saying QuicR doesn't replace all 
streaming use-cases


## Virtual/Augmented Reality, Gaming Applications

Applications, such as games or the ones based on virtual reality environment, 
have to need to share state about various objects across the network. This 
involves pariticipants sending small number of objects with state that need 
to be synchronized to the other side and it needs to be done periodically 
to keep the state up to date and also reach eventually consistency under 
losses.

Goals of such applications typically involve
- Support 2D and 3D objects
- Support delay and rollback based synchronization
- Easily extensible for applications to send theirown custom data
- Efficient distribution to multiple users

todo finsih this

# Security

The key tenant of the security is that middles boxes are not trusted any 
more or less than the network. They both needed to be trusted to forward 
packets or the packets don’t arrive but they should not have access to 
data or know which human is communicating with which human. They do 
have a need to understand what applications are using them.

## End to End Encryption

The data transmitted is encrypted and authenticated end to end with 
a symmetric key provided out of band. Each publisher has their 
own key which is distributed to all the subscribers.


## Fronting

A given origin relay may actually simply be fronting other relays 
behind it and effectively doing a NAT style name translation of 
the ResourceID. This allows for TOR like onion routing systems 
help preserve privacy of what participants are communicating.


# TODO

1. Define trust establishment flows between QuicR Endpoints, 
Cloud Relays and the Origin Server. Also add security toke to 
the messages.
2. Messages needs some security considerations - integrity 
protection and so on.
2. Talk more about relay chaining
3. Define constructs for End to End Encryption
4. Fix the notation of the messages
