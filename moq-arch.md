

# Introduction

Interactive realtime applications, such as web conferencing systems, require ultra low latency. Such applications create their own application-specific delivery network over which latency requirements can be met. Realtime transport protocols such as RTP provide the basic elements needed for realtime communication, both contribution and distribution, while leaving aspects such as resiliency and congestion control to be provided by each application.

On the other hand, media streaming applications are much more tolerant to latency and require highly scalable media distribution. Such applications leverage existing CDN networks, used for optimizing web delivery, to distribute media in commone video streaming applications.

Recently new usecases have emerged requiring higher scalability of delivery for interactive realtime applications and much lower latency for streaming applications and a combination thereoff. On one side are usecases such as normal web confernces wanting to distribute out to millions of viewers and allow any of thoses viewers to instanlty move to being a presenter. On the other side are usescase such as steaming a soccer game to millions of people including people in the stadium watching the game live. Viewers watching an e-sports event want to be able to comment with low latency between the live play to ensure the interactivity aspects [by having low latecny between what diffirent viewers are seeing]. All of these uses cases push towards latencies that are in the order of 100ms over the naturual latency the network causes. 

This document outlines a unified architetcure for data delivery that enables a wide range of realtime applications with different resiliency and latency needs. The architecture defines and uses QuicR, a delivery protocol that is based on a publish/subscribe metaphor where client endpoints publish and subscribe to named objects that is sent to, and received from, relays that forms an overlay delivery network similar to what CDN provides today. QuicR is pronounced something close to “quicker” but with more of a pirate "arrrr" at the end.

The subscribe messages allow subscription to a name that includes a wildcard to match multiple published names, so a single subcribe can allow a client to receive publishes for a wide class of named objects. 

A typical usecase is an interactive communication application, e.g. video conferencing, where each endpoint in the conference subscribes to the media from the participants in the conference and at the same time publishes its own media. The cloud device that receives the subscriptions and distributes media is called a Relay and is similar to an application-independent SFU in the audio/video conferncing uses cases and simular to a CDN cache node in traditional streaming. 

The Relays are arranged in a logical tree where for a given application, there is an origin Relay at root of the tree that controls the namespace. Publishe messages are sent towards the root of the tree and down the path of an subscribers to that named data. 

The QuicR protocol takes care of transmitting named objects from the Publisher to the Relay and from the Relay to all the subscribers of the named dobject. It provides transport services selected and tuned based on application requirements (with the support of underlying transport, where necessary) such as detecting available bandwidth, fragmentation and reassembly, resiliency, congestion control and prioritization of data delivery based on data lifetime and importance of data. It is designed to be NAT and firewall traversal friendly and can be upfronted  with load balancers. Objects are named such that it is unique for the relay/delivery network and scoped to an application. Subscriptions can include a form of wildcarding to the named object.

The design supports sending media and other named objects between a set of participants in a game or video call with under a hundred milliseconds of latency and meets the needs of web conferencing systems. The design can also be used for large scale streaming to millions of participants with latency ranging from a few seconds to under a few hundred milliseconds based on applications needs. It can also be used as low latency publish/subscribe system for real time systems such as messaging, gaming, and IoT.

In the simplest case, a web conferencing application could use a single relay to forward packets between users in a video conference. However a more typical scenario would have a delivery network made of multiple relays spread across several points of presence. QuicR is designed to make it easy to implement relays so that fail over could happen between relays with minimal impact to the clients and relays can redirect a client to a different relay.

# Contributing

All significant discussion of development of this protocol is in the GitHub issue tracker at:
```
https://github.com/fluffy/draft-jennings-moq-arch 
```

# Terminology

* Relay Function: Functionality of the QuicR architecture, that implements store and forward behavior at the minimum. Such a function typically receives subscrptions and publishes data to the other endpoints that have subscribed to the named data. Such functions may cache the data as well for optimizing the delivery experience.

* Relay:  Server component (physical/logical) in the cloud that implements the Relay Function.

* Publisher: An endpoint that sends named obejcts to a Relay. [ also referred to as producer of the named object]

* Subscriber: An endpoint that subscribes and receives the named objects. Relays can act as subscribers to other relays. Subscribers can also be referred to as consumers.

* Client/QuicR Client: An endpoint that acts as a Publisher, Subscriber, or both. May also implement a Relay Function in certain contexts.

* Named Object: Application level chunk of Data that has a unique Name, a limited lifetime, priority and is transported via this protocol.

* Origin server: Component managing the QuicR namespace for a specific application and is responsible for establishing trust between clients and relays. Origin servers can implement other QuicR functions.

# QuicR characteristics and its Relationship to existing streaming standards

As its evident, QuicR and its architetcure uses similar concepts and delivery mechanisms to those used by streaming standards such as HLS and MPEG-DASH. Specifically the use of a CDN-like delivery network, the use of named objects and the receiver-triggered media/data delivery. However there are fundamental characteristics that QuicR provides to enable ultra low latency delivery for interactive applications such as conferncing and gaming. 

* To support low latency the granularity of the delivered objects ,in terms of time duration, need to be quite small making it complicated for clients to request each object individually. QuicR uses a publish and subcription semantic along with a wildcarded naming to simplify and speed object delivery. 

* Certain realtime applications operating in ultra low latency mode require objects delivered as and when they are avaiable without having to wait for previous objects that have not yet been delivered due to network loss or out of order network delivery. QuicR supports Quic datagrams based object delivery for this purposes. Note that QuicR also allows for both Quic datagram and stream usages based on the application's latency/quality requirements.

* QuicR supports resiliency mechanisms that are more suitable for realtime delivery such as FEC and selective retransmission. 

* Quic's current congestion control algorithms need to be evaluated for efficacy in low latency interactive real-time contexts specially when it comes to mechanisms such as slow start and multiplicative decrease. Based on the results of the evaluation work, QuicR can select the congestion control algorithm suitable for the application's class.

* Published objects in QuicR have associated max-age that specifies the validity of such obejcts. max-age influences relay's drop decisions and the used by the underlying Quic transport to cease retransmissions associated with the named object.

* Unlike streaming architectures where media contribution and media distribution are treated differently, QuicR can be used for both object contribution/publishing and distribution/subscribing as the split does not exist for interactive communications.  

* QuicR supports "aggregation of subscriptions" to the named objects where the subscriptions are aggregated at the relay functions and allows "short-circuited" delivery of published objects when there is a match at a given relay function.

* QuicR allows publishers to associate a priority with objects. Priorities can help the delivery network and the subscribers to make decisions about resiliency, latency,drops etc. Priorities can used to set relative importance between different qualities for layered video encoding, for example.

* QuicR is designed so that objects are encrypted end-to-end and will pass transparently through the delivery network. Any information required by the delivery network, e.g priorities, will be included as part of the metadata that is accessible to the delivery network for further processing as appropriate.

# Architecture

## Problem Space

[To Do] Need work

This architetcure is designed for applications such as video communication systems, video streaming systems, games systems, multiuser AR/VR applications, and IoT sensor that produce real time data. It is designed for endpoints with between 0.1 and 10 mbps connection to the Internet that have a need for real time data transports. The main characteristic of real time data is that it is not useful if it is takes longer than some fixed amount of time to deliver. 

The client can be behind NATs and firewalls and will often be on a WIFI for cellular network. The Relays need to have a public IP address, or at least an IP address reachable by all the clients they serve, but can be behind firewalls and load balancers.

## Components

TODO ADD FIGURE  - QuicR (simple-arch.png "QuicR Architectural Components")


Above diagram shows the various components/roles making the QuicR architecture and how it can be leveraged by two different classes of applications; a streaming app and a communication app.

TODO: explain the picture including the various components of publcishers, subscribers, origin server

TODO: explian that as the pub go up the tree, they get short circuit sent to any subibers on the the relay they traverse. Huge impact to latency for nearby the producer of the media. 

# Names and Named Objects

Names are basic elements with in the QuicR architecture and they uniquely identify objects. Named objects can be cached in relays in a way CDNs cache resources and thus can obtain similar benefits such caching mechanisms would offer.

## Group of Objects

Objects with in QuicR belong to a group. A group (a.k.a group of objects) represent an independent composition of set of objects, where there exists dependency relationship between the objects within the group. Groups, thus can be independently consummable by the subscriber applications.

The group, its structure, the granularity and nature of relation that exists betweem the composed objects are application specific. Group themselves don't share any relationship with other groups in a given context. Also the QuicR protocol doesn't mandate the cardinality of these group of objects and leaves the same to the application.

A typical example would be a group of pictures/video frames or group of audio samples that represent synchronization point in the video conferencing example.


## Named Objects

Objects represent the named entity within QuicR. An object's name is scoped to the group to which it belongs. The objects with in a group form a monotically increasing sequence space and the same is used in their naming.

## Names


Names in QuicR are composed of following components:

1. Domain Component
2. Application Component
3. Object Group Component

!--
~~~ ascii-art
       48 bits                      54 bits                     54 bits
┌───────────────────┬───────────────────────────────── ┬──────────────────────┐
│       Domain      │            Application           │    Object Group      │
│     Component     │             Component            │     Component        │
└───────────────────┴──────────────────────────────────┴─────────┬────────────┘
                                                                 │
                                                  ┌──────────────┴─────────────┐
                                                  │                            │
                                                  ▼                            ▼
                                        ┌──────────────────┐        ┌──────────────────┐
                                        │      Group       │        │       Object     │
                                        │    Identifier    │        │    Identifier    │
                                        └──────────────────┘        └──────────────────┘
                                              16 bits                      10 bits

~~~
Figure: QuicR Name
!--

Domain component uniquely identifies a given application domain. This is like a HTTP Origin and uniquely identifies the application and a root relay function. This is a DNS domain name or IP address combined with a UDP port number mapped to into the domain. Example: sfu.webex.com:5004.

Application component is scoped under a given Domain/Origin. This component identifies aspects specific to a given application instance hosted under a given domain (e.g.meeting identifier, media type or media quality identifier).

The final subcomponent identifies the group and the composed objects. The objects within a group are identified by a monotonically increasing sequence numbers beginning with 0. Each group is similarly identified by monotonically increasing integers.

Example: In this example, the domain component identifies acme.meeting.com domain, the application compoment identifies an instance of a meeting under this domain, say "meeting123", and camera stream from the user "alice". It also identifies the object 17 under part of the group 15. 

```quicr://acme.meeting.com/meeting123/alice/cam5/gro15/obj7```

Names within QuicR should adhere to following constraints:

* Names should enable compact representation for efficient transmission and storage. To keep the size of each packet small for media like audio or game state, the names need to hash or map down to something in the range of 128 bits. 
* Names should be efficiently converted to cache friendly datatypes ( like Keys in CDN caches) for storage and lookup purposes.
* Names should enable data lookup at the relays based on partial as well as whole names.

Once a named object is created, the content inside the named object can never be changed.

Objects have an expirty time after which they should be discarded by caches. 

Objects have an priority that the relays and clients can use to sequence which object to send first.

## Name Discovery

Names can be discovered via manifests. The role of the manifest is to identify the names as well as aspects pertaining to the associated data in a given usage context of the application. The content of Manifest is application defined and end to end encrypted. The manifest is owned by the application's origin server and are accessed as a protected resources by the authorized QuicR clients. The QuicR protocol treats Manifests as a named object, thus allowing for clients to subscribe for the purposes of bootstrapping into the session as well as to follow  manifest changes during a session [ new members joining a conference for example].

The manifest has well known name on the Origin server.

Also to note, a given application might provide non QuicR mechanisms to retrieve the manifest or not even even need a manifest. Such mechanisms are out of scop and can be used complementary to the approaches defined in this specification.

## QuicR media objects

The objects that names point to are application specific. The granularity of such data ( say media frame, fragment, datum) and its frequency are fully specified by a given application and they need to be opaque for relays/in-transit caches. The namedd objects are end-to-end encrypted.

[To Do] Should we do some hand waving here about mapping media into objects and talk about synchronization point trade-offs etc.? 

TODO - Congestion controll comes form QUIC but bitrate allocation is done at QuicR layer based on priority of objects.

# Examples

## Warp in QuicR

The media for a given channel, fluffy, could be proivided at differnt encoding points - say low, medius, and high. Then the media could be broken into segments that include the refences frames and were a number of seconds of video. Each frame of video would be an named object in the segment and audio would be a differnt named object corespoding to frame. So an object name could be like quicr:twitch.com/channel-fluffy/codeing-medium/segment-10:22:33/video/frame-22 

# Protocol Design Considerations

## HTTP/3

It would be possible to start with something that looked like HTTP as the protcol between the relays with special conventions for wild cards in URLs of a GET and ways to stream non final responses for any responses perhaps using something like multipart MINE. However, most of the existing code and logic for HTTP would not really be usable with the low latency streaming of data. It is probably much simplier and more scableable to simply define a PUB/SUB protocol direclty on top of QUIC.

##QUIC  Streams and Datagrams

There and pro and cons to mapping object transport on top of streams or on top of QUIC datagrams. The working group would need to sort this out and consider the possibility of using both for differnt types of data and if there should be suppor for a semi-reliable transport of data. Some objects, for example the manifest, you nearly always want to recieve in a relaible way while other objects have to be realtime.

## QUIC Congestion Controll

The basic idea in BBR of speeding up to probe then slowing down to drain the queue build up caused duing probe can work fine with real time applicaions. However the the current implemetations in QUIC do not seem optimized for real time applicaions and have some time where the slow down causes too much jitter. To not have playout drop, the jitter buffers add latency to compensate for this. Probing for the RTT has been one of the phases that causes particular problems for this. To reduce the latency of QUIC, this work should coordinate with the QUIC working group have have the QUIC working group develop congention controll opimzations for low latncy use of QUIC.

## Why not RTP

TODO - add Mo's points: The problem of stored formats vs RTP payload formats. The what does RTP get you. The problem that RTP is an gateway drug to SDP and friends done't let friends use SDP.






