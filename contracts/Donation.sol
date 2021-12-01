//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Collectible.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface IDonation {
    function createCampaign(
        address payable _campaignOwner,
        string memory _name,
        string memory _description,
        uint96 _dateGoal,
        uint _priceGoal
    ) external;

    function donate(uint _campaignId) external payable;
    function withdraw(uint _campaignId) external;
    function isPriceGoalReached(uint _campaignId) external view returns(bool);
    function isDateGoalReached(uint _campaignId) external view returns(bool);
    function getDonatedAmountForCampaign(uint _campaignId) external view returns (uint);
}


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

    Counters.Counter campaignId;
    mapping(uint => Campaign) public campaigns;
    Collectible public collectible;

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

    constructor() {
        collectible = new Collectible();
    }

    /// @notice function that allows contract owner to create new campaign
    /// @param _campaignOwner The address of the owner for campaign
    /// @param _name Name of campaign
    /// @param _description Description of campaign
    /// @param _dateGoal Date when campaign will end
    /// @param _priceGoal Donation goal of campaign
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

    /// @notice Donates sent amount to desired campaign
    /// @param _campaignId Id of campaign which will receive donation
    function donate(uint _campaignId) public override payable goalNotReached(_campaignId) {
        require(msg.value > 0, "Value must be greater than 0");
        Campaign storage campaign = campaigns[_campaignId];
        uint donation = msg.value;
        if(campaign.amount + donation > campaign.priceGoal) {
            donation = campaign.priceGoal - campaign.amount;
            uint change = msg.value - donation;
            (bool sent,) = msg.sender.call{value: change}("");
            require(sent, "Failed to send Ether");
            emit PriceGoalReached(_campaignId, campaign.priceGoal);
        }
        if(campaign.donors[msg.sender] == 0) {
            collectible.createCollectible(msg.sender);
        }
        campaign.amount += donation;
        campaign.donors[msg.sender] += donation;
        emit Donate(msg.sender, _campaignId, donation);
    }

    /// @notice Withdraws collected donations from campaign to owner of campaign
    /// @param _campaignId Id of campaign from which donations will be withdrawn
    function withdraw(uint _campaignId) public override nonReentrant {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.campaignOwner, "Only campaign owner can withdraw donations");
        require(campaign.amount > 0, "There are no funds to be withdrawn");
        uint valueToWithdraw = campaign.amount;
        campaign.amount = 0;
        (bool sent, ) = msg.sender.call{value: valueToWithdraw}("");
        require(sent, "Failed to send Ether");
        emit Withdraw(_campaignId, valueToWithdraw);
    }

    /// @notice Returns information if price goal of campaign is reached
    /// @param _campaignId Id of campaign
    function isPriceGoalReached(uint _campaignId) public override view returns(bool) {
        Campaign storage campaign = campaigns[_campaignId];
        return campaign.priceGoal - campaign.amount <= 0;
    }

    /// @notice Returns information if date goal of campaign has passed
    /// @param _campaignId Id of campaign
    function isDateGoalReached(uint _campaignId) public override view returns(bool) {
        Campaign storage campaign = campaigns[_campaignId];
        return campaign.dateGoal <= block.timestamp;
    }

    function getDonatedAmountForCampaign(uint _campaignId) public override view returns (uint) {
        Campaign storage campaign = campaigns[_campaignId];
        return(campaign.donors[msg.sender]);
    }
}
