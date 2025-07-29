// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable {
    uint public currentVotingSessionId;
    uint private nonce; // ADDED: Nonce for unique proposal IDs

    mapping(uint => VotingSession) public votingSessions;
    mapping(address => Voter) public voters;

    struct Voter {
        bool isRegistered;
        uint[] votedSessionIds; // MODIFIED: Changed from single uint to array to track all sessions voted in
        uint[] proposalIds;     // MODIFIED: Changed from single uint to array to track all proposals voted for
    }

    struct Proposal {
        uint id;
        string description;
        uint voteCount;
    }

    struct VotingSession {
        WorkflowStatus workflowStatus;
        uint winningProposalId;
        Proposal[] proposals;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    event VoterRegistered(address voterAddress);
    event VoterUnregistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);
    event SessionCreated(uint sessionId);

    constructor() Ownable(msg.sender) {
    }

    modifier onlyIfRegistered() {
        require(voters[msg.sender].isRegistered, "You are not registered");
        _;
    }
 
    function getCurrentSession() public view returns (VotingSession memory) {
        return votingSessions[currentVotingSessionId];
    }

    function createVotingSession() public onlyOwner {
        currentVotingSessionId++;
        votingSessions[currentVotingSessionId].workflowStatus = WorkflowStatus.RegisteringVoters;
        emit SessionCreated(currentVotingSessionId);
    }

    function registerVoter(address _address) public onlyOwner {
        require(votingSessions[currentVotingSessionId].workflowStatus == WorkflowStatus.RegisteringVoters, 
                "Registration not started for this session");
        require(!voters[_address].isRegistered, "Voter is already registered");
        
        // ADDED: Initialize the voter's arrays
        voters[_address].isRegistered = true;
        voters[_address].votedSessionIds = new uint[](0); // ADDED: Initialize array
        voters[_address].proposalIds = new uint[](0);     // ADDED: Initialize array
        
        emit VoterRegistered(_address);
    }

    function unregisterVoter(address _address) public onlyOwner {
        require(votingSessions[currentVotingSessionId].workflowStatus == WorkflowStatus.RegisteringVoters, 
                "Registration not started for this session");
        require(voters[_address].isRegistered, "Voter is already unregistered");
        
        voters[_address].isRegistered = false;
        emit VoterUnregistered(_address);
    }

    function startProposalsRegistration() public onlyOwner {
        // MODIFIED: Direct storage access instead of memory copy
        require(votingSessions[currentVotingSessionId].workflowStatus == WorkflowStatus.RegisteringVoters, 
                "Proposals not started for this session");
        
        votingSessions[currentVotingSessionId].workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    function sendNewProposition(string memory _description) public onlyIfRegistered {
        require(bytes(_description).length > 0, "Proposal description is required");
        
        // MODIFIED: Direct storage access instead of memory copy
        VotingSession storage currentSession = votingSessions[currentVotingSessionId];
        require(currentSession.workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, 
                "Proposals not started for this session");
        
        // MODIFIED: Using nonce for unique IDs
        currentSession.proposals.push(Proposal({
            id: nonce,
            description: _description,
            voteCount: 0
        }));
        
        emit ProposalRegistered(nonce);
        nonce++; // ADDED: Increment nonce
    }

    function endProposalsRegistration() public onlyOwner {
        // MODIFIED: Direct storage access instead of memory copy
        require(votingSessions[currentVotingSessionId].workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, 
                "Proposals registration not started for this session");
        
        votingSessions[currentVotingSessionId].workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded); 
    }

    function startVotingSession() public onlyOwner {
        // MODIFIED: Direct storage access instead of memory copy
        require(votingSessions[currentVotingSessionId].workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, 
                "Proposals registration not ended");
        
        votingSessions[currentVotingSessionId].workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    function sendVote(uint _proposalId) public onlyIfRegistered {
        // MODIFIED: Direct storage access with better variable names
        VotingSession storage cs = votingSessions[currentVotingSessionId];
        require(cs.workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting session not started");
        
        // ADDED: Check if proposal exists
        require(_proposalId < cs.proposals.length, "Invalid proposal Id");

        Voter storage v = voters[msg.sender];
        
        // ADDED: Safe check for previous votes in this session
        bool hasVotedInSession = false;
        for(uint i = 0; i < v.votedSessionIds.length; i++) {
            if(v.votedSessionIds[i] == currentVotingSessionId) {
                hasVotedInSession = true;
                break;
            }
        }
        require(!hasVotedInSession, "You have already voted for this session");
        
        // MODIFIED: Record the vote properly
        v.votedSessionIds.push(currentVotingSessionId);
        v.proposalIds.push(_proposalId);
        
        cs.proposals[_proposalId].voteCount++;
        emit Voted(msg.sender, _proposalId);
    }

    function endVotingSession() public onlyOwner {
        // MODIFIED: Direct storage access instead of memory copy
        require(votingSessions[currentVotingSessionId].workflowStatus == WorkflowStatus.VotingSessionStarted, 
                "Voting session not started");
        
        votingSessions[currentVotingSessionId].workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    function computeMostVotedProposal() public {
        // MODIFIED: Direct storage access with better variable names
        VotingSession storage cs = votingSessions[currentVotingSessionId];
        require(cs.workflowStatus == WorkflowStatus.VotingSessionEnded, "Voting session not ended");
        require(cs.proposals.length > 0, "This session has no proposals");

        // MODIFIED: Simplified algorithm to find winner
        uint winningId = 0;
        uint maxVotes = 0;
        
        for (uint i = 0; i < cs.proposals.length; i++) {
            if (cs.proposals[i].voteCount > maxVotes) {
                maxVotes = cs.proposals[i].voteCount;
                winningId = cs.proposals[i].id;
            }
        }

        cs.winningProposalId = winningId;
        cs.workflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }

    function getWinningProposalBySession(uint _sessionId) external view returns(VotingSession memory) {
        return votingSessions[_sessionId];
    }

    function getAllProposalsBySession(uint _sessiondId) external view returns (Proposal[] memory) {
        return votingSessions[_sessiondId].proposals;
    }

    function getAllProposalsFromCurrentSession() public view returns (Proposal[] memory) {
        // MODIFIED: Simplified to direct storage access
        return votingSessions[currentVotingSessionId].proposals;
    }
}