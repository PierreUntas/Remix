// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable {

    mapping (uint => Session) sessions;
    mapping(address => Voter) public voters;
    mapping(address => bool) public whitelist;
    WorkflowStatus public workflowStatus;
    uint lastProposalId;
    uint actualSessionId;

    struct Voter {
        address voterAddress;
    }

    struct Proposal {
        uint proposalId;
        string description;
        address submitter;
        uint voteCount;
    }

    struct Session {
        uint id;
        uint winningProposalId;
        uint highestVoteCount;
        Proposal[] proposals;
        mapping (address => bool) participants;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    event NewVotingSession(uint sessionsId);
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    constructor() Ownable(msg.sender) {
    }

    function addToWhitelist(address _address) public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Registration not started");
        whitelist[_address] = true;
        emit VoterRegistered(_address);
    }

    function isWhitelisted(address _address) public view returns (bool) {
        return whitelist[_address];
    }

    function createSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "A session is already running");
        actualSessionId++;
        Session storage newSession = sessions[actualSessionId];
        newSession.id = actualSessionId;
        emit NewVotingSession(actualSessionId);
    }

    function renewSession(Proposal[] memory bestProposals) public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "A session is already running");
        actualSessionId++;
        Session storage newSession = sessions[actualSessionId];
        newSession.id = actualSessionId;
        for (uint i = 0; i < bestProposals.length; i++) {
            newSession.proposals.push(bestProposals[i]);
        }
        emit NewVotingSession(actualSessionId);
    }

    function startProposalsRegistration() public onlyOwner {
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    function sendNewProposition(string memory _description) public {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "registration did not started");
        require(whitelist[msg.sender], "You are not registered");
        Session storage currentSession = sessions[actualSessionId];
        lastProposalId++;
        currentSession.proposals.push(Proposal(lastProposalId, _description, msg.sender, 0));
        emit ProposalRegistered(lastProposalId);
    }

    function getAllProposalsBySession(uint _sessionId) external view returns(Proposal[] memory) {
        return sessions[_sessionId].proposals;
    }
    
    function endProposalsRegistration() public onlyOwner {
        require (workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals registration not started");
        // ajouter un require pour vérifier si il y a eu une proposition
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded); 
    }

    function startVotingSession() public onlyOwner {
       require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Proposals registration not ended");
       workflowStatus = WorkflowStatus.VotingSessionStarted;
       emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted); 
    }
    
    function sendVote(uint _proposalId) public {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "registration did not started");
        require(whitelist[msg.sender], "You are not registered");
        Session storage currentSession = sessions[actualSessionId];
        require(!currentSession.participants[msg.sender], "You have already vote");
        Proposal storage proposal = currentSession.proposals[_proposalId];
        proposal.voteCount++;
        currentSession.participants[msg.sender] = true;
        if(proposal.voteCount > currentSession.highestVoteCount) { 
            currentSession.highestVoteCount = proposal.voteCount;
        }
        emit Voted(msg.sender, _proposalId);
    }


    function endVotingSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting session not started");
        // ajouter un require pour vérifier si il y a eu un vote
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    function computeMostVotedProposal() public {   
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, "Voting session did not end");
        Session storage currentSession = sessions[actualSessionId];
        Proposal[] storage proposals = currentSession.proposals;
        uint numberOfBestProposal;
        for (uint i = 0; i < proposals.length; i++) {
            if(proposals[i].voteCount == currentSession.highestVoteCount)
            numberOfBestProposal++;
        }
        uint index;
        Proposal[] memory bestProposals = new Proposal[](numberOfBestProposal);
        for (uint i = 0; i < proposals.length; i++) {
            bestProposals[index] = proposals[i];
            index++;
        }
        if(bestProposals.length == 1) {
            currentSession.winningProposalId = bestProposals[0].proposalId;
            workflowStatus = WorkflowStatus.RegisteringVoters;
        }
        else {
            renewSession(bestProposals);
            workflowStatus = WorkflowStatus.RegisteringVoters;
        }
    }
}
