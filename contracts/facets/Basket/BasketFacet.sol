// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import "../../openzeppelin/math/SafeMath.sol";
import "../ERC20/LibERC20Storage.sol";
import "../ERC20/LibERC20.sol";
import "./LibBasketStorage.sol";

contract BasketFacet {
    using  SafeMath for uint256;
    function initialize(address[] memory _tokens) external {
        LibBasketStorage.BasketStorage storage bs = LibBasketStorage.basketStorage();

        for (uint256 i = 0; i < _tokens.length; i ++) {
            bs.tokens.push(IERC20(_tokens[i]));
            bs.inPool[_tokens[i]] = true;
        }
    }

    function joinPool(uint256 _amount) external {
        LibBasketStorage.BasketStorage storage bs = LibBasketStorage.basketStorage();
        uint256 totalSupply = LibERC20Storage.erc20Storage().totalSupply;

        for(uint256 i; i < bs.tokens.length; i ++) {
            IERC20 token = bs.tokens[i];
            // this line below does not work in initial state.
            //uint256 tokenAmount = balance(address(token)).mul(_amount).div(totalSupply);
            uint256 tokenAmount = _amount;
            require(token.transferFrom(msg.sender, address(this), tokenAmount), "Transfer Failed");
        }

        LibERC20.mint(msg.sender, _amount);
    }


    // Must be overwritten to withdraw from strategies
    function exitPool(uint256 _amount) external virtual {
        LibBasketStorage.BasketStorage storage bs = LibBasketStorage.basketStorage();
        uint256 totalSupply = LibERC20Storage.erc20Storage().totalSupply;

        for(uint256 i; i < bs.tokens.length; i ++) {
            IERC20 token = bs.tokens[i];
            uint256 tokenAmount = balance(address(token)).mul(_amount).div(totalSupply);
            require(token.transfer(msg.sender, tokenAmount), "Transfer Failed");
        }

    }

    // Seperated balance function to allow yearn like strategies to be hooked up by inheriting from this contract and overriding
    function balance(address _token) public view returns(uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function getTokens() external view returns (IERC20[] memory) {
        return(LibBasketStorage.basketStorage().tokens);
    }

}