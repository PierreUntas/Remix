// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable {
    uint public currentVotingSessionId;

    struct Voter {
        bool isRegistered;
        mapping(uint => bool) hasVotedSession;
        uint[] votedSessionIds;
        uint[] proposalIds;
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
        uint proposalCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    mapping(uint => VotingSession) public votingSessions;
    mapping(address => Voter) private voters;

    event VoterRegistered(address voterAddress);
    event VoterUnregistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint sessionId, uint proposalId);
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
        VotingSession storage newSession = votingSessions[currentVotingSessionId];
        newSession.workflowStatus = WorkflowStatus.RegisteringVoters;
        newSession.proposalCount = 0;
        emit SessionCreated(currentVotingSessionId);
    }

    function registerVoter(address _address) public onlyOwner {
        VotingSession storage currentSession = votingSessions[currentVotingSessionId];
        require(
            currentSession.workflowStatus == WorkflowStatus.RegisteringVoters,
            "Registration not started for this session"
        );
        require(!voters[_address].isRegistered, "Voter already registered");
        voters[_address].isRegistered = true;
        emit VoterRegistered(_address);
    }

    function unregisterVoter(address _address) public onlyOwner {
        VotingSession storage currentSession = votingSessions[currentVotingSessionId];
        require(
            currentSession.workflowStatus == WorkflowStatus.RegisteringVoters,
            "Registration phase ended, cannot unregister"
        );
        require(voters[_address].isRegistered, "Voter already unregistered");
        voters[_address].isRegistered = false;
        emit VoterUnregistered(_address);
    }

    function startProposalsRegistration() public onlyOwner {
        VotingSession storage currentSession = votingSessions[currentVotingSessionId];
        require(
            currentSession.workflowStatus == WorkflowStatus.RegisteringVoters,
            "Wrong status to start proposal registration"
        );
        WorkflowStatus previousStatus = currentSession.workflowStatus;
        currentSession.workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(previousStatus, currentSession.workflowStatus);
    }

    function sendNewProposition(string memory _description) public onlyIfRegistered {
        require(bytes(_description).length > 0, "Proposal description is required");
        
        VotingSession storage currentSession = votingSessions[currentVotingSessionId];
        require(
            currentSession.workflowStatus == WorkflowStatus.ProposalsRegistrationStarted,
            "Proposals registration not started"
        );

        uint proposalId = currentSession.proposalCount;
        currentSession.proposals.push(Proposal({
            id: proposalId,
            description: _description,
            voteCount: 0
        }));
        currentSession.proposalCount++;

        voters[msg.sender].proposalIds.push(proposalId);

        emit ProposalRegistered(currentVotingSessionId, proposalId);
    }

    function endProposalsRegistration() public onlyOwner {
        VotingSession storage currentSession = votingSessions[currentVotingSessionId];
        require(
            currentSession.workflowStatus == WorkflowStatus.ProposalsRegistrationStarted,
            "Proposals registration not started or already ended"
        );
        WorkflowStatus previousStatus = currentSession.workflowStatus;
        currentSession.workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(previousStatus, currentSession.workflowStatus);
    }

    function startVotingSession() public onlyOwner {
        VotingSession storage currentSession = votingSessions[currentVotingSessionId];
        require(
            currentSession.workflowStatus == WorkflowStatus.ProposalsRegistrationEnded,
            "Proposals registration not ended"
        );
        WorkflowStatus previousStatus = currentSession.workflowStatus;
        currentSession.workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(previousStatus, currentSession.workflowStatus);
    }

    function sendVote(uint _proposalId) public onlyIfRegistered {
        VotingSession storage currentSession = votingSessions[currentVotingSessionId];
        require(
            currentSession.workflowStatus == WorkflowStatus.VotingSessionStarted,
            "Voting session not started"
        );
        require(_proposalId < currentSession.proposals.length, "Invalid proposal Id");

        Voter storage voter = voters[msg.sender];
        require(!voter.hasVotedSession[currentVotingSessionId], "You have already voted this session");

        voter.hasVotedSession[currentVotingSessionId] = true;
        voter.votedSessionIds.push(currentVotingSessionId);
        voter.proposalIds.push(_proposalId);

        currentSession.proposals[_proposalId].voteCount++;
        emit Voted(msg.sender, _proposalId);
    }

    function endVotingSession() public onlyOwner {
        VotingSession storage currentSession = votingSessions[currentVotingSessionId];
        require(
            currentSession.workflowStatus == WorkflowStatus.VotingSessionStarted,
            "Voting session not started"
        );
        WorkflowStatus previousStatus = currentSession.workflowStatus;
        currentSession.workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(previousStatus, currentSession.workflowStatus);
    }

    function computeMostVotedProposal() public onlyOwner {
        VotingSession storage currentSession = votingSessions[currentVotingSessionId];
        require(
            currentSession.workflowStatus == WorkflowStatus.VotingSessionEnded,
            "Voting session not ended yet"
        );
        require(currentSession.proposals.length > 0, "No proposals for this session");

        uint highestVoteCount = 0;
        uint winningProposalId = 0;

        for (uint i = 0; i < currentSession.proposals.length; i++) {
            if (currentSession.proposals[i].voteCount > highestVoteCount) {
                highestVoteCount = currentSession.proposals[i].voteCount;
                winningProposalId = currentSession.proposals[i].id;
            }
        }

        currentSession.winningProposalId = winningProposalId;
        WorkflowStatus previousStatus = currentSession.workflowStatus;
        currentSession.workflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(previousStatus, currentSession.workflowStatus);
    }

    function getWinningProposalBySession(uint _sessionId) external view returns (Proposal memory) {
        VotingSession storage session = votingSessions[_sessionId];
        require(session.workflowStatus == WorkflowStatus.VotesTallied, "Votes not tallied yet");
        return session.proposals[session.winningProposalId];
    }

    function getAllProposalsBySession(uint _sessionId) external view returns (Proposal[] memory) {
        VotingSession storage session = votingSessions[_sessionId];
        return session.proposals;
    }

    function getAllProposalsFromCurrentSession() public view returns (Proposal[] memory) {
        VotingSession storage currentSession = votingSessions[currentVotingSessionId];
        return currentSession.proposals;
    }
}
