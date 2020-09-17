// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import "../../openzeppelin/math/SafeMath.sol";
import "../ERC20/LibERC20Storage.sol";
import "../ERC20/LibERC20.sol";
import "./LibBasketStorage.sol";
import "../../libraries/LibDiamondStorage.sol";

contract BasketFacet {
    using SafeMath for uint256;

    constructor() public {
        // Lock the pool on creating the contract
        LibBasketStorage.basketStorage().lock = true;
    }

    // Before calling the first joinPool, the pools needs to be initialized with token balances
    function initialize(address[] memory _tokens) external {
        LibDiamondStorage.DiamondStorage storage ds = LibDiamondStorage.diamondStorage();
        LibBasketStorage.BasketStorage storage bs = LibBasketStorage.basketStorage();

        require(msg.sender == ds.contractOwner, "Must own the contract.");

        for (uint256 i = 0; i < _tokens.length; i ++) {
            bs.tokens.push(IERC20(_tokens[i]));
            bs.inPool[_tokens[i]] = true;
            // requires some initial supply, could be less than 1 gwei, but yea.
            require(balance(_tokens[i]) >= 1 gwei, "TOKEN_BALANCE_TOO_LOW");
        }

        this.setLock(false);
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

    }

    function getLock() external view returns(bool){
        return LibBasketStorage.basketStorage().lock;
    }

    function setLock(bool _lock) external {
        // Maybe remove the first check
        require(
            msg.sender == LibDiamondStorage.diamondStorage().contractOwner ||
            msg.sender == address(this)
        );
        LibBasketStorage.basketStorage().lock = _lock;
    }

    // Seperated balance function to allow yearn like strategies to be hooked up by inheriting from this contract and overriding
    function balance(address _token) public view returns(uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function getTokens() external view returns (IERC20[] memory) {
        return(LibBasketStorage.basketStorage().tokens);
    }

}