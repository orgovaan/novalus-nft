//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//install: forge install OpenZeppelin/openzeppelin-contracts --no-commit
//import NftType custom var type to circumwent: It looks like the NftType enum is defined
//separately in both the NovalusNftController and NovalusNft contracts.
//Since enums are distinct types, even if they have the same name, they are not compatible with each other.
import {NovalusNft, NftType} from "./NovalusNft.sol";

/////////////////////////////////////
//// Custom Errors //////////////////
/////////////////////////////////////

error NovalusNftController__NotEnoughBalance();
error NovalusNftController__NotCrowdSalesContract();
error NovalusNftController__NotEnoughNftInStock();
error NovalusNftController__NotOwner();

/////////////////////////////////////
//// Contracts //////////////////////
/////////////////////////////////////

contract NovalusNftController {
    /////////////////////////////////////
    //// Type declarations //////////////
    /////////////////////////////////////

    /////////////////////////////////////
    //// State variables ////////////////
    /////////////////////////////////////

    uint256 private constant INITIAL_SUPPLY = 5;

    address private immutable i_owner;
    address private immutable i_crowdSalesContract;

    NovalusNft private novalusNftContract;

    bool private s_earlyBird;

    string s_baseUri = "baseUri";

    mapping(address => uint256) private s_addressToExtraNftBalance;
    mapping(NftType => uint256) private s_nftTypeToPrice;
    mapping(NftType => uint256) s_nftTypeToExtraNftBalanceReward; //could be immutable but not supported?
    mapping(NftType => uint256)
        private s_nftTypeToExtraNftBalanceReward_earlyBird; //could be immutable but not supported?

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
            revert NovalusNftController__NotOwner();
        }
        _;
    }

    modifier onlyCrowdSalesContract() {
        //revert if msg.sender is not the owner of the NovalusNftController contract
        if (msg.sender != i_crowdSalesContract) {
            revert NovalusNftController__NotCrowdSalesContract();
        }
        _;
    }

    /////////////////////////////////////
    //// Constructor ////////////////////
    /////////////////////////////////////

    constructor(address _crowdSalesContract, string memory _baseUri) {
        i_owner = msg.sender;
        i_crowdSalesContract = _crowdSalesContract;

        //chnange to appropriate values
        s_nftTypeToPrice[NftType.standard] = 1;
        s_nftTypeToPrice[NftType.broker] = 10;
        s_nftTypeToPrice[NftType.professional] = 100;
        s_nftTypeToPrice[NftType.infinity] = 1000;

        //chnange to appropriate values
        s_nftTypeToExtraNftBalanceReward[NftType.standard] = 2;
        s_nftTypeToExtraNftBalanceReward[NftType.broker] = 20;
        s_nftTypeToExtraNftBalanceReward[NftType.professional] = 200;
        s_nftTypeToExtraNftBalanceReward[NftType.infinity] = 2000;

        //chnange to appropriate values
        s_nftTypeToExtraNftBalanceReward_earlyBird[NftType.standard] = 3;
        s_nftTypeToExtraNftBalanceReward_earlyBird[NftType.broker] = 30;
        s_nftTypeToExtraNftBalanceReward_earlyBird[NftType.professional] = 300;
        s_nftTypeToExtraNftBalanceReward_earlyBird[NftType.infinity] = 3000;

        novalusNftContract = new NovalusNft(
            INITIAL_SUPPLY,
            _baseUri,
            address(this)
        );
    }

    /////////////////////////////////////
    //// Functions //////////////////////
    /////////////////////////////////////

    function reDeployNovalusNftContract(
        string memory _baseUri
    ) external onlyOwner returns (NovalusNft) {
        novalusNftContract = new NovalusNft(
            INITIAL_SUPPLY,
            _baseUri,
            address(this)
        );
        return novalusNftContract;
    }

    function setNftTypePrice(
        NftType _nftType,
        uint256 _newPrice
    ) external onlyOwner {
        s_nftTypeToPrice[_nftType] = _newPrice;
    }

    function buyNft(NftType _nftType, uint256 _amount) external {
        //revert if user balance is less than the total price of NFTs in cart
        if (
            s_addressToExtraNftBalance[msg.sender] <
            s_nftTypeToPrice[_nftType] * _amount
        ) {
            revert NovalusNftController__NotEnoughBalance();
        }

        //decrement the user balance after purchase
        s_addressToExtraNftBalance[msg.sender] -=
            s_nftTypeToPrice[_nftType] *
            _amount;

        //revert if the amount to mint would be more than the stock
        if (_amount > novalusNftContract.getStock()) {
            revert NovalusNftController__NotEnoughNftInStock();
        }

        //mint the desired amount
        for (uint i = 0; i < _amount; i++) {
            novalusNftContract.mintNft(msg.sender, _nftType);
        }
    }

    //the CrowdSalesContract can call this
    function airdropNftOnPackagePurchase(
        address _buyer,
        NftType _nftType
    ) external onlyCrowdSalesContract {
        novalusNftContract.mintNft(_buyer, _nftType);
    }

    //arguments should come from an input file we read in with a deploy script.
    //Should be called from the constructor?
    function airdropNftToExistingCustomers(
        address[] calldata _customerAddresses,
        NftType[] calldata _nftTypes
    ) external onlyCrowdSalesContract {
        assert(_customerAddresses.length == _nftTypes.length);

        //revert if the number of nfts to drop is more than the stock
        if (_customerAddresses.length > novalusNftContract.getStock()) {
            revert NovalusNftController__NotEnoughNftInStock();
        }

        for (uint256 i = 0; i < _customerAddresses.length; i++) {
            novalusNftContract.mintNft(_customerAddresses[i], _nftTypes[i]);
        }
    }

    function airdropExtraNftBalanceOnPackagePurchase(
        address _buyer,
        NftType _nftType,
        bool _earlyBird
    ) public onlyCrowdSalesContract {
        if (_earlyBird) {
            s_addressToExtraNftBalance[
                _buyer
            ] += s_nftTypeToExtraNftBalanceReward_earlyBird[_nftType];
        } else {
            s_addressToExtraNftBalance[
                _buyer
            ] += s_nftTypeToExtraNftBalanceReward[_nftType];
        }
    }

    //arguments should come from an input file we read in with a deploy script.
    //assumes that the input file contains data for the address of the customer, the type of package the user bought, and the date of purchase
    function airdropExtraNftBalanceToExistingCustomers(
        //to be added: validation for array lengths
        uint256 _numberOfCustomers,
        address[] calldata _customer,
        NftType[] calldata _nftType,
        uint256 _date
    ) external onlyCrowdSalesContract {
        for (uint256 i = 0; i < _numberOfCustomers; i++) {
            if (_date < 1679865600) {
                //Unix timestamp for April 1, 2023, 00:00:00 UTC, is approximately 1679865600
                s_earlyBird = true;
            } else {
                s_earlyBird = false;
            }

            airdropExtraNftBalanceOnPackagePurchase(
                _customer[i],
                _nftType[i],
                s_earlyBird
            );

            //every future customer is by default non-early bird
            s_earlyBird = false;
        }
    }

    function callAddToStockAndSetNextBaseUri(
        uint256 _additionalQty,
        string memory _nextBaseUri
    ) external onlyOwner {
        novalusNftContract.addToStockAndSetNextBaseUri(
            _additionalQty,
            _nextBaseUri
        );
    }

    function callSetController(address _newController) external onlyOwner {
        novalusNftContract.setController(_newController);
    }

    /////////////////////////////////////
    //// Getter Functions ///////////////
    /////////////////////////////////////

    function getUsersExtraNftBalance(
        address _user
    ) external view returns (uint256) {
        return s_addressToExtraNftBalance[_user];
    }

    function getNftTypePrice(NftType _nftType) external view returns (uint256) {
        return s_nftTypeToPrice[_nftType];
    }
}
