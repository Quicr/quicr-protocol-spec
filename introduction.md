# Introduction

This specifiction defines QUICR, a media delivery protocol 
over QUIC.

Recently new usecases have emerged requiring higher scalability of
delivery for interactive realtime applications and much lower latency
for streaming applications and a combination thereof. 

On one side are use cases such as normal web conferences wanting to 
distribute out to millions of viewers and allow viewers to instantly 
move to being a presenter (active participant). On the other side are 
usescases such as streaming a soccer game to millions of people 
including people in the stadium watching the game live. Viewers 
watching an e-sports event want to be able to comment 
with low latency to ensure the interactivity aspects between what 
different viewers are preserved. All of these usescases push 
towards latencies that are in the order of 100ms over the 
natural latency the network causes.

The architecture for this specificaiton is outlined in
draft-jennings-moq-arch, where the principal idea is 
Client endpoints publish and subscribe to named objects that 
is sent to, and received from, relays that forms an overlay 
delivery network similar to what CDN provides today.

The architecture specification, draft-jennings-moq-arch, is a 
prequisite to read this specification.

This specification defines the protocol specifics of the 
QuicR Media Delievery Architecture.

# Contributing

All significant discussion of development of this protocol is in the
GitHub issue tracker at: ```
https://github.com/Quicr/quicr-protocol-spec ```

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
  a limited lifetime, priority and is transported via the protocol defined
  in this specification.

* Origin server: Component managing/authoring the names scoped under a 
  domain for a specific application and is responsible for establishing trust between clients and relays for delivering media. Origin servers MAY implement other QuicR functions, such as Relay function, as necessary.

# QuicR Protocol

This section provides a non-normative description for the QuicR protocol.

At a high level, entities within QuicR architecture publish named media 
objects and consume media by susbcribing to the named objects. Some 
entities perform "Relay" function providing the store and forward behavior
to server subscription requests that optimize media delivery lantencies
and quality wherever applicable. The names used in the QuicR protocol 
are scoped and authorozied to a domain by the Origin serving the domain. 

TODO: How does quicr minimize the manifest overload

## Origin Server 

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

## Relays

The relays receive subscriptions and intent to publish request and
forward them towards the origin. This may send the messages
directly to the Origin Relay or possibly traverse another Relay. Replies
to theses message follow the reverse direction of the request and when
the Origin gives the OK to a subscription or intent to publish, the
Relay allows the subscription or future publishes to the Names in the
request.

Subscription received are aggregated. When a relay receives a publish
request with data, it will forward it both towards the Origin and to any
clients or relays that have a matching subscription. This "short
circuit" of distribution by a relay before the data has even reached the
Origin servers provides significant latency reduction for nearby client.

The Relay keeps an outgoing queue of objects to be sent to the each
subscriber and objects are sent in priority order.

Relays MAY cache some of the information for short period of time and
the time cached may depend on the origin.

