// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable {
    uint public currentVotingSessionId;
    uint private nonce;

    mapping(uint => VotingSession) public votingSessions;
    mapping(address => Voter) public voters;

    struct Voter {
        bool isRegistered;
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

    constructor() Ownable(msg.sender){
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
        VotingSession memory currentSession = getCurrentSession();
        require(currentSession.workflowStatus == WorkflowStatus.RegisteringVoters, "Registration not started for this session");
        require(!voters[_address].isRegistered, "Voter is already registered");
        voters[_address].isRegistered = true;
        emit VoterRegistered(_address);
    }

    function unregisterVoter(address _address) public onlyOwner {
        VotingSession memory currentSession = getCurrentSession();
        require(currentSession.workflowStatus == WorkflowStatus.RegisteringVoters, "Registration not started for this session");
        require(voters[_address].isRegistered, "Voter is already unregistered");
        voters[_address].isRegistered = false;
        emit VoterUnregistered(_address);
    }

    function startProposalsRegistration() public onlyOwner {
        VotingSession memory currentSession = getCurrentSession();
        require(currentSession.workflowStatus == WorkflowStatus.RegisteringVoters, "Proposals not started for this session");
        currentSession.workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    function sendNewProposition(string memory _description) public onlyIfRegistered {
        require(bytes(_description).length > 0, "Proposal description is required");
        require(voters[msg.sender].isRegistered, "You are not registered");
        VotingSession storage currentSession = votingSessions[currentVotingSessionId];
        require(currentSession.workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals not started for this session");
        
        currentSession.proposals.push(Proposal({
                id: nonce,
                description: _description,
                voteCount: 0
        }));
        emit ProposalRegistered(nonce);
        nonce++;
    }

    function endProposalsRegistration() public onlyOwner {
        VotingSession memory currentSession = getCurrentSession();
        require(currentSession.workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals registration not started for this session");
        currentSession.workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded); 
    }

    function startVotingSession() public onlyOwner {
        VotingSession memory cs = getCurrentSession();
        require(cs.workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Proposals registration not ended");
        cs.workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    function sendVote(uint _proposalId) public onlyIfRegistered {
        VotingSession storage cs = votingSessions[currentVotingSessionId];
        require(cs.workflowStatus == WorkflowStatus.VotingSessionStarted, "registration did not started");
        require(_proposalId < cs.proposals.length, "Invalid proposal Id");

        Voter storage v = voters[msg.sender];

        require(v.isRegistered, "You are not registered to vote for this session");
        require(v.votedSessionIds[v.votedSessionIds.length - 1] != currentVotingSessionId, "You have already voted for this session");
        v.proposalIds.push(_proposalId);

        cs.proposals[_proposalId].voteCount++;
        emit Voted(msg.sender, _proposalId);
    }

    function endVotingSession() public onlyOwner {
        VotingSession memory cs = getCurrentSession();
        require(cs.workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting session not started");
        cs.workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    function computeMostVotedProposal() public {
        VotingSession memory cs = getCurrentSession();
        require(cs.workflowStatus == WorkflowStatus.VotingSessionEnded, "Voting session not ended");
        require(cs.proposals.length > 0, "This session has no proposals");

        Proposal memory mostVotedProposal;
        Proposal[] memory proposals = cs.proposals;
 
        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > mostVotedProposal.voteCount)
                mostVotedProposal = proposals[i];
        }

        cs.winningProposalId = mostVotedProposal.id;
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
        VotingSession memory cs = getCurrentSession();
        return cs.proposals;
    }
}