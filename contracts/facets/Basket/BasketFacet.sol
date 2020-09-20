// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import "../../openzeppelin/math/SafeMath.sol";
import "../ERC20/LibERC20Storage.sol";
import "../ERC20/LibERC20.sol";
import "./LibBasketStorage.sol";
import "../../libraries/LibDiamondStorage.sol";

contract BasketFacet {
    using SafeMath for uint256;

    // Before calling the first joinPool, the pools needs to be initialized with token balances
    function initialize(address[] memory _tokens) external {
        LibDiamondStorage.DiamondStorage storage ds = LibDiamondStorage.diamondStorage();
        LibBasketStorage.BasketStorage storage bs = LibBasketStorage.basketStorage();
        LibERC20Storage.ERC20Storage storage es = LibERC20Storage.erc20Storage();

        require(msg.sender == ds.contractOwner, "Must own the contract.");
        require(es.totalSupply >= 1 gwei, "POOL_TOKEN_BALANCE_TOO_LOW");

        for (uint256 i = 0; i < _tokens.length; i ++) {
            bs.tokens.push(IERC20(_tokens[i]));
            bs.inPool[_tokens[i]] = true;
            // requires some initial supply, could be less than 1 gwei, but yea.
            require(balance(_tokens[i]) >= 1 gwei, "TOKEN_BALANCE_TOO_LOW");
        }

        // unlock the contract
        this.setLock(block.number-1);
    }

    function joinPool(uint256 _amount) external {
        require(!this.getLock(), "POOL_LOCKED");
        LibBasketStorage.BasketStorage storage bs = LibBasketStorage.basketStorage();
        uint256 totalSupply = LibERC20Storage.erc20Storage().totalSupply;

        for(uint256 i; i < bs.tokens.length; i ++) {
            IERC20 token = bs.tokens[i];
            uint256 tokenAmount = balance(address(token)).mul(_amount).div(totalSupply);
            require(token.transferFrom(msg.sender, address(this), tokenAmount), "Transfer Failed");
        }

        LibERC20.mint(msg.sender, _amount);
    }


    // Must be overwritten to withdraw from strategies
    function exitPool(uint256 _amount) external virtual {
        require(!this.getLock(), "POOL_LOCKED");
        LibBasketStorage.BasketStorage storage bs = LibBasketStorage.basketStorage();
        uint256 totalSupply = LibERC20Storage.erc20Storage().totalSupply;

        for(uint256 i; i < bs.tokens.length; i ++) {
            IERC20 token = bs.tokens[i];
            uint256 tokenAmount = balance(address(token)).mul(_amount).div(totalSupply);
            require(token.transfer(msg.sender, tokenAmount), "Transfer Failed");
        }

        LibERC20.burn(msg.sender, _amount);
    }

    // returns true when locked
    function getLock() external view returns(bool){
        LibBasketStorage.BasketStorage storage bs = LibBasketStorage.basketStorage();
        return bs.lockBlock == 0 || bs.lockBlock >= block.number;
    }

    // lock up to and including _lock blocknumber
    function setLock(uint256 _lock) external {
        // Maybe remove the first check
        require(
            msg.sender == LibDiamondStorage.diamondStorage().contractOwner ||
            msg.sender == address(this)
        );
        LibBasketStorage.basketStorage().lockBlock = _lock;
    }

    // Seperated balance function to allow yearn like strategies to be hooked up by inheriting from this contract and overriding
    function balance(address _token) public view returns(uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function getTokens() external view returns (IERC20[] memory) {
        return(LibBasketStorage.basketStorage().tokens);
    }

}