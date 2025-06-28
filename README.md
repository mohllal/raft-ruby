# Raft Algorithm Implementation in Ruby

This is a working implementation of the Raft consensus algorithm in Ruby.

This code is the companion to my blog post series on implementing Raft:

- [Part 1: The Why and How of Consensus in Distributed Systems](https://mohllal.github.io/implementing-raft-part-1/)
- [Part 2: Leader Election](https://mohllal.github.io/implementing-raft-part-2/)

## Features

The implementation includes:

- **Leader election**: Implements randomized timeout-based elections
- **Log replication**: Full log replication with file system persistence
- **DRb-based RPC**: Uses Ruby's built-in distributed object system
- **State machine**: Simple key-value store with persistence
- **Network partition handling**: Simulates network failures and recoveries
- **Log persistence**: Persistent storage of log entries and metadata
- **Conflict resolution**: Handles log conflicts during replication

## Installation

1. Make sure you have Ruby 3.3+ installed
2. Install dependencies:

   ```bash
   bundle install
   ```

3. (Optional) Copy and customize environment configuration:

   ```bash
   cp .env.template .env
   # Edit .env to customize logging, timeouts, etc.
   ```

## Configuration

Copy `.env.template` to `.env` and customize:

```bash
# Timing Configuration
RAFT_HEARTBEAT_INTERVAL=0.05      # Heartbeat interval in seconds
RAFT_ELECTION_TIMEOUT_MIN=0.15    # Min election timeout in seconds
RAFT_ELECTION_TIMEOUT_MAX=0.3     # Max election timeout in seconds
RAFT_RPC_TIMEOUT=0.1              # RPC request timeout in seconds

RAFT_DATA_DIR=data               # Data directory for persistence
RAFT_LOG_DIR=logs                # Log directory for persistence
RAFT_STATE_FILE=state.json       # State file for persistence
RAFT_LOG_FILE=log.json           # Log file for persistence
RAFT_METADATA_FILE=metadata.json # Metadata file for persistence

# Logging Configuration
RAFT_LOG_LEVEL=INFO               # DEBUG, INFO, WARN, ERROR
```

## Running the demo

### Starting the cluster

Start three Raft nodes in separate terminals:

```bash
# Terminal 1
ruby demo/start_node.rb node1

# Terminal 2
ruby demo/start_node.rb node2

# Terminal 3
ruby demo/start_node.rb node3
```

When you start each node, you'll see:

```bash
=== Starting Raft Node ===
Node ID: node1
Port: 8001
==========================
[2025-06-22 22:34:32] INFO Raft::StateMachine: State machine for node1 initialized with 0 entries
[2025-06-22 22:34:32] INFO Raft::RaftNode: Node node1 initialized as follower
[2025-06-22 22:34:32] INFO Raft::RaftNode: Cluster ports configured: {"node1"=>8001, "node2"=>8002, "node3"=>8003}
[2025-06-22 22:34:32] INFO Raft::DRbServer: DRb server started on druby://localhost:8001
Node node1 started successfully!
Press Ctrl+C to stop...
```

Each node:

1. Starts as a **follower** (the default Raft state)
2. Initializes an empty state machine (key-value store)
3. Starts a DRb server on its assigned port for inter-node communication

### Leader election

After a few seconds, one node (in this example, `node2`) times out and starts an election:

**`node2` becomes a candidate and requests votes:**

```bash
[2025-06-22 22:34:38] INFO Raft::RaftNode: Election timeout - starting election
[2025-06-22 22:34:38] INFO Raft::RaftNode: Became candidate (term 1)
[2025-06-22 22:34:38] INFO Raft::RaftNode: Starting election for term 1
[2025-06-22 22:34:38] INFO Raft::RaftNode: Requesting votes from node1, node3
```

**`node1` and `node3` receive the vote request and grant their votes:**

```bash
[2025-06-22 22:34:38] INFO Raft::RaftNode: Received RequestVote(candidate: node2, term: 1, last_log: 0/0)
[2025-06-22 22:34:38] INFO Raft::RaftNode: Granted vote to node2 (term 1)

# On node3:
[2025-06-22 22:34:38] INFO Raft::RaftNode: Received RequestVote(candidate: node2, term: 1, last_log: 0/0)
[2025-06-22 22:34:38] INFO Raft::RaftNode: Granted vote to node2 (term 1)
```

**`node2` wins the election and becomes leader:**

```bash
[2025-06-22 22:34:38] INFO Raft::RaftNode: Received vote from node3 (2/2)
[2025-06-22 22:34:38] INFO Raft::RaftNode: Won election with 2 votes!
[2025-06-22 22:34:38] INFO Raft::RaftNode: Became leader (term 1)
```

### Heartbeats

Once elected, the leader (`node2`) sends regular heartbeats to maintain its leadership:

**Leader sends heartbeats:**

```bash
[2025-06-22 22:34:38] INFO Raft::RemoteNode: → Sending append_entries to node1 (term 1, 0 entries)
[2025-06-22 22:34:38] INFO Raft::RemoteNode: → Sending append_entries to node3 (term 1, 0 entries)
```

**Followers acknowledge heartbeats:**

```bash
# On followers:
[2025-06-22 22:34:38] INFO Raft::RaftNode: Received Heartbeat(leader: node2, term: 1, prev: 0/0, commit: 0)
```

The cluster is now stable with:

- **`node2`** as the LEADER
- **`node1`** and **`node3`** as FOLLOWERS
- All nodes in term 1
- Heartbeats every 1 second preventing new elections

### Log replication

In a fourth terminal, run the distributed cluster demo:

```bash
# Terminal 4
ruby demo/distributed_cluster_demo.rb
```

Follow the prompts to connect to all nodes, then use the interactive mode:

```bash
=== Distributed Raft Cluster Demo ===

Press Enter once all nodes are started...

✓ Connected to node1 on port 8001
✓ Connected to node2 on port 8002
✓ Connected to node3 on port 8003

=== Current Cluster State ===
node1: follower (term: 1, log index: 0)
node2: leader (term: 1, log index: 0)
node3: follower (term: 1, log index: 0)

> add user1 Alice
✓ Added log entry through node2: LogEntry(term=1, index=1, cmd=SET user1 Alice)

> add user2 Bob
✓ Added log entry through node2: LogEntry(term=1, index=2, cmd=SET user2 Bob)

> status
=== Current Cluster State ===
node1: follower (term: 1, log index: 2)
node2: leader (term: 1, log index: 2)
node3: follower (term: 1, log index: 2)
```

#### What happens during log replication?

When you add an entry, you'll see these logs:

**On the Leader (`node2`):**

```bash
[2025-06-22 22:35:12] INFO Raft::RaftNode: Appended log entry: #<struct term=1, index=1, command={:type=>"SET", :key=>"user1", :value=>"Alice"}>
[2025-06-22 22:35:12] INFO Raft::RaftNode: Sending AppendEntries(leader: node2, term: 1, prev: 0/0, entries: 1, commit: 0) to node1
[2025-06-22 22:35:12] INFO Raft::RaftNode: Sending AppendEntries(leader: node2, term: 1, prev: 0/0, entries: 1, commit: 0) to node3
[2025-06-22 22:35:12] INFO Raft::RaftNode: Updated indices for node1: next=2, match=1
[2025-06-22 22:35:12] INFO Raft::RaftNode: Updated indices for node3: next=2, match=1
[2025-06-22 22:35:12] INFO Raft::RaftNode: Advanced commit index from 0 to 1
[2025-06-22 22:35:12] INFO Raft::RaftNode: Applied log entry 1: {:type=>"SET", :key=>"user1", :value=>"Alice"} -> set
```

**On the Followers (`node1` & `node3`):**

```bash
[2025-06-22 22:35:12] INFO Raft::RaftNode: Received AppendEntries(leader: node2, term: 1, prev: 0/0, entries: 1, commit: 0)
[2025-06-22 22:35:12] INFO Raft::RaftNode: Appended 1 entries to log
[2025-06-22 22:35:12] INFO Raft::RaftNode: Updated commit index to 1
[2025-06-22 22:35:12] INFO Raft::RaftNode: Applied log entry 1: {:type=>"SET", :key=>"user1", :value=>"Alice"} -> set
```

### Persistence files

After adding log entries, check the persistence files:

#### Log file

Path: `logs/node2/log.json`, this is the log of the Raft node

```json
[
  {
    "term": 1,
    "index": 1,
    "command": {
      "type": "SET",
      "key": "user1",
      "value": "Alice"
    }
  },
  {
    "term": 1,
    "index": 2,
    "command": {
      "type": "SET",
      "key": "user2",
      "value": "Bob"
    }
  }
]
```

#### Metadata file

Path: `logs/node2/metadata.json`, this is the metadata of the Raft node

```json
{
  "current_term": 1,
  "voted_for": "node2",
  "commit_index": 2,
  "last_applied": 2,
  "last_updated": "2025-06-22T22:35:15.123Z"
}
```

#### State machine file

Path: `data/node2/state.json`, this is the state of the key-value store

```json
{
  "user1": "Alice",
  "user2": "Bob"
}
```

### Testing fault tolerance

1. **Stop the leader** (Ctrl+C in `node2`'s terminal)
2. Watch as the remaining nodes elect a new leader:

```bash
# On remaining nodes:
[2025-06-22 22:36:00] INFO Raft::RaftNode: Leader heartbeat timeout
[2025-06-22 22:36:00] INFO Raft::RaftNode: Election timeout - starting election
[2025-06-22 22:36:00] INFO Raft::RaftNode: Became candidate (term 2)
```

3. **Restart the stopped node** (`node2`) and watch it catch up:

```bash
[2025-06-22 22:36:30] INFO Raft::RaftNode: Loaded persistent state: term=1, log_size=2, commit=2, applied=2
[2025-06-22 22:36:30] INFO Raft::RaftNode: Received AppendEntries with higher term 2, becoming follower
```

The restarted node will:

- Load its persisted state (term, log, metadata)
- Receive updates from the new leader
- Apply any missed log entries

## References

- [Raft Paper](https://raft.github.io/raft.pdf) - The original Raft consensus algorithm paper
- [Raft Visualization](https://raft.github.io/) - Great visual explanation of Raft
- [Raft Implementation Guide](https://thesecretlivesofdata.com/raft/) - Step-by-step Raft visualization
