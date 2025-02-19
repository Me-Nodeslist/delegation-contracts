// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "./interfaces/ILicenseNFT.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract LicenseNFT is
    ILicenseNft,
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    string public constant version = "0.1.0";

    uint256 constant MAX_SUPPLY = 10000000;

    string private baseURI;
    uint256 public tokenIndex;
    uint256 public transferProhibitedUntil;
    uint256 public redeemProhibitedUntil;
    address public redeemAddress;

    mapping(uint256 => MetaData) public tokenMetas;
    mapping(uint256 => bool) public transferred;
    mapping(address => bool) public canTransferOnce;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        string memory name,
        string memory symbol,
        uint256 _transferProhibitedUntil,
        uint256 _redeemProhibitedUntil,
        address _redeemAddress
    ) public initializer {
        __ERC721_init(name, symbol);
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        transferProhibitedUntil = _transferProhibitedUntil;
        redeemProhibitedUntil = _redeemProhibitedUntil;
        redeemAddress = _redeemAddress;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return
            interfaceId == type(ILicenseNft).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        if (to == redeemAddress) {
            require(
                block.timestamp > redeemProhibitedUntil,
                "Redeem not allowed"
            );
            super.transferFrom(from, to, tokenId);
            return;
        }

        if (block.timestamp < transferProhibitedUntil) {
            require(canTransferOnce[from], "Transfer not allowed");
            require(!transferred[tokenId], "Already Transferred");
            transferred[tokenId] = true;
        }

        super.transferFrom(from, to, tokenId);
    }

    function mint(
        address receiver,
        uint256 count,
        MetaData calldata meta
    ) public onlyOwner {
        require(tokenIndex + count <= MAX_SUPPLY, "Mint finished");
        for (uint i = 1; i <= count; i++) {
            _safeMint(receiver, tokenIndex + i);
            tokenMetas[tokenIndex + i] = meta;
        }
        tokenIndex += count;
    }

    function mintBatch(
        address[] calldata receivers,
        uint256[] calldata counts,
        MetaData[] calldata metas
    ) external onlyOwner {
        require(
            receivers.length == counts.length && counts.length == metas.length,
            "Length of arr not equal"
        );
        for (uint i = 0; i < receivers.length; i++) {
            mint(receivers[i], counts[i], metas[i]);
        }
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    function setTransferProhibitedUntil(
        uint256 newTransferProhibitedUntil
    ) external onlyOwner {
        transferProhibitedUntil = newTransferProhibitedUntil;
    }

    function setRedeemProhibitedUntil(
        uint256 newRedeemProhibitedUntil
    ) external onlyOwner {
        redeemProhibitedUntil = newRedeemProhibitedUntil;
    }

    function setRedeemAddress(address newRedeemAddress) external onlyOwner {
        redeemAddress = newRedeemAddress;
    }

    function setTransferOnceWhitelist(
        address[] calldata whitelist
    ) external onlyOwner {
        require(whitelist.length > 0, "Empty whitelist");
        for (uint i = 0; i < whitelist.length; i++) {
            canTransferOnce[whitelist[i]] = true;
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}
