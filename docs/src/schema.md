# HTTP API


```@raw html

<style>
  .swagger-ui .information-container {
    display: none !important;
  }

  .swagger-ui #operations-tag-default {
    display: none !important;
  }

</style>


<div id="swagger-ui"></div>
<script>

  window.onload = () => {

    var pathArray = window.location.pathname.split('/');
    pathArray.pop();
    pathArray.pop();
    pathArray.push('assets', 'schema.json');
    var relativePath = pathArray.join('/');
    
    console.log(relativePath);
      window.ui = SwaggerUIBundle({
          url: relativePath,
          dom_id: '#swagger-ui',
      });
  };
</script>
```



```
GET /deme # returns a current manifest file
GET /deme/{hash}

POST /tickets : Tuple{TicketID, DateTime, auth_code::Digest} -> Tuple{salt::Vector{UInt8}, auth_code::Digest} # resets token when repeated
DELETE /tickets/{TicketID}
PUT /tickets/{TicketID} : Tuple{Pseudonym, auth_code::Digest} -> Admission
GET /tickets/{TicketID} : TicketStatus

POST /braidchain/members : Member -> AckInclusion{ChainState}
GET /braidchain/members : Vector{Tuple{Int, Member}}
GET /braidchain/members?id={Pseudonym} : Tuple{Int, Member}
GET /braidchain/members?pseudonym={Pseudonym} : Tuple{Int, Member}

POST /braidchain/proposals : Proposal -> AckInclusion
GET /braidcahin/proposals/{UUID} : Tuple{Int, Proposal}
GET /braidchain/proposals : Vector{Tuple{Int, Proposal}}

GET /braidchain/{Int}/record : Transaction
GET /braidchain/{Int}/leaf : AckInclusion{ChainState}
GET /braidchain/{Int}/root : AckConsistency{ChainState}
GET /braidchain/commit : Commit{ChainState}
GET /braidchain/tar : BraidChainArchive

POST /pollingstation/{UUID}/votes : Vote -> CastAck
GET /pollingstation/{UUID}/spine : Vector{Digest}
GET /pollingstation/{UUID}/commit : Commit{BallotBoxState}
GET /pollingstation/{UUID}/proposal : Tuple{Int, Proposal}
GET /pollingstation/{UUID}/votes/{Int}/record : CastRecord
GET /pollingstation/{UUID}/votes/{Int}/receipt : CastReceipt
GET /pollingstation/{UUID}/votes/{Int}/leaf : AckInclusion{BallotBoxState}
GET /pollingstation/{UUID}/votes/{Int}/root : AckConsistency{BallotBoxState}
GET /pollingstation/{UUID}/tar : BallotBoxArchive
GET /pollingstation/collectors # necessary to make a proposal
```

## Braider

```
GET /braider : BraiderStatus
GET /braider/jobs : Vector{JobID}
GET /braider/jobs/{JobID} : JobStatus
GET /braider/jobs/{JobID}/braid : Braid
POST /braider/jobs : BraidJobSpec -> JobID
PUT /braider/jobs/{JobID} : Tuple{Vector{Pseudonym}, Generator} -> JobStatus
```
