const Diamond = artifacts.require('Diamond')
const Test1Facet = artifacts.require('Test1Facet')
const Test2Facet = artifacts.require('Test2Facet')
const CallFacet = artifacts.require('CallFacet')
const BasketFacet = artifacts.require('BasketFacet')
const Comp = artifacts.require('Comp')
const Timelock = artifacts.require('Timelock')
const ERC20Facet = artifacts.require('ERC20Facet')
const GovernorAlpha = artifacts.require('GovernorAlpha')
const ERC20Factory = artifacts.require('ERC20Factory')

module.exports = function (deployer, network, accounts) {
  // deployment steps
  // The constructor inside Diamond deploys DiamondFacet
  //throw Error(accounts[0])
  deployer.then(async () => {
    await deployer.deploy(Diamond, accounts[0])
    await deployer.deploy(Test1Facet)
    await deployer.deploy(Test2Facet)
    await deployer.deploy(CallFacet)
    await deployer.deploy(ERC20Facet)
    await deployer.deploy(BasketFacet)
    await deployer.deploy(Comp, accounts[0])
    await deployer.deploy(Timelock, accounts[0], 0)
    await deployer.deploy(ERC20Factory)
    let comp = await Comp.deployed()
    let timelock = await Timelock.deployed()
    await deployer.deploy(GovernorAlpha, timelock.address, comp.address, accounts[0])

  })
}
