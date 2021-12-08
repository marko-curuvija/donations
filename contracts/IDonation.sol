//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDonation {
    function createCampaign(
        address payable _campaignOwner,
        string memory _name,
        string memory _description,
        uint96 _dateGoal,
        uint _priceGoal
    ) external;

    function donate(uint _campaignId) external payable;
    function donateNonNativeCoins(address _tokenAddress, uint amount, uint campaignId) external;
    function withdraw(uint _campaignId) external;
    function isPriceGoalReached(uint _campaignId) external view returns(bool);
    function isDateGoalReached(uint _campaignId) external view returns(bool);
    function getDonatedAmountForCampaign(uint _campaignId) external view returns (uint);
}