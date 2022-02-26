

# Introduction

Interactive realtime applications, such as web conferencing systems,
require ultra low latency (< 150ms). Such applications create their own
application specific delivery network over which latency requirements
can be met. Realtime transport protocols such as RTP provide the basic
elements needed for realtime communication, both contribution and
distribution, while leaving aspects such as resiliency and congestion
control to be provided by each application.

On the other hand, media streaming applications are much more tolerant
to latency and require highly scalable media distribution. Such
applications leverage existing CDN networks, used for optimizing web
delivery, to distribute media in common video streaming applications.

Recently new use cases have emerged requiring higher scalability of
delivery for interactive realtime applications and much lower latency
for streaming applications and a combination thereof. On one side are
use cases such as normal web conferences wanting to distribute out to
millions of viewers and allow any of those viewers to instantly move to
being a presenter. On the other side are uses case such as steaming a
soccer game to millions of people including people in the stadium
watching the game live. Viewers watching an e-sports event want to be
able to comment with low latency between the live play to ensure the
interactivity aspects
by having low latency between what different viewers are seeing. All
of these uses cases push towards latencies that are in the order of
100ms over the natural latency the network causes.

This document outlines a unified architecture for data delivery that
enables a wide range of realtime applications with different resiliency
and latency needs. The architecture defines and uses QuicR, a delivery
protocol that is based on a publish/subscribe metaphor where client
endpoints publish and subscribe to named objects that is sent to, and
received from, relays that forms an overlay delivery network similar to
what CDN provides today. QuicR is pronounced something close to
“quicker” but with more of a pirate "arrrr" at the end.

The subscribe messages allow subscription to a name that includes a
wildcard to match multiple published names, so a single subscribe can
allow a client to receive publishes for a wide class of named objects.

A typical use case is an interactive communication application,
e.g. video conferencing, where each endpoint in the conference
subscribes to the media from the participants in the conference and at
the same time publishes its own media. The cloud device that receives
the subscriptions and distributes media is called a Relay and is similar
to an application-independent SFU in the audio/video conferencing uses
cases and similar to a CDN cache node in traditional streaming.

The Relays are arranged in a logical tree where, for a given application,
there is an origin Relay at root of the tree that controls the
namespace. Publish messages are sent towards the root of the tree and
down the path of any subscribers to that named data.

The QuicR protocol takes care of transmitting named objects from the
Publisher to the Relay and from the Relay to all the subscribers of the
named object. It provides transport services selected and tuned based on
application requirements (with the support of underlying transport,
where necessary) such as detecting available bandwidth, fragmentation
and reassembly, resiliency, congestion control and prioritization of
data delivery based on data lifetime and importance of data. It is
designed to be NAT and firewall traversal friendly and can be fronted
with load balancers. Objects are named such that it is unique for the
relay/delivery network and scoped to an application. Subscriptions can
include a form of wildcarding to the named object.

The design supports sending media and other named objects between a set
of participants in a game or video call with under a hundred
milliseconds of latency and meets the needs of web conferencing
systems. The design can also be used for large scale streaming to
millions of participants with latency ranging from a few seconds to
under a  hundred milliseconds based on applications needs. It can
also be used as low latency publish/subscribe system for real time
systems such as messaging, gaming, and IoT.

In the simplest case, a web conferencing application could use a single
relay to forward packets between users in a video conference. However a
more typical scenario would have a delivery network made of multiple
relays spread across several points of presence. QuicR is designed to
make it easy to implement relays so that fail over could happen between
relays with minimal impact to the clients and relays can redirect a
client to a different relay.

# Contributing

All significant discussion of development of this protocol is in the
GitHub issue tracker at: ```
https://github.com/fluffy/draft-jennings-moq-arch ```

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

# QuicR relationship to existing streaming standards

As its evident, QuicR and its architecture uses similar concepts and
delivery mechanisms to those used by streaming standards such as HLS and
MPEG-DASH. Specifically the use of a CDN-like delivery network, the use
of named objects and the receiver-triggered media/data delivery. However
there are fundamental characteristics that QuicR provides to enable
ultra low latency delivery for interactive applications such as
conferencing and gaming.

* To support low latency the granularity of the delivered objects, in
  terms of time duration, need to be quite small making it complicated
  for clients to request each object individually. QuicR uses a publish
  and subscription semantic along with a wildcard name to simplify and
  speed object delivery.

* Certain realtime applications operating in ultra low latency mode
  require objects delivered as and when they are available without
  having to wait for previous objects that have not yet been delivered
  due to network loss or out of order network delivery. QuicR supports
  Quic datagrams based object delivery for this purposes. Note that
  QuicR also allows for both Quic datagram and stream usages based on
  the application's latency/quality requirements.

* QuicR supports resiliency mechanisms that are more suitable for
  realtime delivery such as FEC and selective retransmission.

* Quic's current congestion control algorithms need to be evaluated for
  efficacy in low latency interactive real-time contexts specially when
  it comes to mechanisms such as slow start and multiplicative
  decrease. Based on the results of the evaluation work, QuicR can
  select the congestion control algorithm suitable for the application's
  class.

* Published objects in QuicR have associated max-age that specifies the
  validity of such objects. max-age influences relay's drop decisions
  and the used by the underlying Quic transport to cease retransmissions
  associated with the named object.

* Unlike streaming architectures where media contribution and media
  distribution are treated differently, QuicR can be used for both
  object contribution/publishing and distribution/subscribing as the
  split does not exist for interactive communications.

* QuicR supports "aggregation of subscriptions" to the named objects
  where the subscriptions are aggregated at the relay functions and
  allows "short-circuited" delivery of published objects when there is a
  match at a given relay function.

* QuicR allows publishers to associate a priority with
  objects. Priorities can help the delivery network and the subscribers
  to make decisions about resiliency, latency, drops etc. Priorities can
  used to set relative importance between different qualities for
  layered video encoding, for example.

* QuicR is designed so that objects are encrypted end-to-end and will
  pass transparently through the delivery network. Any information
  required by the delivery network, e.g priorities, will be included as
  part of the metadata that is accessible to the delivery network for
  further processing as appropriate.

# Architecture

## Components

### QuicR Delivery Network Architecture via Origin and No Relay functions
!--
~~~ascii-art
                                           Publisher: quicr://twitch.com/channel-1/video/hi-res/...
                                           Publisher: quicr://twitch.com/channel-1/video/med-res/...
                                           ...                        *
               ┌──────────────────────────────────────────────────────*──────────────────────┐
               │             Subscribe                                *                      │
               │ quicr://<ingest-server>/streams/*        ┌───────────*─────────────────┐    │
               │       ┌───────────────────────┐          │                             │    │
               │       │     ingest-server     │          │   distribution-server       │    │
          ┌────┤       │      [Subscriber]     ├──────────▶      [Publisher]            │    │
          │    │       └───────────────────────┘          └──────┬──────────────────────┘    │
          │    └─────────────────────────────────────────────────┼───────────────┼───────────┘
          │                                                                      │
  Publish:                                  Pub:
  quicr://<ingest-server>                   quicr://twitch.com/channel-1/      Sub:quicr://twitch.com/ch
  /stream123                                video/hi-res/group1/obj12          annel-1/video/hi-res/*
                                            Pub: quicr://...
          │                                 Pub: quicr://...                     │
          │                                                                      │
          │                                                      │               │
          │                                                      ▼               │
┌───────────────────┐                                       ┌───────────────────────────────┐
│┌────────────────┐ │                                       │         Subscriber            │
││    Streamer    │ │                                       │                               │
││  [Publisher]   │ │                                       └───────────────────────────────┘
│└────────────────┘ │
└───────────────────┘

~~~
Figure: Pub/Sub via Origin (No relay)
!--

### QuicR Delivery Network Architecture via Relay delivery network

!--
~~~ascii-art
 
                                       ┌───────────────────────┐
                                       │                       │
                                       │    Origin [Relay]     │
                                       │ [quicr://meeting.com/ │
                                    ┌─▶│     meeting123..]     │◀──────────┐
                                    │  │                       │           │
                                    │  │                       │           │
             pub-1: hi-res  video   │  └───────────────────┬───┘           │     sub:
             pub-2: low-res video   │                                      │ alice/video/*
                                    │            pub: alice, high-res      │
                                    │            pub: alice, low-res       │
                                    │                                      │
                                    │                      │               │
                      ┌─────────────┴──────────┐           │    ┌─────────────────┐             sub:
                      │                        │           │    │                 │◀─────── alice/video/*
             ┌───────▶│         Relay-B        │           └───▶│    Relay-B      │
             │        │                        │                │                 ├────┐          │
             │        └────────────────────────┘                └─┬─────────▲─────┘    │          │
             │                     │         ▲                    │                    │          │
 pub-1: hi-re│  video              │                                  sub:alice/v                 │
 pub-2: low-r│s video                     sub: alice,   pub: alice,      deo/*     pub: alice,    │
             │            pub: alice,    hi-res video    high-res,                  high-res,     │
             │           hi-res video                     low-res                    low-res      │
             │                               │                              │                     │
             │                     │         │                    │         │          │          │
             │                     ▼         │                    ▼         │          ▼          │
      .─────────────.             .──────────┴──.             .─────────────.         .─────────────.
   ,─'               '─.       ,─'               '─.       ,─'               '─.   ,─'               '─.
  (        Alice        )     (         Bob         )     (        Carl         ) (        Derek        )
   `──.             _.─'       `──.             _.─'       `──.             _.─'   `──.             _.─'
       `───────────'               `───────────'               `───────────'           `───────────'

~~~
Figure: Pub/Sub with relay delivery network
!--

Above diagram shows the various components/roles making the QuicR
architecture and how it can be leveraged by two different classes of
applications; a streaming app and a communication app.

TODO: explain the picture including the various components of
publishers, subscribers, origin server

TODO: explain that as the pub go up the tree, they get short circuit
sent to any subscriber on the the relay they traverse. Huge impact to
latency for nearby the producer of the media.

# Names and Named Objects

Names are basic elements with in the QuicR architecture and they
uniquely identify objects. Named objects can be cached in relays in a
way CDNs cache resources and thus can obtain similar benefits such
caching mechanisms would offer.

## Objects Groups

Objects with in QuicR belong to a group. A group (a.k.a group of
objects) represent an independent composition of set of objects, where
there exists dependency relationship between the objects within the
group. Groups, thus can be independently consumable by the subscriber
applications.

A typical example would be a group of pictures/video frames or group of
audio samples that represent synchronization point in the video
conferencing example.


## Named Objects


The names of each in QuicR are composed of following components:

1. Domain Component
2. Application Component
3. Group ID Component
4. Object ID Component 

!--
~~~ascii-art
   48 bits          48 bits            32 bits
┌─────────────┬────────────────────┬───────────────┐
│     Domain  │    Application     │ Object Group  │
│   Component │     Component      │   Component   │
└─────────────┴────────────────────┴──────┬────────┘
                               ┌──────────┤
                               │          └──────────┐
                               ▼                     ▼
                     ┌───────────────────┐ ┌───────────────────┐
                     │       Group       │ │       Object      │
                     │     Identifier    │ │     Identifier    │
                     └───────────────────┘ └───────────────────┘
                            16 bits               16 bits
~~~
Figure: QuicR Name
!--

Domain component uniquely identifies a given application domain. This is
like a HTTP Origin and uniquely identifies the application and a root
relay function. This is a DNS domain name or IP address combined with a
UDP port number mapped to into the domain. Example: sfu.webex.com:5004.

Application components are scoped under a given Domain. This
component identifies aspects specific to a given application instance
hosted under a given domain (e.g.meeting identifier, which movie or
channel, media type or media
quality identifier).

Inside each Application Component, there is a set of groups. Each
group is identified by a monotonically increasing integer. Inside of
each Group, each object is identified by another monotonically increasing
integer inside that group. The groupID and objectID start at 0 and are
limited to 16 bits long.

Example: In this example, the domain component identifies
acme.meeting.com domain, the application component identifies an
instance of a meeting under this domain, say "meeting123", and high
resolution camera stream from the user "alice". It also identifies the
object 17 under part of the group 15.

```
quicr://acme.meeting.com/meeting123/alice/cam5/HiRes/15/17
```

## Wildcarding with Names

QuicR allows subscribers to request for media based on wildcard'ed
names. Wildcarding enables subscribes to be made as aggregates instead
of object level granularity. Wildcard names are formed by skipping the
right most segments of names.
 
For example, in an web conferencing use case, the client may subscribe
to just the origin and ResourceID to get all the media for a particular
conference as indicated by the example below. The example matches all
the named objects published by alice in the meeting123.

```quicr://acme.meeting.com/meeting123/alice/* ```

When subscribing, there is an option to tell the relay to one of:

A.  Deliver any new objects it receives that match the name 

B. Deliver any new objects it receives and in addition send any previos
objects it has received that are in the same group as the most recently
received group that matches the name.

C. Wait until an object that has a objectiD that matches the name is
received then start sending any objects that match the name.

D. Send the most recent object that matches the name then send any new
objects that match the name. 

## Name Hashes 

All Names need to hash or map down to 128 bits. This allows for:

* compact representation for efficient transmission and storage,

* cache friendly datatypes ( like Keys in CDN caches) for storage and
lookup purposes and,

* enable rapid data lookup at the relays based on partial as well as
whole names ( wildcard support ).

TODO - Suhas - perhaps move the figure here ???

This is done hashing the origin to first 48 bits. Any relay that forms an
connection to an new origin needs to ensure this does not collide with
an existing origin. The application component is mapped to the next 48
bits and it is the responsibility of the application to ensure there are
not collisions within a given origin. Finally the group ID and object ID
each map to 16 bits.

Design Note: It os possible to let each application define the
size theses boundaries as well as sub boundaries inside the application
component but for sake of simplicity it is described as fixed boundaries
for now.

Wildcard search simply turn into a bitmask at the approbate bit location
of the hashed name. 

The hash names are key part of the design for allowing small objects
without adding lots of overhead and for effecent implementation of
Relays. 

# Objects

Once a named object is created, the content inside the named object can
never be changed. Objects have an expiry time after which they should be
discarded by caches. Objects have an priority that the relays and
clients can use to sequence which object to send first. The data inside
an object is end to end encrypted with keys which are not available to
Relay.

# Relays

The relays receive subscriptions and intent to publish request and
forward them towards the origin Relay. This may send the messages
directly to the Origin Relay or possibly traverse another Relay. Replies
to theses message follow the reverse direction of the request and when
the Origin gives the OK to a subscription or request to publish, the
Relay allows the subscription or future publishes to the Name in the
request.

Subscription received are aggregated. When a relay receives a publish
request with data, it will forward it both towards the Origin and to any
clients or relays that have a matchin subscription. This "short
circuit" of distribution by a relay before the data has even reached the
Origin servers provides significan latency reduction for nearby client.

The Relay keeps an outgoing queue of objects to be sent to the each
subscriber and objects are sent in priority order.

Relays MAY cache some of the information for short period of time and
the time cached may depend on the origin.

# QuicR Usage Design Patterns

This section explains design patters that can be use to build
applications on top of QuicR.

##  QuicR Manifest Objects

Names can be optionally discovered via manifests. In such cases, the
role of the manifest is to identify the names as well as aspects
pertaining to the associated data in a given usage context of the
application.

* Typically a manifest identifies the domain and application aspects for
  the set of names that can be published.

* The content of Manifest is application defined and end to end
  encrypted.

* The manifest is owned by the application's origin server and are
  accessed as a protected resources by the authorized QuicR clients.

* The QuicR protocol treats Manifests as a named object, thus allowing
  for clients to subscribe for the purposes of bootstrapping into the
  session as well as to follow manifest changes during a session
  [ new members joining a conference for example].

* The manifest has well known name on the Origin server.

* The manifest would typically be a a group and new version of it could
  be published with an incremented ObjectID.  Subscriptions of the group
  would get the latest copy of the manifest. 

Also to note, a given application might provide non QuicR mechanisms to
retrieve the manifest. 

## QuicR Video Objects

Most video applications would use the application component et to identity
which videos stream it was as well as the encoding point such as
resolution and bit rate. Each independent decode set of frames would go
in a single group, and each frame inside that group would go in a
separate named object inside the group. The allows an application to
review a given encoding of the video by subscribing to the applications
component with a wildcard for group and object IDs. 

This allows a subscription to get all the frame in the current group if
it joins lates, or wait till the group before starting to get data based
on the subscription options. Changing to a different bitrate or
resolution would use a a new subscripting to the appropriate

The QUIC transport that QuicR is running on provides the congestion
controll but the application and see what objects are received and
determin if it should change it's subscription to a different bitrate
application component. 

Todays video is often encoded with I frames at a fixed internal but this
can result in pulsing video quality. Future system may want to insert I
frames at each change of scene resulting in groups with a variable
number of frames. QuicR easily supports that. 

## QuicR Audio Objects

Each small chuck of audio, such as 10 ms, can be put its own Object.

Future sub 2 kbps audio codecs may take advantage of a rapidly
updated model that are needed to decode the audio which could result in
audio needing to use groups like video does to ensure all the objects
needed to decode some audio are in the same group. 

## QuicR Game Moves Objects

Some game send out a base set of state information then incremental
deltas to this. Each time a new base set is sent, a new group can be
formed and each increment change as an Object in the group. When new
players join, they can subscribe to get the current group and all the
incremental changes to it.

## Messaging Objects

Chat applications and messaging system can form a manifest representing
the roser of the people in a given channel or talk room. The manifest
can provide the an applications component for each user than
contributes messages. A subscription to each applications component can
receive each new message. Each message would be a single
object. Typically QuicR would be use to get the recent messages and then
a more traditional HTTP CDN approach could be used to retrieve copies of
all the older objects.



# Security Considerations

The links between Relay and other Relays or Clients can be encrypted,
this does not protect the content form Relays. To mitigate this all the
objects need to be end to end encrypted with a keying mechanism outside
the scope of this protocol. For may applications, simp;y getting the
keys over HTTPS for a particular object from the origin server will be
adequate. For other applicants keying based on MLS may be more
appropriate. Many applications can leverage the existing key managed scheme
used in HLS and DASH for DRM protected content.

Relays reachable on the internet are assumed to bave a bustiness
relationship with teh Origin and the protocol provides a way to verify
that any data moved is on behalf of a give Origin. 

Relays in a local network may choose to process content for any Origin
but since only local users can access them, their is a way to mange
which applications use them.

Subscriptions need to be refreshed at least ever 5 seconds to ensure
liveness and consent for the client to continue receiving data.


# Protocol Design Considerations

## HTTP/3

It is tempting to base this on HTTP but there are a few high level
architectural mismatches. HTTP is largely designed for a stateless
server in a client server architecture. The whole concept of the PUB/SUB
is that the relays are *not* stateless and keep the subscription
information and this is what allows for low latency and high throughput
on the relays. In todays CDS, the CDN nodes end up faking the
credentials of the origin server and this limites how and where they can
be a deployed. A design with explicitly designed relays that do not need
to do this, while still assuming an end to end encrypted model so the
relayes did not have access to the content makes for a better design. 

It would be possible to start with something that looked like HTTP as
the protocol between the relays with special conventions for wild cards
in URLs of a GET and ways to stream non final responses for any
responses perhaps using something like multipart MINE. However, most of
the existing code and logic for HTTP would not really be usable with the
low latency streaming of data. It is probably much simpler and more
scaleable to simply define a PUB/SUB protocol directly on top of QUIC.

## QUIC Streams and Datagrams

There and pro and cons to mapping object transport on top of streams or
on top of QUIC datagrams. The working group would need to sort this out
and consider the possibility of using both for different types of data
and if there should be support for a semi-reliable transport of
data. Some objects, for example the manifest, you nearly always want to
receive in a reliable way while other objects have to be realtime.

## QUIC Congestion Control

The basic idea in BBR of speeding up to probe then slowing down to drain
the queue build up caused during probe can work fine with real time
applications. However the the current implementations in QUIC do not
seem optimized for real time applications and have some time where the
slow down causes too much jitter. To not have payout drop, the jitter
buffers add latency to compensate for this. Probing for the RTT has been
one of the phases that causes particular problems for this. To reduce
the latency of QUIC, this work should coordinate with the QUIC working
group have have the QUIC working group develop congestion control
optimizations for low latency use of QUIC.

## Why not RTP

TODO - add Mo's points: The problem of stored formats vs RTP payload
formats. The what does RTP get you. The problem that RTP is an gateway
drug to SDP and friends done't let friends try to debug SDP.

