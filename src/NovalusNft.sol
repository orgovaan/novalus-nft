//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//install: forge install OpenZeppelin/openzeppelin-contracts --no-commit
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/////////////////////////////////////
//// Importable type defs ///////////
/////////////////////////////////////

enum NftType {
    standard,
    broker,
    professional,
    infinity
}

/////////////////////////////////////
//// Custom Errors //////////////////
/////////////////////////////////////

error NovalusNft__NotEnoughNftInStock();
error NovalusNft__NotNftController();

/////////////////////////////////////
//// Contracts //////////////////////
/////////////////////////////////////

contract NovalusNft is ERC721 {
    using Strings for uint256; //to be able to use method .ToString when overriding the function tokenURI()

    /////////////////////////////////////
    //// State variables ////////////////
    /////////////////////////////////////

    address private s_controller;

    uint256 private s_tokenCounter;
    uint256 private s_stock;
    uint256 private s_previousStock;
    uint256 private s_batchNumber;
    string private s_baseUri;
    string private s_nextBaseUri;

    mapping(uint256 => string) private s_tokenIdToUri;
    mapping(uint256 => NftType) private s_tokenIdToNftType;
    mapping(uint256 => uint256) private s_tokenIdToMintBlockTime;
    mapping(uint256 => string) private s_tokenIdToBaseUri;

    /////////////////////////////////////
    //// Events /////////////////////////
    /////////////////////////////////////

    event minted(address _minter, uint256 _tokenId, uint256 timestamp);

    /////////////////////////////////////
    //// Modifiers //////////////////////
    /////////////////////////////////////

    modifier onlyController() {
        //revert if msg.sender is not the owner of the NovalusNftController contract
        if (msg.sender != s_controller) {
            revert NovalusNft__NotNftController();
        }
        _;
    }

    /////////////////////////////////////
    //// Constructor ////////////////////
    /////////////////////////////////////

    constructor(
        uint256 _initialSupply,
        string memory _baseUri,
        address _controller
    ) ERC721("NovalusNft", "NOVALUS") {
        s_stock = _initialSupply;
        s_baseUri = _baseUri;
        s_previousStock = s_stock;
        s_tokenCounter = 0;
        s_controller = _controller;
        s_batchNumber = 0;
    }

    /////////////////////////////////////
    //// Functions //////////////////////
    /////////////////////////////////////

    //tokens are minted with incrementing tokenIds, regardless of NFT type
    function mintNft(address _to, NftType _nftType) external onlyController {
        //revert if stock is sold out
        if (s_stock <= 0) {
            revert NovalusNft__NotEnoughNftInStock();
        }

        _safeMint(_to, s_tokenCounter);

        if (s_tokenCounter >= s_previousStock) {
            s_baseUri = s_nextBaseUri;
        }

        s_tokenIdToUri[s_tokenCounter] = tokenURI(s_tokenCounter); //tokenuri of the minted token (defined in ERC721.sol)
        s_tokenIdToNftType[s_tokenCounter] = _nftType; //the NFT type of the minted token
        s_tokenIdToMintBlockTime[s_tokenCounter] = block.timestamp; //the NFT type of the minted token
        s_tokenIdToBaseUri[s_tokenCounter] = s_baseUri;

        emit minted(msg.sender, s_tokenCounter, block.timestamp);

        s_tokenCounter++;
        s_stock--;
    }

    function addToStockAndSetNextBaseUri(
        uint256 _additionalQty,
        string memory _nextBaseUri
    ) external onlyController {
        s_previousStock = s_stock + s_tokenCounter;
        s_stock += _additionalQty;
        s_nextBaseUri = _nextBaseUri;
    }

    function setController(address _newController) external onlyController {
        s_controller = _newController;
    }

    function _baseURI() internal view override returns (string memory) {
        return s_baseUri; //overriden line
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = s_tokenIdToBaseUri[tokenId]; // overriden line
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : "";
    }

    /////////////////////////////////////
    //// Getters ////////////////////////
    /////////////////////////////////////

    function getNftType(uint256 _tokenId) external view returns (NftType) {
        return s_tokenIdToNftType[_tokenId];
    }

    function getMintDate(uint256 _tokenId) external view returns (uint256) {
        return s_tokenIdToMintBlockTime[_tokenId];
    }

    function getTokenBaseUri(
        uint256 _tokenId
    ) external view returns (string memory) {
        return s_tokenIdToBaseUri[_tokenId];
    }

    function getStock() external view returns (uint256) {
        return s_stock;
    }

    function getMintedQty() external view returns (uint256) {
        return s_tokenCounter;
    }

    function getCurrentBaseUri() external view returns (string memory) {
        return s_baseUri;
    }

    //not neccesary
    function getNextBaseUri() external view returns (string memory) {
        return s_nextBaseUri;
    }

    //not neccesary
    function getPreviousStock() external view returns (uint256) {
        return s_previousStock;
    }
}
