//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './Collectible.sol';
import './IDonation.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryPayments.sol";

/// @title Contract for donations
/// @author Marko Curuvija
contract Donation is IDonation, Ownable, ReentrancyGuard {

    using Counters for Counters.Counter;
    struct Campaign {
        address payable campaignOwner;
        uint96 dateGoal;
        string name;
        string description;
        uint priceGoal;
        uint amount;
        mapping(address => uint) donors;
    }

    address payable immutable wethAddress;
    Counters.Counter campaignId;
    mapping(uint => Campaign) public campaigns;
    Collectible public immutable collectible;
    ISwapRouter public immutable swapRouter;

    event Donate(address _from, uint _campaignId, uint _amount);
    event CreateCampaign(string _name, uint _campaignId);
    event Withdraw(uint _campaignId, uint amount);
    event PriceGoalReached(uint _campaignId, uint _priceGoal);

    /// @dev function that checks if campaign price or date goal has been reached
    modifier goalNotReached(uint _campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        require(
            campaign.dateGoal >= block.timestamp, "Campaign has reached date goal"
        );
        require(
            campaign.priceGoal != campaign.amount, "Campaign has reached price goal"
        );
        _;
    }

    modifier valueAboveZero(uint _value) {
        require(_value > 0, "Value must be greater than 0");
        _;
    }

    constructor(ISwapRouter _swapRouter, address payable _weth9) {
        collectible = new Collectible();
        swapRouter = _swapRouter;
        wethAddress = _weth9;
    }

    /// @inheritdoc IDonation
    function createCampaign(
        address payable _campaignOwner,
        string memory _name,
        string memory _description,
        uint96 _dateGoal,
        uint _priceGoal
    ) public override onlyOwner {
        uint id = campaignId.current();
        Campaign storage campaign = campaigns[id];
        campaign.campaignOwner = _campaignOwner;
        campaign.name = _name;
        campaign.description = _description;
        campaign.dateGoal = _dateGoal;
        campaign.priceGoal = _priceGoal;
        campaignId.increment();
        emit CreateCampaign(_name, id);
    }

    /// @inheritdoc IDonation
    function donateNative(uint _campaignId) public override payable goalNotReached(_campaignId) valueAboveZero(msg.value) {
        Campaign storage campaign = campaigns[_campaignId];
        uint donation = msg.value;
        uint change = calculateAndReturnChange(msg.value, campaign.amount, campaign.priceGoal, _campaignId);
        donation -= change;
        sendCollectibleIfFirstDonation(campaign, msg.sender);
        updateCampaignWithDonation(msg.sender, campaign, donation, _campaignId);
    }

    /// @inheritdoc IDonation
    function donateNonNative(
        bytes memory _path,
        address _tokenAddress,
        uint _amount,
        uint _deadline,
        uint _campaignId
    ) public override goalNotReached(_campaignId) valueAboveZero(_amount){
        Campaign storage campaign = campaigns[_campaignId];
        uint donation = _swapTokens(
            _path,
            _tokenAddress,
            msg.sender,
            address(this),
            _amount,
            _deadline
        );
        uint change = calculateAndReturnChange(donation, campaign.amount, campaign.priceGoal, _campaignId);
        donation -= change;
        IPeripheryPayments(address(swapRouter)).unwrapWETH9(donation, address(this));
        sendCollectibleIfFirstDonation(campaign, msg.sender);
        updateCampaignWithDonation(msg.sender, campaign, donation, _campaignId);
    }

    /// @inheritdoc IDonation
    function withdraw(uint _campaignId) public override nonReentrant {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.campaignOwner, "Only campaign owner can withdraw donations");
        require(campaign.amount > 0, "There are no funds to be withdrawn");
        uint valueToWithdraw = campaign.amount;
        campaign.amount = 0;
        (bool sent,) = msg.sender.call{value : valueToWithdraw}("");
        require(sent, "Failed to send Ether");
        emit Withdraw(_campaignId, valueToWithdraw);
    }

    /// @inheritdoc IDonation
    function isPriceGoalReached(uint _campaignId) public override view returns (bool) {
        Campaign storage campaign = campaigns[_campaignId];
        return campaign.priceGoal - campaign.amount <= 0;
    }

    /// @inheritdoc IDonation
    function isDateGoalReached(uint _campaignId) public override view returns (bool) {
        Campaign storage campaign = campaigns[_campaignId];
        return campaign.dateGoal <= block.timestamp;
    }

    /// @inheritdoc IDonation
    function getDonatedAmountForCampaign(uint _campaignId) public override view returns (uint) {
        Campaign storage campaign = campaigns[_campaignId];
        return (campaign.donors[msg.sender]);
    }

    function _swapTokens(
        bytes memory _path,
        address _tokenIn,
        address _sender,
        address _recipient,
        uint _amount,
        uint _deadline
    ) private returns (uint amountOut) {
        TransferHelper.safeTransferFrom(_tokenIn, _sender, _recipient, _amount);
        TransferHelper.safeApprove(_tokenIn, address(swapRouter), _amount);

        ISwapRouter.ExactInputParams memory params =
        ISwapRouter.ExactInputParams({
        path: _path,
        recipient : address(swapRouter),
        deadline : _deadline,
        amountIn : _amount,
        amountOutMinimum : 0
        });

        amountOut = swapRouter.exactInput(params);
    }

    function sendCollectibleIfFirstDonation(Campaign storage _campaign, address _donor) private {
        if (_campaign.donors[_donor] == 0) {
            collectible.createCollectible(_donor);
        }
    }

    function updateCampaignWithDonation(
        address _donor,
        Campaign storage _campaign,
        uint _donation,
        uint _campaignId
    ) private {
        _campaign.amount += _donation;
        _campaign.donors[_donor] += _donation;
        emit Donate(_donor, _campaignId, _donation);
    }

    function calculateAndReturnChange(uint _donation, uint _collected, uint _priceGoal, uint _campaignId) private returns(uint) {
        uint change = 0;
        if (_collected + _donation > _priceGoal) {
            change = _donation - (_priceGoal - _collected);
            emit PriceGoalReached(_campaignId, _priceGoal);
        }
        (bool sent,) = msg.sender.call{value : change}("");
        require(sent, "Failed to send Ether");
        return change;
    }

    receive() external payable {

    }
}
