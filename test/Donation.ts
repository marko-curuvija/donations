import { expect } from "chai";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Collectible, Donation, IERC20 } from "../typechain";
import { BigNumberish } from "ethers";
import {getCurrentTimestamp} from "hardhat/internal/hardhat-network/provider/utils/getCurrentTimestamp";

describe("Donation", function () {
  let Donation;
  let donation: Donation;
  let daiToken: IERC20;
  let collectible: Collectible;
  let owner: SignerWithAddress;
  let address1: SignerWithAddress;
  let dateGoal: BigNumberish;

  const name = "Campaign 1";
  const description = "description";
  const priceGoal = ethers.utils.parseEther("0.005");
  const donationAmount = ethers.utils.parseEther("0.002");
  const hre = require("hardhat");
  const daiTokenAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
  const daiWalletAddress = "0x1e3d6eab4bcf24bcd04721caa11c478a2e59852d";
  const wethTokenAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  const swapRouterAddress = "0xE592427A0AEce92De3Edee1F18E0157C05861564";

  beforeEach(async () => {
    Donation = await ethers.getContractFactory("Donation");
    [owner, address1] = await ethers.getSigners();
    donation = await Donation.deploy(swapRouterAddress, wethTokenAddress);

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    dateGoal = block.timestamp + 600;

    await donation.createCampaign(
      owner.address,
      name,
      description,
      dateGoal,
      priceGoal
    );
  });

  describe("Create campaign", function () {
    it("Owner should be able to create new campaign", async function () {
      await donation.createCampaign(
        owner.address,
        name,
        description,
        dateGoal,
        priceGoal
      );
      const campaign = await donation.campaigns(1);
      expect(campaign.campaignOwner).to.equal(owner.address);
      expect(campaign.name).to.equal(name);
      expect(campaign.description).to.equal(description);
      expect(campaign.dateGoal).to.equal(dateGoal);
      expect(campaign.priceGoal).to.equal(priceGoal);
    });

    it("CreateCampaign event should be fired when new capaign is created", async function () {
      const createCampaign = donation.createCampaign(
        owner.address,
        name,
        description,
        dateGoal,
        priceGoal
      );
      expect(createCampaign)
        .to.emit(donation, "CreateCampaign")
        .withArgs(name, 1);
    });

    it("Account that is not owner should not be able to create new campaign", async function () {
      expect(
        donation
          .connect(address1)
          .createCampaign(
            address1.address,
            name,
            description,
            dateGoal,
            priceGoal
          )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Withdraw", function () {
    it("Should withdraw funds from campaign", async function () {
      await donation.connect(address1).donate(0, { value: donationAmount });

      const withdraw = donation.withdraw(0);
      expect(() => withdraw).to.changeEtherBalance(owner, donationAmount);
    });

    it("Withdraw event should be fired when someone withdraws donations from campaign", async function () {
      await donation.connect(address1).donate(0, { value: donationAmount });
      const withdraw = donation.withdraw(0);
      expect(withdraw)
        .to.emit(donation, "Withdraw")
        .withArgs(0, donationAmount);
    });

    it("Should not withdraw funds if someone who is not campaignOwner tries to withdraw", async function () {
      await donation.connect(address1).donate(0, { value: donationAmount });

      expect(donation.connect(address1).withdraw(0)).to.be.revertedWith(
        "Only campaign owner can withdraw donations"
      );
    });

    it("Should not withdraw funds if campaign amount is 0", async function () {
      expect(donation.withdraw(0)).to.be.revertedWith(
        "There are no funds to be withdrawn"
      );
    });
  });

  describe("Donate", function () {
    it("Should be able to donate to campaign", async function () {
      const donate = await donation
        .connect(address1)
        .donate(0, { value: donationAmount });
      const campaign = await donation.campaigns(0);
      const donor = await donation
        .connect(address1)
        .getDonatedAmountForCampaign(0);
      expect(campaign.amount).to.be.equal(donationAmount);
      expect(donor).to.be.equal(donationAmount);
      expect(() => donate).to.changeEtherBalance(donation, donationAmount);
    });

    it("Should be able to donate non native tokens to campaign", async function () {
      daiToken = await ethers.getContractAt("IERC20", daiTokenAddress);
      await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [daiWalletAddress],
      });
      const walletSigner = await ethers.getSigner(daiWalletAddress);
      await daiToken
        .connect(walletSigner)
        .approve(donation.address, ethers.utils.parseUnits("20", 18));
      await donation
        .connect(walletSigner)
        .donateNonNativeCoins(
          daiTokenAddress,
          ethers.utils.parseUnits("20", 18),
          500,
          getCurrentTimestamp(),
          0,
          0
        );
      const campaign = await donation.campaigns(0);
      expect(campaign.amount).to.be.above(0);
      expect(await donation.provider.getBalance(donation.address)).to.be.above(
        0
      );
    });

    it("Should receive NFT after first donation", async function () {
      const collectibleAddress = await donation.collectible();
      collectible = (await ethers.getContractAt(
        "Collectible",
        collectibleAddress
      )) as Collectible;
      await donation.connect(address1).donate(0, { value: donationAmount });
      expect(await collectible.ownerOf(0)).to.be.equal(address1.address);
    });

    it("Should not receive NFT if account already donated to campaign", async function () {
      const collectibleAddress = await donation.collectible();
      collectible = (await ethers.getContractAt(
        "Collectible",
        collectibleAddress
      )) as Collectible;
      await donation.connect(address1).donate(0, { value: donationAmount });
      await donation.connect(address1).donate(0, { value: donationAmount });
      expect(collectible.ownerOf(1)).to.be.revertedWith(
        "ERC721: owner query for nonexistent token"
      );
    });

    it("Donate event should be fired when someone donates to campaign", async function () {
      const donate = await donation
        .connect(address1)
        .donate(0, { value: donationAmount });
      await expect(donate)
        .to.emit(donation, "Donate")
        .withArgs(address1.address, 0, donationAmount);
    });

    it("Should not be able to donate if price goal has been reached", async function () {
      await donation.donate(0, { value: priceGoal });

      await expect(
        donation.donate(0, { value: donationAmount })
      ).to.be.revertedWith("Campaign has reached price goal");
    });

    it("Should donate amount to reach goal and return change to donor", async function () {
      const exceedingPriceGoalDonation = ethers.utils.parseEther("0.007");
      const donate = donation
        .connect(address1)
        .donate(0, { value: exceedingPriceGoalDonation });

      await expect(() => donate).to.changeEtherBalances(
        [address1, donation],
        [-priceGoal, priceGoal]
      );
    });

    it("PriceGoalReached event should be fired when price goal is reached on campaign", async function () {
      const exceedingPriceGoalDonation = ethers.utils.parseEther("0.007");
      const donate = donation
        .connect(address1)
        .donate(0, { value: exceedingPriceGoalDonation });

      expect(donate)
        .to.emit(donation, "PriceGoalReached")
        .withArgs(0, priceGoal);
    });

    it("Should not be able to donate if date goal has passed", async function () {
      await network.provider.send("evm_increaseTime", [900]);

      expect(donation.donate(0, { value: donationAmount })).to.be.revertedWith(
        "Campaign has reached date goal"
      );
    });
  });
});
