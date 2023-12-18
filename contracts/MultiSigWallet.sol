// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MultiSigWallet
 * @dev A multi-signature wallet with proposal and execution functionalities.
 * Directors can create and execute proposals to modify wallet parameters, such as the receiver wallet address, wallet name, and the USD value of ETH for triggering transfers.
 */
contract MultiSigWallet {
    using SafeERC20 for IERC20;
    uint256 public nextProposalId;

    // Directors' wallet addresses
    address public director1;
    address public director2;

    // Wallet parameters
    string public name;
    uint256 public usdValue;
    address public receiverWallet1;
    address public receiverWallet2;

    // Chainlink ETH/USD Price Feed
    AggregatorV3Interface public ethUSD_PriceFeed;

    // Proposal status enumeration
    enum ProposalStatus {
        Pending,
        Accepted,
        Rejected
    }

    // Proposal structure
    struct Proposal {
        uint256 id;
        address creator;
        address executor;
        ProposalStatus status;
        address receiverWallet1;
        address receiverWallet2;
        string name;
        uint256 usdValue;
    }

    // Mapping of proposal ID to Proposal
    mapping(uint256 => Proposal) public proposals;

    // Events
    event ProposalCreated(uint256 id, address creator);
    event ProposalExecuted(uint256 id, address executor);
    event ProposalStatusChanged(
        uint256 id,
        address executor,
        ProposalStatus status
    );
    event FundsReceived(address indexed sender, uint256 amount);

    // Modifiers
    /**
     * @dev Modifier to restrict function access to directors only.
     */
    modifier onlyDirector() {
        require(
            msg.sender == director1 || msg.sender == director2,
            "Not authorized"
        );
        _;
    }

    /**
     * @dev Modifier to ensure that the sender is not the creator of the proposal.
     */
    modifier notCreator(uint256 proposalId) {
        require(
            proposals[proposalId].creator != msg.sender,
            "Proposal creator cannot execute the action"
        );
        _;
    }

    /**
     * @dev Contract constructor.
     * @param initialDirectors Array containing the initial directors' wallet addresses.
     * @param _name Initial wallet name.
     * @param _usdValue Initial USD value for triggering transfers.
     * @param _receiverWallet1 Initial receiver1 wallet address.
     * @param _receiverWallet2 Initial receiver2 wallet address.
     * @param _priceFeed Address of the Chainlink ETH/USD Price Feed.
     */
    constructor(
        address[] memory initialDirectors,
        string memory _name,
        uint256 _usdValue,
        address _receiverWallet1,
        address _receiverWallet2,
        address _priceFeed
    ) {
        require(initialDirectors.length == 2, "Two directors required");
        require(
            initialDirectors[0] != initialDirectors[1],
            "Different wallets required"
        );
        require(
            initialDirectors[0] != address(0) &&
                initialDirectors[1] != address(0),
            "Zero address not allowed"
        );
        require(_receiverWallet1 != address(0), "Zero address not allowed");
        require(_receiverWallet2 != address(0), "Zero address not allowed");
        require(_priceFeed != address(0), "Zero address not allowed");

        director1 = initialDirectors[0];
        director2 = initialDirectors[1];
        name = _name;
        usdValue = _usdValue;
        receiverWallet1 = _receiverWallet1;
        receiverWallet2 = _receiverWallet2;
        ethUSD_PriceFeed = AggregatorV3Interface(_priceFeed);
    }

    /**
     * @dev Creates a new proposal for modifying wallet parameters.
     * @param _receiverWallet1 New receiver1 wallet address.
     * @param _receiverWallet2 New receiver2 wallet address.
     * @param _name New wallet name.
     * @param _usdValue New USD value for triggering transfers.
     */
    function makeProposal(
        address _receiverWallet1,
        address _receiverWallet2,
        string memory _name,
        uint256 _usdValue
    ) external onlyDirector {
        require(
            _receiverWallet1 != address(0) ||
                _receiverWallet2 != address(0) ||
                bytes(_name).length > 0 ||
                _usdValue > 0,
            "invalid proposal"
        );
        uint256 proposalId = nextProposalId++;
        proposals[proposalId] = Proposal({
            id: proposalId,
            creator: msg.sender,
            executor: address(0),
            status: ProposalStatus.Pending,
            receiverWallet1: _receiverWallet1,
            receiverWallet2: _receiverWallet2,
            name: _name,
            usdValue: _usdValue
        });

        emit ProposalCreated(proposalId, msg.sender);
    }

    /**
     * @dev Executes an accepted proposal to modify wallet parameters.
     * @param proposalId ID of the proposal to execute.
     * @param accept Boolean flag indicating whether the proposal is accepted.
     */
    function executeAction(
        uint256 proposalId,
        bool accept
    ) external onlyDirector notCreator(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.creator != address(0), "Proposal does not exist");
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
            if (proposal.receiverWallet1 != address(0)) {
                receiverWallet1 = proposal.receiverWallet1;
            }
            if (proposal.receiverWallet2 != address(0)) {
                receiverWallet2 = proposal.receiverWallet2;
            }
            if (proposal.usdValue > 0) {
                usdValue = proposal.usdValue;
            }

            emit ProposalExecuted(proposalId, msg.sender);
        } else {
            // Reject the proposal
            proposal.status = ProposalStatus.Rejected;
        }

        emit ProposalStatusChanged(proposalId, msg.sender, proposal.status);
    }

    /**
     * @dev Checks if the ETH balance in USD value is greater than or equal to the specified threshold.
     * @return A boolean indicating whether the ETH balance is sufficient.
     */
    function checkEthBalanceVsUSD() external view returns (bool) {
        require(usdValue > 0, "USD value must be greater than 0");

        uint256 usdPrice = getPrice();

        require(usdPrice > 0, "Invalid ETH/USD price");

        uint256 ethBalance = address(this).balance;
        uint256 ethValueInUSD = (ethBalance * usdPrice) / 1e8; // 1e8 is the Chainlink decimals for USD/ETH

        return ethValueInUSD >= usdValue;
    }

    /**
     * @dev Gets the latest ETH/USD price from the Chainlink aggregator.
     * @return The latest ETH/USD price.
     */
    function getPrice() public view returns (uint256) {
        (, int256 price, , , ) = ethUSD_PriceFeed.latestRoundData();

        return (uint256(price) * 10 ** 10);
    }

    /**
     * @dev Transfers half of the funds from the contract to two receiver wallets.
     * @param tokenAddress Address of the ERC20 token or address(0) for Ether.
     */
    function transferFunds(address tokenAddress) external {
        uint256 balance = getBalance(tokenAddress);
        require(balance > 0, "No funds to transfer");

        // Calculate half of the balance
        uint256 amountToSend = balance / 2;

        // Transfer funds to receiverWallet1
        transferToken(tokenAddress, receiverWallet1, amountToSend);

        // Transfer funds to receiverWallet2
        transferToken(tokenAddress, receiverWallet2, amountToSend);
    }

    /**
     * @dev Receive function to handle incoming Ether transactions.
     */
    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    /**
     * @dev Gets the balance of the contract in Ether or ERC20 tokens.
     * @param tokenAddress Address of the ERC20 token or address(0) for Ether.
     * @return The current balance of the contract.
     */
    function getBalance(address tokenAddress) public view returns (uint256) {
        if (tokenAddress == address(0)) {
            // Ether balance
            return address(this).balance;
        } else {
            // ERC20 token balance
            return IERC20(tokenAddress).balanceOf(address(this));
        }
    }

    /**
     * @dev Transfers Ether or ERC20 tokens to the specified address.
     * @param tokenAddress Address of the ERC20 token or address(0) for Ether.
     * @param to Address to receive the funds.
     * @param amount Amount of Ether or ERC20 tokens to transfer.
     */
    function transferToken(
        address tokenAddress,
        address to,
        uint256 amount
    ) internal {
        if (tokenAddress == address(0)) {
            // Transfer Ether
            (bool success, ) = to.call{value: amount}("");
            require(success, "Transfer failed");
        } else {
            // Transfer ERC20 token
            IERC20(tokenAddress).safeTransfer(to, amount);
        }
    }
}
