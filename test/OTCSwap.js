const { expect } = require("chai");
const BN = require("ethers").BigNumber;

describe("OTCSwap contract", function () {
  let OTCSwapContract;
  let Leg1ERC20;
  let Leg2ERC20;
  
  let leg1ERC20Instance;
  let leg2ERC20Instance;
  
  let otcSwap;
  let owner;
  let leg1Addr;
  let leg2Addr;
  let extraAddr1;
  let extraAddr2;
  let addrs;

  beforeEach(async function () {
    Leg1ERC20 = await ethers.getContractFactory("ERC20Stub");
    Leg2ERC20 = await ethers.getContractFactory("ERC20Stub");
    OTCSwapContract = await ethers.getContractFactory("OTCSwap");
    [owner, swapCreator, leg1Addr, leg2Addr, extraAddr1, extraAddr2, ...addrs] = await ethers.getSigners();

    otcSwap = await OTCSwapContract.deploy();
    leg1ERC20Instance = await Leg1ERC20.deploy();
    leg2ERC20Instance = await Leg2ERC20.deploy();
    await otcSwap.deployed();
    await leg1ERC20Instance.deployed();
    await leg2ERC20Instance.deployed();
    leg1ERC20Instance.transfer(leg1Addr.address, 1000000);
    leg1ERC20Instance.connect(leg1Addr).approve(otcSwap.address, 1000000);
    leg2ERC20Instance.transfer(leg2Addr.address, 1000000);
    leg2ERC20Instance.connect(leg2Addr).approve(otcSwap.address, 1000000);
  });

  describe("Deployment", function () {

    it("Should mint and send ERC20 tokens to respective swap leg owners.", async function () {
      const leg1Balance = await leg1ERC20Instance.balanceOf(leg1Addr.address);
      expect(leg1Balance).to.equal(1000000);
      const leg2Balance = await leg2ERC20Instance.balanceOf(leg2Addr.address);
      expect(leg2Balance).to.equal(1000000);
    });

    it("Should return empty list for a new address with no swaps.", async function () {
      assertAddressHasNoSwaps(leg1Addr.address)
    });

  });

  async function assertAddressHasNoSwaps(address) {
    let swaps = await otcSwap.getSwapsFor(address);
    expect(swaps).to.eql([]);
  }

  
  describe("Swap Transactions", function () {
    it("Should return swaps that were created, for the requested users.", async function () {
      await expect(
        otcSwap.createNewSwap(
          leg1Addr.address, leg1ERC20Instance.address, 50,
          leg2Addr.address, leg2ERC20Instance.address, 100)
        )
        .to.emit(otcSwap, 'SwapCreated')
        .withArgs(
          1, owner.address,
          leg1Addr.address, leg2Addr.address, leg1ERC20Instance.address, 50,
          leg2Addr.address,leg1Addr.address, leg2ERC20Instance.address, 100
        );
        
      await expect(
        otcSwap.createNewSwap(
          extraAddr1.address, leg1ERC20Instance.address, 101,
          extraAddr2.address, leg2ERC20Instance.address, 300)
        )
        .to.emit(otcSwap, 'SwapCreated')
        .withArgs(
          2, owner.address,
          extraAddr1.address,extraAddr2.address,leg1ERC20Instance.address, 101,
          extraAddr2.address,extraAddr1.address,leg2ERC20Instance.address, 300
        );
    
      expect(await otcSwap.getSwapsFor(owner.address)).to.eql([1,2]);
      expect(await otcSwap.getSwapsFor(leg1Addr.address)).to.eql([1]);
      expect(await otcSwap.getSwapsFor(leg2Addr.address)).to.eql([1]);
      expect(await otcSwap.getSwapsFor(extraAddr1.address)).to.eql([2]);
      expect(await otcSwap.getSwapsFor(extraAddr2.address)).to.eql([2]);

      //Verify return of swap info given id.
      expect(await otcSwap.getSwapInfo(1)).to.eql([
        1, owner.address,
        leg1Addr.address, leg1ERC20Instance.address, BN.from(50), BN.from(0),
        leg2Addr.address, leg2ERC20Instance.address, BN.from(100), BN.from(0)
      ]);
    });

    
    it("Should execute swap only when both legs are funded.", async function () {
      await otcSwap.createNewSwap(
        leg1Addr.address, leg1ERC20Instance.address, 50,
        leg2Addr.address, leg2ERC20Instance.address, 100
      );
      
      await expect(
        otcSwap.connect(leg1Addr).fundSwapLeg(
          1, leg1ERC20Instance.address, 25)
        )
        .to.emit(otcSwap, 'SwapFundingStatus')
        .withArgs(
          1,
          leg1Addr.address, leg1ERC20Instance.address, 50, 25,
          leg2Addr.address, leg2ERC20Instance.address, 100, 0,
          false
        );
      
      await otcSwap.connect(leg1Addr).fundSwapLeg(1, leg1ERC20Instance.address, 25); //fund remaining of leg1
      
      await expect(
        otcSwap.connect(leg2Addr).fundSwapLeg(
          1, leg2ERC20Instance.address, 100)
        )
        .to.emit(otcSwap, 'SwapFundingStatus')
        .withArgs(
          1,
          leg1Addr.address, leg1ERC20Instance.address, 50, 50,
          leg2Addr.address, leg2ERC20Instance.address, 100, 100,
          true // Swap should execute when both legs are funded
        );
      
      const leg1BalanceOfLeg2Token = await leg2ERC20Instance.balanceOf(leg1Addr.address);
      expect(leg1BalanceOfLeg2Token).to.equal(100);
      const leg2BalanceOfLeg1Token = await leg1ERC20Instance.balanceOf(leg2Addr.address);
      expect(leg2BalanceOfLeg1Token).to.equal(50);
      
      assertAddressHasNoSwaps(leg1Addr.address)
      assertAddressHasNoSwaps(leg2Addr.address)
      
      let invalidSwapIdLookup = otcSwap.getSwapInfo(1);
      await expect(invalidSwapIdLookup).to.be.revertedWith("No swap found for given id");
    });


    it("Should execute swap even if both legs are slightly overfunded.", async function () {
      await otcSwap.createNewSwap(
        leg1Addr.address, leg1ERC20Instance.address, 50,
        leg2Addr.address, leg2ERC20Instance.address, 100
      );
      
      await otcSwap.connect(leg1Addr).fundSwapLeg(1, leg1ERC20Instance.address, 55);
      await otcSwap.connect(leg2Addr).fundSwapLeg(1, leg2ERC20Instance.address, 110);

      const leg1BalanceOfLeg2Token = await leg2ERC20Instance.balanceOf(leg1Addr.address);
      expect(leg1BalanceOfLeg2Token).to.equal(110);
      const leg2BalanceOfLeg1Token = await leg1ERC20Instance.balanceOf(leg2Addr.address);
      expect(leg2BalanceOfLeg1Token).to.equal(55);

    });

    it("Should fail when attempting to fund a fully funded leg.", async function () {
      await otcSwap.createNewSwap(
        leg1Addr.address, leg1ERC20Instance.address, 50,
        leg2Addr.address, leg2ERC20Instance.address, 100
      );
      
      await otcSwap.connect(leg1Addr).fundSwapLeg(1, leg1ERC20Instance.address, 50);
      let repeatFundingTxn = otcSwap.connect(leg1Addr).fundSwapLeg(1, leg1ERC20Instance.address, 10);
      await expect(repeatFundingTxn).to.be.revertedWith("Swap leg is already fully funded.");
    });

    it("Should fail when grossly overfunding.", async function () {
      await otcSwap.createNewSwap(
        leg1Addr.address, leg1ERC20Instance.address, 50,
        leg2Addr.address, leg2ERC20Instance.address, 100
      );
      
      let overFundedTxn = otcSwap.connect(leg1Addr).fundSwapLeg(1, leg1ERC20Instance.address, 500);
      await expect(overFundedTxn).to.be.revertedWith("funding amount exceeded deposit threshold");
    });

    it("Should fail when funding with wrong token contract.", async function () {
      let WrongERC20 = await ethers.getContractFactory("ERC20Stub");
      let wrongERC20Instance = await WrongERC20.deploy();
      await wrongERC20Instance.deployed();

      wrongERC20Instance.transfer(leg1Addr.address, 1000000);
      wrongERC20Instance.connect(leg1Addr).approve(otcSwap.address, 1000000);

      await otcSwap.createNewSwap(
        leg1Addr.address, leg1ERC20Instance.address, 50,
        leg2Addr.address, leg2ERC20Instance.address, 100
      );
      
      let wrongTokenFunding = otcSwap.connect(leg1Addr).fundSwapLeg(1, wrongERC20Instance.address, 50);
      await expect(wrongTokenFunding).to.be.revertedWith("Provided token address does not match that of the funding leg");
    });


    it("Should allow funding only be relevant address for easier refunds.", async function () {
      leg1ERC20Instance.connect(leg1Addr).transfer(extraAddr1.address, 1000);
      leg1ERC20Instance.connect(extraAddr1).approve(otcSwap.address, 1000000);

      await otcSwap.createNewSwap(
        leg1Addr.address, leg1ERC20Instance.address, 50,
        leg2Addr.address, leg2ERC20Instance.address, 100
      );
      
      let unauthorizedFunding = otcSwap.connect(extraAddr1).fundSwapLeg(1, leg1ERC20Instance.address, 50);
      await expect(unauthorizedFunding).to.be.revertedWith("Funding address is not from either of the legs.");
    });

    it("Should refund tokens and delete swap when cancelled by relevant parties.", async function () {
      await otcSwap.createNewSwap(
        leg1Addr.address, leg1ERC20Instance.address, 50,
        leg2Addr.address, leg2ERC20Instance.address, 100
      );
      
      await otcSwap.connect(leg1Addr).fundSwapLeg(1, leg1ERC20Instance.address, 50);
      await otcSwap.connect(leg2Addr).fundSwapLeg(1, leg2ERC20Instance.address, 50); //half funded so swap doesn't execute

      await expect(otcSwap.connect(leg2Addr).cancelAndRefundSwap(1))
        .to.emit(otcSwap, 'SwapRefunded')
        .withArgs(
            1,
            owner.address,
            leg1Addr.address, leg1ERC20Instance.address, 50,
            leg2Addr.address, leg2ERC20Instance.address, 50
        );

      const leg1Balance = await leg1ERC20Instance.balanceOf(leg1Addr.address);
      expect(leg1Balance).to.equal(1000000);
      const leg2Balance = await leg2ERC20Instance.balanceOf(leg2Addr.address);
      expect(leg2Balance).to.equal(1000000);

      let invalidSwapIdLookup = otcSwap.getSwapInfo(1);
      await expect(invalidSwapIdLookup).to.be.revertedWith("No swap found for given id");
    });

  });

});
