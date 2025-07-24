// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable {
    address public admin;
    uint public winningProposalId;
    mapping(address => bool) public whitelist;

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint voteProposalId;
    }

    struct Proposal {
        uint id;
        string description;
        uint voteCount;
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
    event WorkflowStatusChange(
        WorkflowStatus previousStatus, 
        WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    constructor() Ownable(msg.sender) {
        admin = msg.sender;
    }

    function sendNewProposition(string memory _description) public {
        // créer nouvel Id
        // creér un nouvelle porposition
    }

    function sendVote(uint _proposalId) public {
        // incrémenter le nombre de vote
        // passer le status du Voter à true
    }

    // function pour déterminer la propostion gagnante (et le gagnant)
}
