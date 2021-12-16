//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDonation {
    /**
     * Creates new campaign
     *
     * @param _campaignOwner - The address of the owner for campaign
     * @param _name - Name of campaign
     * @param _description - Description of campaign
     * @param _dateGoal - Date when campaign will end and will not accept donations anymore
     * @param _priceGoal - Donation goal of campaign after it will not accept donations anymore
     *
     * No return, reverts on error
     */
    function createCampaign(
        address payable _campaignOwner,
        string memory _name,
        string memory _description,
        uint96 _dateGoal,
        uint _priceGoal
    ) external;

    /**
     * Donates native coins to desired campaign
     *
     * @param _campaignId - Id of campaign which will receive donation
     *
     * No return, reverts on error
     */
    function donateNative(uint _campaignId) external payable;

    /**
     * Donates non native tokens to campaign
     *
     * @param _tokenAddress - Address of ERC20 token that will be donated
     * @param _amount - Amount of tokens that will be donated
     * @param _deadline - UNIX timestamp of deadline for swap to happen
     * @param _campaignId - Id of campaign which will receive donation
     *
     * No return, reverts on error
     */
    function donateNonNative(
        bytes memory _path,
        address _tokenAddress,
        uint _amount,
        uint _deadline,
        uint _campaignId
    ) external;

    /**
     * Withdraws collected donations from campaign to owner of campaign
     *
     * @param _campaignId - Id of campaign from which donations will be withdrawn
     *
     * No return, reverts on error
    */
    function withdraw(uint _campaignId) external;

    /**
     * Returns information if price goal of campaign is reached
     *
     * @param _campaignId - Id of campaign
     *
     * @return boolean
    */
    function isPriceGoalReached(uint _campaignId) external view returns(bool);

    /**
     * Returns information if date goal of campaign is reached
     *
     * @param _campaignId - Id of campaign
     *
     * @return boolean
    */
    function isDateGoalReached(uint _campaignId) external view returns(bool);

    /**
     * Returns donated amount by sender to campaign
     *
     * @param _campaignId - Id of campaign
     *
     * @return uint
    */
    function getDonatedAmountForCampaign(uint _campaignId) external view returns (uint);
}