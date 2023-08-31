/*a kulonbozo nft-khez NEM fog tartozni kulon kep
Esetleg az svg-t megpróbálhatjuk rárakni on-chain, meg a json-t is online generálni


Valasszuk szet az NFT-s részt az extraNftBalance-ostol
Azért is, mert ha később más logika szerint akarják a mintet, akkor nem tudjuk megváltoztatni.

Nft:
- mint (a controller hívja a guard alapján
- felírjuk 
--a type (még ezt is el lehet dobni, maradhat csak az értéke)
--érték, 
--kibocsátás ideje
--token uri

- upload next bacth
- esetleg batch transfer
- nem kell pausable
- nem kell enum?


Controller:
- ez az, ahol az nft 
- ebben van minden, amit később le akarunk cserélni
- ez verérli a mintet
- ez hívja a 
- corwdsale contract hozzá tudja adni az extranft balancot
-crowdsale contract vagy a user hívja hívja, az utóbbi a hh terhére
-- lesz egy mint, ami nem kér pénzt, lesz, ami igen
- semmit nem tárol a csomagokról. nem azt mondja a crowdsale, hogy eladtam ilyen típusú csomagot, hanem megadjuk neki, hogy 
- batchmint
- batchaddBalance



scaffolding-ba lehet feltolni a dolgokat, az nft-t meg az nft controllert.
*/

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//install: forge install OpenZeppelin/openzeppelin-contracts --no-commit
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
//Optional, provides an additional layer of control and security
//if removed, remove functions _beforeTokenTransfer() and pause()
import {ERC721Pausable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";

/////////////////////////////////////
//// Custom Errors //////////////////
/////////////////////////////////////

error NovalusNft__NotEnoughBalance();
error NovalusNft__NotContractOwner();
error NovalusNft__NotCrowdSalesContract();
error NovalusNft__PackageTypeHasNoAssociatedNftType();
error NovalusNft__PackageTypeDoesNotExist();
error NovalusNft__NotEnoughNftInStock();

/////////////////////////////////////
//// Contracts //////////////////////
/////////////////////////////////////

contract NovalusNft is ERC721, ERC721Pausable {
    /////////////////////////////////////
    //// Type declarations //////////////
    /////////////////////////////////////

    enum PackageType {
        standard,
        broker,
        professional,
        infinity,
        validator,
        validatorPro
    }

    PackageType private packageType;

    struct PackageTypeInfo {
        ////string nftTypeMetadataURI;
        uint256 nftTypePrice;
        uint256 nftTypeInitialSupply;
        uint256 nftTypeTotalSupply;
        uint256 extraNftBalanceEarlyBird;
        uint256 extraNftBalance;
        uint256 numberOfMintedFromThisNftType;
        string currentNftBaseUri;
    }

    /////////////////////////////////////
    //// State variables ////////////////
    /////////////////////////////////////

    uint256 private s_tokenCounter;

    address private immutable i_owner;
    string[] private s_baseUri; //baseURI will be different for the different batches
    uint8 private s_batchCounter;
    string private s_currentBaseUri;

    //initial NFT supplies
    uint256 private constant INSUPPLY_STANDARD = 100;
    uint256 private constant INSUPPLY_BROKER = 100;
    uint256 private constant INSUPPLY_PROFESSIONAL = 100;
    uint256 private constant INSUPPLY_INFINITY = 100;

    address private constant CROWDSALESCONTRACT = address(0); //change to the real stuff. Or will it change, do we need a function for this with an onlyOwner modifier?

    mapping(uint256 => string) private s_tokenIdToUri;
    mapping(uint256 => PackageType) private s_tokenIdtoPackageType; //basically used also like s_tokenIdtoNftType
    mapping(address => uint256) private s_addressToExtraNftBalance;
    mapping(PackageType => PackageTypeInfo) public s_packageTypeToInfo;

    /////////////////////////////////////
    //// Events /////////////////////////
    /////////////////////////////////////

    event minted(address _minter, uint256 _tokenId, uint256 timestamp);

    /////////////////////////////////////
    //// Modifiers //////////////////////
    /////////////////////////////////////

    modifier onlyOwner() {
        //revert if msg.sender is not the owner of the NovalusNft contract
        if (msg.sender != i_owner) {
            revert NovalusNft__NotContractOwner();
        }
        _;
    }

    modifier onlyCrowdSalesContract() {
        //revert if msg.sender is not the CrwodSalesContract
        if (msg.sender != CROWDSALESCONTRACT) {
            revert NovalusNft__NotCrowdSalesContract();
        }
        _;
    }

    modifier onlyPackagesWithNfts(PackageType _packageType) {
        //revert if submitted package type is one of the types that do not have an nft type associated with it
        if (
            _packageType != PackageType.standard &&
            _packageType != PackageType.broker &&
            _packageType != PackageType.professional &&
            _packageType != PackageType.infinity
        ) {
            revert NovalusNft__PackageTypeHasNoAssociatedNftType();
        }
        _;
    }

    modifier onlyExistingPackages(PackageType _packageType) {
        //revert if submitted type is not on exsiting package type
        if (
            _packageType != PackageType.standard &&
            _packageType != PackageType.broker &&
            _packageType != PackageType.professional &&
            _packageType != PackageType.infinity &&
            _packageType != PackageType.validator &&
            _packageType != PackageType.validatorPro
        ) {
            revert NovalusNft__PackageTypeDoesNotExist();
        }
        _;
    }

    /////////////////////////////////////
    //// Constructor ////////////////////
    /////////////////////////////////////

    constructor(string memory _baseUri) ERC721("NovalusNft", "NOVALUS") {
        i_owner = msg.sender;
        s_tokenCounter = 0;
        s_batchCounter = 0;
        s_baseUri[s_batchCounter] = _baseUri;

        //Initialize the NftTypeInfo structs.
        //SET APPROPRIATE VALUES
        s_packageTypeToInfo[PackageType.standard] = PackageTypeInfo({
            nftTypePrice: 250,
            nftTypeInitialSupply: INSUPPLY_STANDARD,
            nftTypeTotalSupply: INSUPPLY_STANDARD,
            extraNftBalanceEarlyBird: 0,
            extraNftBalance: 0,
            numberOfMintedFromThisNftType: 0,
            currentNftBaseUri: s_baseUri[s_batchCounter]
        });

        s_packageTypeToInfo[PackageType.broker] = PackageTypeInfo({
            nftTypePrice: 750,
            nftTypeInitialSupply: INSUPPLY_BROKER,
            nftTypeTotalSupply: INSUPPLY_BROKER,
            extraNftBalanceEarlyBird: 0,
            extraNftBalance: 0,
            numberOfMintedFromThisNftType: 0,
            currentNftBaseUri: s_baseUri[s_batchCounter]
        });

        s_packageTypeToInfo[PackageType.professional] = PackageTypeInfo({
            nftTypePrice: 1490,
            nftTypeInitialSupply: INSUPPLY_PROFESSIONAL,
            nftTypeTotalSupply: INSUPPLY_PROFESSIONAL,
            extraNftBalanceEarlyBird: 500,
            extraNftBalance: 250,
            numberOfMintedFromThisNftType: 0,
            currentNftBaseUri: s_baseUri[s_batchCounter]
        });

        s_packageTypeToInfo[PackageType.infinity] = PackageTypeInfo({
            nftTypePrice: 4990,
            nftTypeInitialSupply: INSUPPLY_INFINITY,
            nftTypeTotalSupply: INSUPPLY_INFINITY,
            extraNftBalanceEarlyBird: 1500,
            extraNftBalance: 1000,
            numberOfMintedFromThisNftType: 0,
            currentNftBaseUri: s_baseUri[s_batchCounter]
        });

        s_packageTypeToInfo[PackageType.validator] = PackageTypeInfo({
            nftTypePrice: 0,
            nftTypeInitialSupply: 0,
            nftTypeTotalSupply: 0,
            extraNftBalanceEarlyBird: 3000,
            extraNftBalance: 2000,
            numberOfMintedFromThisNftType: 0,
            currentNftBaseUri: ""
        });

        s_packageTypeToInfo[PackageType.validatorPro] = PackageTypeInfo({
            nftTypePrice: 0,
            nftTypeInitialSupply: 0,
            nftTypeTotalSupply: 0,
            extraNftBalanceEarlyBird: 3000,
            extraNftBalance: 2000,
            numberOfMintedFromThisNftType: 0,
            currentNftBaseUri: ""
        });
    }

    /////////////////////////////////////
    //// Functions //////////////////////
    /////////////////////////////////////

    function setNftTypePrice(
        PackageType _packageType,
        uint256 _newPrice
    ) external onlyPackagesWithNfts(_packageType) onlyOwner {
        s_packageTypeToInfo[_packageType].nftTypePrice = _newPrice;
    }

    function setNftTypeSuppliesAndNewBaseUriWhenNewBatchIsReleased(
        uint256 _supplyAddOnStandard,
        uint256 _supplyAddOnBroker,
        uint256 _supplyAddOnProfessional,
        uint256 _supplyAddOnInfinity,
        string memory _newBaseUri
    ) external onlyOwner {
        s_packageTypeToInfo[PackageType.standard]
            .nftTypeTotalSupply += _supplyAddOnStandard;
        s_packageTypeToInfo[PackageType.broker]
            .nftTypeTotalSupply += _supplyAddOnBroker;
        s_packageTypeToInfo[PackageType.professional]
            .nftTypeTotalSupply += _supplyAddOnProfessional;
        s_packageTypeToInfo[PackageType.infinity]
            .nftTypeTotalSupply += _supplyAddOnInfinity;

        s_batchCounter++; //increment the batch nuumber
        s_baseUri[s_batchCounter] = _newBaseUri; //currently works until batch no 1 (2nd batch)
    }

    //currently works until batch no 1 (2nd batch)
    //can be made more generic by e.g. saving the previous total supply in a var,...
    function _setCurrentBaseUri(
        PackageType _packageType
    ) internal onlyPackagesWithNfts(_packageType) {
        if (
            s_packageTypeToInfo[_packageType].numberOfMintedFromThisNftType >
            s_packageTypeToInfo[_packageType].nftTypeInitialSupply
        ) {
            s_packageTypeToInfo[_packageType].currentNftBaseUri = s_baseUri[1];
        }
    }

    //tokens are minted with incrementing tokenIds, regardless of NFT type
    //(Or should we have a pre-defined block of numbers for each NftType?)
    function _mintNft(address _to, PackageType _packageType) internal {
        //revert if this type is already sold out - unless we add more to IPFS-not and update the supply data with setNftTypeSupply()
        if (
            s_packageTypeToInfo[_packageType].numberOfMintedFromThisNftType >=
            s_packageTypeToInfo[_packageType].nftTypeTotalSupply
        ) {
            revert NovalusNft__NotEnoughNftInStock();
        }

        _safeMint(_to, s_tokenCounter);

        s_tokenIdtoPackageType[s_tokenCounter] = _packageType; //the NFT type of the minted token

        _setCurrentBaseUri(_packageType);

        s_currentBaseUri = s_packageTypeToInfo[_packageType].currentNftBaseUri; //s_currentBaseUri is what the baseURI() function will return
        s_tokenIdToUri[s_tokenCounter] = tokenURI(s_tokenCounter); //tokenuri of the minted token

        emit minted(msg.sender, s_tokenCounter, block.timestamp);

        s_packageTypeToInfo[_packageType].numberOfMintedFromThisNftType++;
        s_tokenCounter++;
    }

    function buyNft(
        PackageType _packageType,
        uint256 _mintAmount
    ) external onlyPackagesWithNfts(_packageType) {
        //revert if user balance is less than the total price of NFTs in cart
        if (
            s_addressToExtraNftBalance[msg.sender] <
            s_packageTypeToInfo[_packageType].nftTypePrice * _mintAmount
        ) {
            revert NovalusNft__NotEnoughBalance();
        }
        //revert if the amount to mint PLUS the already minted qty would be more than the supply
        if (
            s_packageTypeToInfo[_packageType].numberOfMintedFromThisNftType +
                _mintAmount >
            s_packageTypeToInfo[_packageType].nftTypeTotalSupply
        ) {
            revert NovalusNft__NotEnoughNftInStock();
        }

        for (uint i = 0; i < _mintAmount; i++) {
            //mint the desired amount
            _mintNft(msg.sender, _packageType);
        }

        s_addressToExtraNftBalance[msg.sender] -= //decrement the user balance after purchase
            s_packageTypeToInfo[_packageType].nftTypePrice *
            _mintAmount;
    }

    //the CrowdSalesContract can call this. (Or we need a listener for the CrowdSalesContract sales event)
    function airdropNftOnPackagePurchase(
        address _buyer,
        PackageType _boughtPackage
    ) external onlyPackagesWithNfts(_boughtPackage) onlyCrowdSalesContract {
        _mintNft(_buyer, _boughtPackage);
    }

    //need to read an input file with a deploy script. Should be called from the constructor?
    function airdropNftToExistingCustomers(
        uint256 _numberOfCustomers,
        address[] calldata _customer,
        PackageType[] calldata _boughtPackage
    ) external onlyCrowdSalesContract {
        for (uint256 i = 0; i < _numberOfCustomers; i++) {
            require(
                _boughtPackage[i] == PackageType.standard ||
                    _boughtPackage[i] == PackageType.broker ||
                    _boughtPackage[i] == PackageType.professional ||
                    _boughtPackage[i] == PackageType.infinity,
                "This package does not come with an NFT."
            );
            _mintNft(_customer[i], _boughtPackage[i]);
        }
    }

    //the CrowdSalesContract can call this. (Or we need a listener for the CrowdSalesContract sales event)
    function airdropExtraNftBalanceOnPackagePurchase(
        address _buyer,
        PackageType _boughtPackage,
        bool _earlyBird
    ) public onlyExistingPackages(_boughtPackage) onlyCrowdSalesContract {
        if (_earlyBird) {
            s_addressToExtraNftBalance[_buyer] += s_packageTypeToInfo[
                _boughtPackage
            ].extraNftBalanceEarlyBird;
        } else {
            s_addressToExtraNftBalance[_buyer] += s_packageTypeToInfo[
                _boughtPackage
            ].extraNftBalance;
        }
    }

    //need to read an input file in a deploy script. Should be called from the constructor?
    //assumes that the input file contains data for the address of the customer, the type of package the user bought, and the date of purchase
    function airdropExtraNftBalanceToExistingCustomers(
        //to be added: validation for array lengths
        uint256 _numberOfCustomers,
        address[] calldata _customer,
        PackageType[] calldata _boughtPackage,
        uint256 _date
    ) external onlyCrowdSalesContract {
        bool earlyBird;
        for (uint256 i = 0; i < _numberOfCustomers; i++) {
            require(
                _boughtPackage[i] == PackageType.standard ||
                    _boughtPackage[i] == PackageType.broker ||
                    _boughtPackage[i] == PackageType.professional ||
                    _boughtPackage[i] == PackageType.infinity ||
                    _boughtPackage[i] == PackageType.validator ||
                    _boughtPackage[i] == PackageType.validatorPro,
                "Package type does not exist."
            );

            if (_date < 1679865600) {
                //Unix timestamp for April 1, 2023, 00:00:00 UTC, is approximately 1679865600
                earlyBird = true;
            } else {
                earlyBird = false;
            }
            airdropExtraNftBalanceOnPackagePurchase(
                _customer[i],
                _boughtPackage[i],
                earlyBird
            );
        }
    }

    //this is incorrect: when s_currentBaseUri changes, the base Uri of already minted tokens changes too!
    function _baseURI() internal view virtual override returns (string memory) {
        return s_currentBaseUri;
    }

    //this function is defined in both the ERC721 and ERC721Pausable base contracts and, hence
    //we need an implementation here. This implementation is exactly the same as in ERC721Pausable.sol
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override(ERC721, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);

        require(!paused(), "ERC721Pausable: token transfer while paused");
    }

    //added for pausing functionality derived from ERC721Pausable.sol
    function pause(bool val) public onlyOwner {
        if (val == true) {
            _pause();
            return;
        }
        _unpause();
    }

    /////////////////////////////////////
    //// Getter Functions ///////////////
    /////////////////////////////////////

    function getNftTypeTotalSupply(
        PackageType _packageType
    ) external view returns (uint256) {
        return s_packageTypeToInfo[_packageType].nftTypeTotalSupply;
    }

    function getNftTypeStock(
        PackageType _packageType
    ) external view returns (uint256) {
        return
            s_packageTypeToInfo[_packageType].nftTypeTotalSupply -
            s_packageTypeToInfo[_packageType].numberOfMintedFromThisNftType;
    }

    function getUsersExtraNftBalance(
        address _user
    ) external view returns (uint256) {
        return s_addressToExtraNftBalance[_user];
    }

    function getNftTypePrice(
        PackageType _packageType
    ) external view returns (uint256) {
        return s_packageTypeToInfo[_packageType].nftTypePrice;
    }

    function getTokenUri(
        uint256 _tokenId
    ) external view returns (string memory) {
        return s_tokenIdToUri[_tokenId];
    }

    function getNftBatchBaseUri(
        uint8 _batchNumber
    ) external view returns (string memory) {
        return s_baseUri[_batchNumber];
    }
}
