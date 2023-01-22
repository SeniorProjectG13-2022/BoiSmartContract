// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

contract Boii {

    //Global constants
    //custom constant that can set when deploy
    uint256 public periodDuration;
    uint256 public votingPeriodLength;
    uint256 public gracePeriodLength;
    uint256 public proposalDeposit;
    uint256 public dilutionBound;
    uint256 public summoningTime;

    address public depositToken; 

    //Hard-coded limition constants (using the default value of Moloch)
    uint256 constant MAX_VOTING_PERIOD_LENGTH = 10**18;
    uint256 constant MAX_GRACE_PERIOD_LENGTH = 10**18;
    uint256 constant MAX_DILUTION_BOUND = 10**18;
    uint256 constant MAX_NUMBER_OF_SHARES = 10**18;

    enum Vote {
        Null,
        Yes,
        No
    }

    //Member structure
    struct Member {
        uint256 shares;
        bool exists;
        uint256 highestIndexVote; 
        bool jailed;
    }

    //Proposal structure
    struct Proposal {
        address applicant;
        address proposer;
        address sponsor;
        uint256 sharesRequested;
        uint256 tributeOffered;
        uint256 paymentRequested;
        uint256 startPeriod;
        uint256 activePeriod;
        uint256 yesVoted;
        uint256 noVoted;
        bool[5] flags;
        string projectHash;
        uint256 maxTotalSharesAtYesVote;
        mapping(address => Vote) votesByMember;
    }
    
    //Internal contract variables
    uint256 public proposalCount;
    uint256 public totalShares;

    address public constant GUILD = address(0xdead);
    address public constant ESCROW = address(0xbeef);
    address public constant TOTAL = address(0xbabe);

    mapping (address => mapping (address => uint256)) public userTokenBalances;
    
    mapping(address => bool) public proposedToKick;
    mapping(address => Member) public members;
    mapping(uint256 => Proposal) public proposals;

    constructor(
        address _summoner,
        address _depositToken,
        uint256 _periodDuration,
        uint256 _votingPeriodLength,
        uint256 _gracePeriodLength,
        uint256 _proposalDeposit,
        uint256 _dilutionBound
    ) {
        require(_summoner != address(0), "summoner cannot be 0");
        require(_periodDuration > 0, "periodDuration must greater than 0");
        require(_votingPeriodLength > 0, "votingPeriodLength must greater than 0");
        require(_votingPeriodLength <= MAX_VOTING_PERIOD_LENGTH, "votingPeriodLength exceeds the limit");
        require(_gracePeriodLength > 0, "gracePeriodLength must greater than 0");
        require(_gracePeriodLength <= MAX_GRACE_PERIOD_LENGTH, "gracePeriodLength exceeds the limit");
        require(_dilutionBound > 0, "dilutionBound must greater than 0");
        require(_dilutionBound <= MAX_DILUTION_BOUND, "dilutionBound exceeds the limit");
        require(_depositToken != address(0), "depositToken cannot be 0");
        
        depositToken = _depositToken;
        periodDuration = _periodDuration;
        votingPeriodLength = _votingPeriodLength;
        gracePeriodLength = _gracePeriodLength;
        proposalDeposit = _proposalDeposit;
        dilutionBound = _dilutionBound;
        
        summoningTime = block.timestamp;

        members[_summoner] = Member(1, true, 0, false);
        totalShares = 1;

        // NOTE: The Moloch emit the deploy event.
    }

    //Getter and helper function
    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return x >= y ? x : y;
    }

    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp - summoningTime) / periodDuration;
    }

    function getProposalFlags(uint256 proposalId) public view returns (bool[5] memory) {
        return proposals[proposalId].flags;
    }

    function getUserTokenBalance(address user, address token) public view returns (uint256) {
        return userTokenBalances[user][token];
    }

    // FIXME: Cannot use standard ABI, Is it okay to use experimentl version ABI v.2
    // function getAllProposals() public view returns () {
    //     return proposals;
    // }

    // FIXME: add check mechanism to see if the member has already voted. There are 2 ways
    // 1) add member address as optional parameter 
    // 2) create separate function
    // function getProposalById(uint256 proposalId) public view returns (
    //     address, //applicant
    //     address, //proposer
    //     address, //sponsor
    //     uint256, //sharesRequested
    //     uint256, //tributeOffered
    //     uint256, //paymentRequested
    //     uint256, //startPeriod
    //     uint256, //activePeriod
    //     uint256, //yesVoted 
    //     uint256, //noVoted
    //     bool[5] memory, //flags 
    //     string memory, //projectHash
    //     uint256 //maxTotalSharesAtYesVote
    // ) {        
    //     return (
    //         proposals[proposalId].applicant,
    //         proposals[proposalId].proposer,
    //         proposals[proposalId].sponsor,
    //         proposals[proposalId].sharesRequested,
    //         proposals[proposalId].tributeOffered,
    //         proposals[proposalId].paymentRequested,
    //         proposals[proposalId].startPeriod,
    //         proposals[proposalId].activePeriod,
    //         proposals[proposalId].yesVoted,
    //         proposals[proposalId].noVoted,
    //         proposals[proposalId].flags, 
    //         proposals[proposalId].projectHash,
    //         proposals[proposalId].maxTotalSharesAtYesVote
    //     );
    // }

    function submitProposal(
        address applicant,
        uint256 sharesRequested,
        uint256 tributeOffered,
        uint256 paymentRequested,
        string memory projectHash
    ) public returns (uint256 proposalId) {
        require(sharesRequested + sharesRequested <= MAX_NUMBER_OF_SHARES, "too many shares requested");
        require(applicant != address(0), "applicant cannot be 0");
        require(applicant != GUILD && applicant != ESCROW && applicant != TOTAL, "applicant address cannot be reserved");
        require(members[applicant].jailed == false, "proposal applicant must not be jailed");

        // collect tribute from proposer and store it in the Moloch until the proposal is processed
        // require(IERC20(tributeToken).transferFrom(msg.sender, address(this), tributeOffered), "tribute token transfer failed");
        // unsafeAddToBalance(ESCROW, tributeToken, tributeOffered);

        bool[5] memory flags; // [sponsored, processed, didPass, cancelled, guildkick]

        _submitProposal(applicant, sharesRequested, tributeOffered, paymentRequested, projectHash, flags);
        return proposalCount - 1;
    }

    function _submitProposal(
        address applicant,
        uint256 sharesRequested, 
        uint256 tributeOffered, 
        uint256 paymentRequested, 
        string memory projectHash, 
        bool[5] memory flags
    ) internal {
        Proposal storage proposal = proposals[proposalCount];
        proposal.applicant = applicant;
        proposal.proposer = msg.sender;
        proposal.sharesRequested = sharesRequested;
        proposal.tributeOffered = tributeOffered;
        proposal.paymentRequested = paymentRequested;
        proposal.startPeriod = 0;
        proposal.activePeriod = 0;
        proposal.yesVoted = 0;
        proposal.noVoted = 0;
        proposal.flags = flags;
        proposal.projectHash = projectHash;
        proposal.maxTotalSharesAtYesVote = 0;

        proposalCount += 1;
    } 

    function getMemberProposalVote(address memberAddress, uint256 proposalId) public view returns (Vote) {
        require(members[memberAddress].exists, "member does not exist");
        return proposals[proposalId].votesByMember[memberAddress];
    }

    function unsafeAddToBalance(address user, address token, uint256 amount) internal {
        userTokenBalances[user][token] += amount;
        userTokenBalances[TOTAL][token] += amount;
    }

    function unsafeSubtractFromBalance(address user, address token, uint256 amount) internal {
        userTokenBalances[user][token] -= amount;
        userTokenBalances[TOTAL][token] -= amount;
    }

    function unsafeInternalTransfer(address from, address to, address token, uint256 amount) internal {
        unsafeSubtractFromBalance(from, token, amount);
        unsafeAddToBalance(to, token, amount);
    }

    function fairShare(uint256 balance, uint256 shares, uint256 totalShare) internal pure returns (uint256) {
        require(totalShare != 0);

        if (balance == 0) { return 0; }

        uint256 prod = balance * shares;

        if (prod / balance == shares) {
            return prod / totalShare;
        }
        return (balance / totalShare) * shares;
    }

}