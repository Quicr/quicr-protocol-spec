# Names and Named Objects {#names}

Names are basic elements with in the QuicR architecture and they
uniquely identify objects. For publishers of the media, the names 
identify application defined data objects being contributed and
for the subscribers/receivers, the names correspond to 
application data objects to be consumed.

The scope and granularity of the names and the data objects they
represent are application defined and controlled.

However, a given QuicR name must maintain certain properties 
as given below

* Each published name must be unique and is scoped to a 
  given domain and an application under that domain.

* Names should support a way for the subscribers to request 
  for the associated data either by specifying the full or partial names. 
  The latter is supported via wildcarding.

* Named objects should enable caching in relays in a way CDNs cache resources 
  and thus can obtain similar benefits such caching mechanisms would offer.

## Named Objects

The names of each object in QuicR is composed of the following components:

1. Domain Identifier
2. Application Identifier
3. Data Identifier

Domain component uniquely identifies a given application domain. This is
like a HTTP Origin or an standardized identifier that uniquely identifies 
the application and a root relay function. 

Application component is scoped under a given Domain. This
component identifies aspects specific to a given application instance
hosted under a given domain (e.g. which movie or meeting identifier).

Data identifier identifies aspects of application, for example
representation_id in a CMAF segment or video stream from a
conference user. In cases where media being delivered is naturally grouped 
into independently consumable groups (video group of picture or audio 
synchronization points for example), this component is futher composed into 
set of such groups, which are in turn made up of set of objects 
(video frames idr, p-frame within a  given gop). Each such group is 
identified by a monotonically increasing integer and objects within the 
group are also identified by another set of monotonically increasing integers. 
The groupID and objectID start at 0.

Example: In the example below the domain component identifies
acme.meeting.com domain, the application component identifies an
instance of a meeting under this domain, say "meeting123", and the 
data component captures high resolution camera stream from the user "alice"
being published as object 17 under group 15.

```
Example 1
acme.meeting.com/meeting123/alice/cam5/HiRes/15/17
```

```
Example 2
twitch.com/channel-fluffy/video-quality-id/group12/object0
```

Once a named object is created, the content inside the named object can
never be changed. Objects have an expiry time after which they should be
discarded by caches. Objects have an priority that the relays and
clients can use to make drop decisions or sequencing the sending order. 
The data inside an object is end-to-end encrypted whose keys are not 
available to Relay(s).

## Wildcarding with Names

QuicR allows subscribers to request for media based on wildcard'ed
names. Wildcarding enables subscribes/requests for media to be made 
as aggregates instead of at the object level granularity. Wildcard names 
are formed by skipping the right most segments of the "Data Identifier" 
component of the names.
 
For example, in an web conferencing use case, the client may subscribe
to just the origin, meeting_id and one of the publishers so as to get 
all the media from that user in a particular. The example matches all
the named objects published by the user alice in the meeting123.

```acme.meeting.com/meeting123/alice/* ```

When subscribing, there is an option to tell the relay to one of:

A.  Deliver any new objects it receives that match the name 

B. Deliver any new objects it receives and in addition send any previous
objects it has received that are in the same group that matches the name.

C. Wait until an object that has a objectId that matches the name is
received then start sending any objects that match the name.
