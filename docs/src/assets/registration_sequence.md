```mermaid
sequenceDiagram
    participant Client
    participant Registrar
    participant PeaceFounder
    Client->>Registrar: Requests an invite
    Registrar->>PeaceFounder: {ticket_id}_key
    PeaceFounder->>Registrar: {ticket_id, timestamp, demespec, salt}_key
    Registrar->>Client: ticket_id, demespec, token
    Client ->> PeaceFounder: {ticket_id, member_id}_token
    PeaceFounder ->> Client: {member_id}_registrar
    Client ->> PeaceFounder: {pseudonym}_member
    PeaceFounder ->> Client: inclusion_proof, {chain_state}_recorder
```

