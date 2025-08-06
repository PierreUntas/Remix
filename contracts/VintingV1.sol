// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable {

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    struct Proposal {
        string description;
        address submitter;
        uint voteCount;
    }

    struct Session {
        uint id;
        WorkflowStatus workflowStatus;
        uint winningProposalIndex;
        uint highestVoteCount;
        Proposal[] proposals;
        mapping (address => bool) hasVoted;
        uint parentSessionId;
    }
    
    mapping(address => bool) public whitelist;
    mapping (uint => Session) sessions;
    uint sessionIdCounter;

    event WhitelistUpdated(address voterAddress, bool isWhitelisted);
    event NewVotingSession(uint sessionId);
    event WorkflowStatusChange(uint sessionId, WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint sessionId, uint proposalId);
    event Voted(uint sessionId, address voter, uint proposalId);
    event WinningProposition(uint sessionId, uint propositionId);
    event RenewSession(uint sessionId);

    constructor() Ownable(msg.sender) {
    }

    function updateWhitelist(address _address, bool _isWhitelisted) public onlyOwner {
        require(whitelist[_address] != _isWhitelisted, "whitelist is up to date");
        whitelist[_address] = _isWhitelisted;
        emit WhitelistUpdated(_address, _isWhitelisted);
    }

    function isWhitelisted(address _address) public view returns (bool) {
        return whitelist[_address];
    }

    function createSession() public onlyOwner {
        sessionIdCounter++;
        Session storage newSession = sessions[sessionIdCounter];
        newSession.id = sessionIdCounter;
        emit NewVotingSession(sessionIdCounter);
    }

    function renewSession(Proposal[] memory _bestProposals, uint _parentSessionId) public onlyOwner {
        sessionIdCounter++;
        Session storage newSession = sessions[sessionIdCounter];
        newSession.id = sessionIdCounter;
        newSession.parentSessionId = _parentSessionId;
        for (uint i = 0; i < _bestProposals.length; i++) {
            newSession.proposals.push(_bestProposals[i]);
        }
        emit NewVotingSession(sessionIdCounter);
    }

    function startProposalsRegistration(uint sessionId) public onlyOwner {
        Session storage newSession = sessions[sessionId];
        require(newSession.workflowStatus == WorkflowStatus.RegisteringVoters);
        newSession.workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(sessionId, WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    function sendNewProposition(uint sessionId, string memory _description) public {
        require(bytes(_description).length <= 512, "Description is too long, limit 512 bytes");
        Session storage currentSession = sessions[sessionId];
        require(currentSession.workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "registration did not started");
        require(whitelist[msg.sender], "You are not registered");
        currentSession.proposals.push(Proposal(_description, msg.sender, 0));
        emit ProposalRegistered(currentSession.id, currentSession.proposals.length - 1);
    }
    
    function endProposalsRegistration(uint sessionId) public onlyOwner {
        Session storage currentSession = sessions[sessionId];
        require (currentSession.workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals registration not started");
        require(currentSession.proposals.length > 0, "no proposals were registered");
        currentSession.workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(sessionId, WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded); 
    }

    function startVotingSession(uint sessionId) public onlyOwner {
        Session storage currentSession = sessions[sessionId];
        require(currentSession.workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Proposals registration not ended");
        currentSession.workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(sessionId, WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted); 
    }
    
    function sendVote(uint sessionId, uint _proposalId) public {
        Session storage currentSession = sessions[sessionId];
        require(currentSession.workflowStatus == WorkflowStatus.VotingSessionStarted, "registration did not started");
        require(whitelist[msg.sender], "You are not registered");
        require(!currentSession.hasVoted[msg.sender], "You have already vote");
        Proposal storage proposal = currentSession.proposals[_proposalId];
        proposal.voteCount++;
        currentSession.hasVoted[msg.sender] = true;
        if(proposal.voteCount > currentSession.highestVoteCount) { 
            currentSession.highestVoteCount = proposal.voteCount;
        }
        emit Voted(sessionId, msg.sender, _proposalId);
    }

    function endVotingSession(uint sessionId) public onlyOwner {
        Session storage currentSession = sessions[sessionId];
        require(currentSession.workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting session not started");
        require(currentSession.highestVoteCount > 0, "no votes were registered");
        currentSession.workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(sessionId, WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    function computeMostVotedProposal(uint sessionId) public onlyOwner {   
        Session storage currentSession = sessions[sessionId];
        require(currentSession.workflowStatus == WorkflowStatus.VotingSessionEnded, "Voting session did not end");
        Proposal[] storage proposals = currentSession.proposals;
        uint numberOfBestProposal;
        for (uint i = 0; i < proposals.length; i++) {
            if(proposals[i].voteCount == currentSession.highestVoteCount)
            numberOfBestProposal++;
        }
        Proposal[] memory bestProposals = new Proposal[](numberOfBestProposal);
        uint index;
        for (uint i = 0; i < proposals.length; i++) {
            if(proposals[i].voteCount == currentSession.highestVoteCount) {
                bestProposals[index] = proposals[i];
                currentSession.winningProposalIndex = i;
                index++;
            }
        }
        if(bestProposals.length == 1) {
            emit WinningProposition(sessionId, currentSession.winningProposalIndex);
        }
        else {
            currentSession.winningProposalIndex = 0;
            renewSession(bestProposals, currentSession.id);
            emit RenewSession(sessionId);
        }
    }

    function getMostVotedProposal(uint _sessionId) external view returns(Proposal memory) {
        Session storage currentSession = sessions[_sessionId];
        return currentSession.proposals[currentSession.winningProposalIndex];
    }

    function getAllProposals(uint _sessionId) external view returns(Proposal[] memory) {
        return sessions[_sessionId].proposals;
    }

    function getProposalDetails(uint _sessionId, uint proposalIndex) external view returns (Proposal memory ) {
        return sessions[_sessionId].proposals[proposalIndex];
    }

    function hasVoted(uint sessionId, address _address) public view returns(bool) {
         return sessions[sessionId].hasVoted[_address];
    }

    // function getHighestVoteCount
    // attention à mieux gérer le cas ou il y a plusieurs winner, avec une tableau?
}