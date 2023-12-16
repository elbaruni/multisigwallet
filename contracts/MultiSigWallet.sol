// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract MultiSigWallet {
    uint256 public nextProposalId;
    address public director1;
    address public director2;
    string public name;
    uint256 public usdValue;
    address public receiverWallet;

    AggregatorV3Interface public ethUSD_PriceFeed;
    enum ProposalStatus {
        Pending,
        Accepted,
        Rejected
    }

    struct Proposal {
        uint256 id;
        address creator;
        address executor;
        ProposalStatus status;
        address receiverWallet;
        string name;
        uint256 usdValue;
    }

    mapping(uint256 => Proposal) public proposals;

    event ProposalCreated(uint256 id, address creator);
    event ProposalExecuted(uint256 id, address executor);
    event ProposalStatusChanged(
        uint256 id,
        address executor,
        ProposalStatus status
    );
    event FundsReceived(address indexed sender, uint256 amount);

    modifier onlyDirector() {
        require(
            msg.sender == director1 || msg.sender == director2,
            "Not authorized"
        );
        _;
    }

    modifier notCreator(uint256 proposalId) {
        require(
            proposals[proposalId].creator != msg.sender,
            "proposal creator can not execute the action"
        );
        _;
    }

    constructor(
        address[] memory initialDirectors,
        string memory _name,
        uint256 _usdValue,
        address _receiverWallet,
        address _priceFeed
    ) {
        require(initialDirectors.length == 2, "Two directors required");
        require(
            initialDirectors[0] != initialDirectors[1],
            "different wallets required"
        );
        require(initialDirectors[0] != address(0), "zero address not allowed");
        require(initialDirectors[1] != address(0), "zero address not allowed");
        require(_receiverWallet != address(0), "zero address not allowed");
        require(_priceFeed != address(0), "zero address not allowed");
        director1 = initialDirectors[0];
        director2 = initialDirectors[1];
        name = _name;
        usdValue = _usdValue;
        receiverWallet = _receiverWallet;
        ethUSD_PriceFeed = AggregatorV3Interface(_priceFeed);
    }

    function makeProposal(
        address _receiverWallet,
        string memory _name,
        uint256 _usdValue
    ) external onlyDirector {
        uint256 proposalId = nextProposalId++;
        proposals[proposalId] = Proposal({
            id: proposalId,
            creator: msg.sender,
            executor: address(0),
            status: ProposalStatus.Pending,
            receiverWallet: _receiverWallet,
            name: _name,
            usdValue: _usdValue
        });

        emit ProposalCreated(proposalId, msg.sender);
    }

    function executeAction(
        uint256 proposalId,
        bool accept
    ) external onlyDirector notCreator(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(
            proposal.status == ProposalStatus.Pending,
            "Proposal already executed or rejected"
        );

        if (accept) {
            // Execute the proposal action
            proposal.executor = msg.sender;
            proposal.status = ProposalStatus.Accepted;

            // Update the state variables
            if (bytes(proposal.name).length > 0) {
                name = proposal.name;
            }
            if (proposal.receiverWallet != address(0)) {
                receiverWallet = proposal.receiverWallet;
            }
            if (proposal.usdValue > 0) {
                usdValue = proposal.usdValue;
            }

            // You can also update other state variables here

            emit ProposalExecuted(proposalId, msg.sender);
        } else {
            // Reject the proposal
            proposal.status = ProposalStatus.Rejected;
        }

        emit ProposalStatusChanged(proposalId, msg.sender, proposal.status);
    }

    function transferFunds() external {
        (bool success, ) = receiverWallet.call{value: address(this).balance}(
            ""
        );
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    function checkEthBalanceVsUSD() external view returns (bool) {
        require(usdValue > 0, "USD value must be greater than 0");

        uint256 usdPrice = getPrice();

        require(usdPrice > 0, "Invalid ETH/USD price");

        uint256 ethBalance = address(this).balance;
        uint256 ethValueInUSD = (ethBalance * usdPrice) / 1e8; // 1e8 is the Chainlink decimals for USD/ETH

        return ethValueInUSD >= usdValue;
    }

    function getPrice() public view returns (uint256) {
        (, int256 price, , , ) = ethUSD_PriceFeed.latestRoundData();

        return (uint256(price) * 10 ** 10);
    }

    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }
}
