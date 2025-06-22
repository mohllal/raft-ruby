# Raft Algorithm Implementation in Ruby

This is a working implementation of the Raft consensus algorithm in Ruby.

This code is the companion to my blog post series on implementing Raft:

- [Part 1: The Why and How of Consensus in Distributed Systems](https://mohllal.github.io/implementing-raft-part-1/)
- [Part 2: Leader Election](https://mohllal.github.io/implementing-raft-part-2/)

## Features

The implementation includes:

- **Leader Election**: Implements randomized timeout-based elections
- **Log Replication**: Full log replication with file system persistence
- **DRb-based RPC**: Uses Ruby's built-in distributed object system
- **State Machine**: Simple key-value store with persistence
- **Network Partition Handling**: Simulates network failures and recoveries
- **Log Persistence**: Persistent storage of log entries and metadata
- **Conflict Resolution**: Handles log conflicts during replication

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

## Running the Demo

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

### Leader Election

After a few seconds, one node (in this example, node2) times out and starts an election:

**Node2 becomes a candidate and requests votes:**

```bash
[2025-06-22 22:34:38] INFO Raft::RaftNode: Election timeout - starting election
[2025-06-22 22:34:38] INFO Raft::RaftNode: Became candidate (term 1)
[2025-06-22 22:34:38] INFO Raft::RaftNode: Starting election for term 1
[2025-06-22 22:34:38] INFO Raft::RaftNode: Requesting votes from node1, node3
```

**Node1 and Node3 receive the vote request and grant their votes:**

```bash
[2025-06-22 22:34:38] INFO Raft::RaftNode: Received RequestVote(candidate: node2, term: 1, last_log: 0/0)
[2025-06-22 22:34:38] INFO Raft::RaftNode: Granted vote to node2 (term 1)

# On node3:
[2025-06-22 22:34:38] INFO Raft::RaftNode: Received RequestVote(candidate: node2, term: 1, last_log: 0/0)
[2025-06-22 22:34:38] INFO Raft::RaftNode: Granted vote to node2 (term 1)
```

**Node2 wins the election and becomes leader:**

```bash
[2025-06-22 22:34:38] INFO Raft::RaftNode: Received vote from node3 (2/2)
[2025-06-22 22:34:38] INFO Raft::RaftNode: Won election with 2 votes!
[2025-06-22 22:34:38] INFO Raft::RaftNode: Became leader (term 1)
```

### Heartbeats

Once elected, the leader (node2) sends regular heartbeats to maintain its leadership:

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

- **Node2** as the LEADER
- **Node1** and **Node3** as FOLLOWERS
- All nodes in term 1
- Heartbeats every 1 second preventing new elections

## References

- [Raft Paper](https://raft.github.io/raft.pdf) - The original Raft consensus algorithm paper
- [Raft Visualization](https://raft.github.io/) - Great visual explanation of Raft
- [Raft Implementation Guide](https://thesecretlivesofdata.com/raft/) - Step-by-step Raft visualization
