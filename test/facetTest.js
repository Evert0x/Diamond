/* eslint-disable prefer-const */
/* global contract artifacts web3 before it assert */
const { parseEther } = require('ethers/lib/utils')
const Diamond = artifacts.require('Diamond')
const DiamondCutFacet = artifacts.require('DiamondCutFacet')
const DiamondLoupeFacet = artifacts.require('DiamondLoupeFacet')
const OwnershipFacet = artifacts.require('OwnershipFacet')
const CallFacet = artifacts.require('CallFacet')
const BasketFacet = artifacts.require('BasketFacet')
const Comp = artifacts.require('Comp')
const ERC20Facet = artifacts.require('ERC20Facet')
const GovernorAlpha = artifacts.require('GovernorAlpha')
let zeroAddress = '0x0000000000000000000000000000000000000000'
contract('FacetTest', async accounts => {
    let diamond;
    let diamondCutFacet
    let diamondLoupeFacet
    let callFacet;
    let basketFacet;
    let addresses
    let erc20Facet;

    function getSelectors (contract) {
      const selectors = contract.abi.reduce((acc, val) => {
        if (val.type === 'function') {
          acc.push(val.signature)
          return acc
        } else {
          return acc
        }
      }, [])
      return selectors
    }

    before(async () => {
        web3.eth.defaultAccount = accounts[0]
        diamond = await Diamond.deployed()
        diamondCutFacet = new web3.eth.Contract(DiamondCutFacet.abi, diamond.address)
        diamondLoupeFacet = new web3.eth.Contract(DiamondLoupeFacet.abi, diamond.address)
        const ownershipFacet = new web3.eth.Contract(OwnershipFacet.abi, diamond.address)
        callFacet = await CallFacet.deployed()
        basketFacet = await BasketFacet.deployed()
        erc20Facet = await ERC20Facet.deployed()
        addresses = await diamondLoupeFacet.methods.facetAddresses().call()

        // Attach callFacet to diamond
        let selectors = getSelectors(callFacet)
        addresses.push(callFacet.address)
        await diamondCutFacet.methods.diamondCut(
          [[callFacet.address, selectors]], zeroAddress, '0x'
        ).send({ from: web3.eth.defaultAccount, gas: 1000000 })

        // Attach basketFacet to diamond
        selectors = getSelectors(basketFacet)
        addresses.push(basketFacet.address)
        await diamondCutFacet.methods.diamondCut(
          [[basketFacet.address, selectors]], zeroAddress, '0x'
        ).send({ from: web3.eth.defaultAccount, gas: 1000000 })

        // Attach erc20facet to diamond
        selectors = getSelectors(erc20Facet)
        addresses.push(erc20Facet.address)
        await diamondCutFacet.methods.diamondCut(
          [[erc20Facet.address, selectors]], zeroAddress, '0x'
        ).send({ from: web3.eth.defaultAccount, gas: 1000000 })

        // Reinitialize both callFacet, basketFacet and erc20Facet.
        // Using the diamond address
        callFacet = new web3.eth.Contract(CallFacet.abi, diamond.address);
        basketFacet = new web3.eth.Contract(BasketFacet.abi, diamond.address);
        erc20Facet = new web3.eth.Contract(ERC20Facet.abi, diamond.address);
    });

    // the amounts in this test are not realistic
    //    see Comp.sol @ getPriorVotes
    //    see BasketFacet.sol @ joinPool
    // the compound contracts are heavily edited for testing purposes
    it.only('Join comp pool and vote', async () => {
        diamond = await Diamond.deployed()
        comp = await Comp.deployed()
        gov = await GovernorAlpha.deployed()

        // transfer initial tokens (otherwise initialize fails)
        await comp.transfer(diamond.address, parseEther("1"));

        // initalize facet
        await basketFacet.methods.initialize(
          [comp.address]
        ).send({from: web3.eth.defaultAccount, gas: 1000000});

        await erc20Facet.methods.initialize(
          parseEther("1"), "TEST 1", "TST1", 18
        ).send({from: web3.eth.defaultAccount, gas: 1000000});
        // check pie balance
        balance = await erc20Facet.methods.balanceOf(web3.eth.defaultAccount).call();
        assert.equal(balance, parseEther("1"));

        await comp.approve(diamond.address, parseEther("100"));
        await basketFacet.methods.joinPool(parseEther("1")).send({from: web3.eth.defaultAccount, gas: 1000000});

        // check pie balance
        balance = await erc20Facet.methods.balanceOf(web3.eth.defaultAccount).call();
        assert.equal(balance, parseEther("2"));

        // Check diamond token asset balance
        amount = await comp.balanceOf(diamond.address)
        // the initial comp + joined
        expect(amount.eq(parseEther("2")));

        // Create a compound proposal
        proposal = await gov.propose([zeroAddress], [1], ["t"], ["0x1"], "test")
        proposalId = proposal.logs[0].args.id
        assert.equal(proposalId, 1)

        // Assert the pie has not voted yet
        let state = await gov.getReceipt(proposalId, diamond.address);
        assert.equal(state.hasVoted, false)
        assert.equal(state.support, false)
        assert.equal(state.votes, 0)

         // Assert the pie is unlocked
         lock = await basketFacet.methods.getLock().call();
         assert.equal(lock, false);

        //basketFacet.methods.setLock(true).send({from: web3.eth.defaultAccount, gas: 1000000})
        // Cast vote from the pie
        const latest = await web3.eth.getBlockNumber();

        diamondGov = new web3.eth.Contract(GovernorAlpha.abi, gov.address)
        await callFacet.methods.call(
          [diamond.address, gov.address],
          [basketFacet.methods.setLock(latest + 100).encodeABI(), diamondGov.methods.castVote(1, true).encodeABI()],
          [0, 0]
        ).send({from: web3.eth.defaultAccount, gas: 1000000})

        // Assert the pie has voted
        state = await gov.getReceipt(proposalId, diamond.address);
        assert.equal(state.hasVoted, true)
        assert.equal(state.support, true)
        assert.equal(state.votes, parseEther("2"))

        // Assert the pie is locked
        lock = await basketFacet.methods.getLock().call();
        assert.equal(lock, true);
    });
});