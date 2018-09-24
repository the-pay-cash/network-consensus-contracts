pragma solidity ^0.4.24;

import "./interfaces/IRewardByBlock.sol";
import "./interfaces/IKeysManager.sol";
import "./interfaces/IProxyStorage.sol";
import "./eternal-storage/EternalStorage.sol";
import "./libs/SafeMath.sol";


contract RewardByBlock is EternalStorage, IRewardByBlock {
    using SafeMath for uint256;

    bytes32 internal constant EXTRA_RECEIVERS = keccak256("extraReceivers");
    bytes32 internal constant PROXY_STORAGE = keccak256("proxyStorage");
    bytes32 internal constant MINTED_TOTALLY = keccak256("mintedTotally");

    bytes32 internal constant EXTRA_RECEIVERS_AMOUNTS = "extraReceiversAmounts";
    bytes32 internal constant MINTED_FOR_ACCOUNT = "mintedForAccount";
    bytes32 internal constant MINTED_FOR_ACCOUNT_IN_BLOCK = "mintedForAccountInBlock";
    bytes32 internal constant MINTED_IN_BLOCK = "mintedInBlock";

    // solhint-disable const-name-snakecase
    // These values must be changed before deploy
    uint256 public constant blockRewardAmount = 1 ether; 
    uint256 public constant emissionFundsAmount = 1 ether;
    address public constant emissionFunds = 0x0000000000000000000000000000000000000000;
    address public constant bridgeContract = 0x0000000000000000000000000000000000000000;
    // solhint-enable const-name-snakecase

    event AddedReceiver(uint256 amount, address indexed receiver);
    event Rewarded(address[] receivers, uint256[] rewards);

    modifier onlyBridgeContract {
        require(msg.sender == bridgeContract);
        _;
    }

    modifier onlySystem {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    function addExtraReceiver(uint256 _amount, address _receiver)
        external
        onlyBridgeContract
    {
        require(_amount != 0);
        require(_receiver != address(0));
        uint256 oldAmount = extraReceiversAmounts(_receiver);
        if (oldAmount == 0) {
            _addExtraReceiver(_receiver);
        }
        _setExtraReceiverAmount(oldAmount.add(_amount), _receiver);
        emit AddedReceiver(_amount, _receiver);
    }

    function reward(address[] benefactors, uint16[] kind)
        external
        onlySystem
        returns (address[], uint256[])
    {
        require(benefactors.length == kind.length);
        require(benefactors.length == 1);
        require(kind[0] == 0);

        address miningKey = benefactors[0];

        require(_isMiningActive(miningKey));

        uint256 extraLength = extraReceiversLength();

        address[] memory receivers = new address[](extraLength.add(2));
        uint256[] memory rewards = new uint256[](receivers.length);

        receivers[0] = _getPayoutByMining(miningKey);
        rewards[0] = blockRewardAmount;
        receivers[1] = emissionFunds;
        rewards[1] = emissionFundsAmount;

        uint256 i;
        
        for (i = 0; i < extraLength; i++) {
            uint256 extraIndex = i.add(2);
            address extraAddress = extraReceivers(i);
            uint256 extraAmount = extraReceiversAmounts(extraAddress);
            _setExtraReceiverAmount(0, extraAddress);
            receivers[extraIndex] = extraAddress;
            rewards[extraIndex] = extraAmount;
        }

        for (i = 0; i < receivers.length; i++) {
            _setMinted(rewards[i], receivers[i]);
        }

        _clearExtraReceivers();

        emit Rewarded(receivers, rewards);
    
        return (receivers, rewards);
    }

    function extraReceivers(uint256 _index) public view returns(address) {
        return addressArrayStorage[EXTRA_RECEIVERS][_index];
    }

    function extraReceiversAmounts(address _receiver) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(EXTRA_RECEIVERS_AMOUNTS, _receiver))
        ];
    }

    function extraReceiversLength() public view returns(uint256) {
        return addressArrayStorage[EXTRA_RECEIVERS].length;
    }

    function mintedForAccount(address _account)
        public
        view
        returns(uint256)
    {
        return uintStorage[
            keccak256(abi.encode(MINTED_FOR_ACCOUNT, _account))
        ];
    }

    function mintedForAccountInBlock(address _account, uint256 _blockNumber)
        public
        view
        returns(uint256)
    {
        return uintStorage[
            keccak256(abi.encode(MINTED_FOR_ACCOUNT_IN_BLOCK, _account, _blockNumber))
        ];
    }

    function mintedInBlock(uint256 _blockNumber) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(MINTED_IN_BLOCK, _blockNumber))
        ];
    }

    function mintedTotally() public view returns(uint256) {
        return uintStorage[MINTED_TOTALLY];
    }

    function proxyStorage() public view returns(address) {
        return addressStorage[PROXY_STORAGE];
    }

    function _addExtraReceiver(address _receiver) private {
        addressArrayStorage[EXTRA_RECEIVERS].push(_receiver);
    }

    function _clearExtraReceivers() private {
        addressArrayStorage[EXTRA_RECEIVERS].length = 0;
    }

    function _getPayoutByMining(address _miningKey)
        private
        view
        returns (address)
    {
        IKeysManager keysManager = IKeysManager(
            IProxyStorage(proxyStorage()).getKeysManager()
        );
        address payoutKey = keysManager.getPayoutByMining(_miningKey);
        return (payoutKey != address(0)) ? payoutKey : _miningKey;
    }

    function _isMiningActive(address _miningKey)
        private
        view
        returns (bool)
    {
        IKeysManager keysManager = IKeysManager(
            IProxyStorage(proxyStorage()).getKeysManager()
        );
        return keysManager.isMiningActive(_miningKey);
    }

    function _setExtraReceiverAmount(uint256 _amount, address _receiver) private {
        uintStorage[
            keccak256(abi.encode(EXTRA_RECEIVERS_AMOUNTS, _receiver))
        ] = _amount;
    }

    function _setMinted(uint256 _amount, address _account) private {
        bytes32 hash;

        hash = keccak256(abi.encode(MINTED_FOR_ACCOUNT_IN_BLOCK, _account, block.number));
        uintStorage[hash] = _amount;

        hash = keccak256(abi.encode(MINTED_FOR_ACCOUNT, _account));
        uintStorage[hash] = uintStorage[hash].add(_amount);

        hash = keccak256(abi.encode(MINTED_IN_BLOCK, block.number));
        uintStorage[hash] = uintStorage[hash].add(_amount);

        hash = MINTED_TOTALLY;
        uintStorage[hash] = uintStorage[hash].add(_amount);
    }
}
