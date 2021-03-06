pragma solidity ^0.4.23;


import "contracts/NuCypherToken.sol";
import "zeppelin/math/SafeMath.sol";
import "zeppelin/math/Math.sol";
import "proxy/Upgradeable.sol";


/**
* @notice Contract for calculate issued tokens
**/
contract Issuer is Upgradeable {
    using SafeMath for uint256;

    /// Issuer is initialized with a reserved reward
    event Initialized(uint256 reservedReward);

    NuCypherToken public token;
    uint256 public miningCoefficient;
    uint256 public secondsPerPeriod;
    uint256 public lockedPeriodsCoefficient;
    uint256 public awardedPeriods;

    uint256 public lastMintedPeriod;
    uint256 public totalSupply;
    /**
    * Current supply is used in the mining formula and is stored to prevent different calculation
    * for miners which get reward in the same period. There are two values -
    * supply for previous period (used in formula) and supply for current period which accumulates value
    * before end of period. There is no order between them because of storage savings.
    * So each time should check values of both variables.
    **/
    uint256 public currentSupply1;
    uint256 public currentSupply2;

    /**
    * @notice Constructor sets address of token contract and coefficients for mining
    * @dev Formula for mining in one period
    (totalSupply - currentSupply) * (lockedValue / totalLockedValue) * (k1 + allLockedPeriods) / k2
    if allLockedPeriods > awardedPeriods then allLockedPeriods = awardedPeriods
    * @param _token Token contract
    * @param _hoursPerPeriod Size of period in hours
    * @param _miningCoefficient Mining coefficient (k2)
    * @param _lockedPeriodsCoefficient Locked blocks coefficient (k1)
    * @param _awardedPeriods Max periods that will be additionally awarded
    **/
    constructor(
        NuCypherToken _token,
        uint256 _hoursPerPeriod,
        uint256 _miningCoefficient,
        uint256 _lockedPeriodsCoefficient,
        uint256 _awardedPeriods
    )
        public
    {
        require(address(_token) != 0x0 &&
            _miningCoefficient != 0 &&
            _hoursPerPeriod != 0 &&
            _lockedPeriodsCoefficient != 0 &&
            _awardedPeriods != 0);
        token = _token;
        miningCoefficient = _miningCoefficient;
        secondsPerPeriod = _hoursPerPeriod.mul(1 hours);
        lockedPeriodsCoefficient = _lockedPeriodsCoefficient;
        awardedPeriods = _awardedPeriods;
    }

    /**
    * @dev Checks miner initialization
    **/
    modifier isInitialized()
    {
        require(currentSupply1 != 0);
        _;
    }

    /**
    * @return Number of current period
    **/
    function getCurrentPeriod() public view returns (uint256) {
        return block.timestamp / secondsPerPeriod;
    }

    /**
    * @notice Initialize reserved tokens for reward
    **/
    function initialize() public {
        require(currentSupply1 == 0);
        lastMintedPeriod = getCurrentPeriod();
        totalSupply = token.totalSupply();
        uint256 reservedReward = token.balanceOf(address(this));
        uint256 currentTotalSupply = totalSupply.sub(reservedReward);
        currentSupply1 = currentTotalSupply;
        currentSupply2 = currentTotalSupply;
        emit Initialized(reservedReward);
    }

    /**
    * @notice Function to mint tokens for one period.
    * @param _period Period number.
    * @param _lockedValue The amount of tokens that were locked by user in specified period.
    * @param _totalLockedValue The amount of tokens that were locked by all users in specified period.
    * @param _allLockedPeriods The max amount of periods during which tokens will be locked after specified period.
    * @return Amount of minted tokens.
    */
    function mint(
        uint256 _period,
        uint256 _lockedValue,
        uint256 _totalLockedValue,
        uint256 _allLockedPeriods
    )
        internal returns (uint256 amount)
    {
        uint256 currentSupply = _period <= lastMintedPeriod ?
            Math.min256(currentSupply1, currentSupply2) :
            Math.max256(currentSupply1, currentSupply2);
        if (currentSupply == totalSupply) {
            return;
        }

        //totalSupply * lockedValue * (k1 + allLockedPeriods) / (totalLockedValue * k2) -
        //currentSupply * lockedValue * (k1 + allLockedPeriods) / (totalLockedValue * k2)
        uint256 allLockedPeriods = (_allLockedPeriods <= awardedPeriods ?
            _allLockedPeriods : awardedPeriods)
            .add(lockedPeriodsCoefficient);
        uint256 denominator = _totalLockedValue.mul(miningCoefficient);
        amount =
            totalSupply
                .mul(_lockedValue)
                .mul(allLockedPeriods)
                .div(denominator).sub(
            currentSupply
                .mul(_lockedValue)
                .mul(allLockedPeriods)
                .div(denominator));
        // rounding the last reward
        if (amount == 0) {
            amount = 1;
        }

        if (_period <= lastMintedPeriod) {
            if (currentSupply1 > currentSupply2) {
                currentSupply1 = currentSupply1.add(amount);
            } else {
                currentSupply2 = currentSupply2.add(amount);
            }
        } else {
            lastMintedPeriod = _period;
            if (currentSupply1 > currentSupply2) {
                currentSupply2 = currentSupply1.add(amount);
            } else {
                currentSupply1 = currentSupply2.add(amount);
            }
        }
    }

    function verifyState(address _testTarget) public onlyOwner {
        require(address(delegateGet(_testTarget, "token()")) == address(token));
        require(uint256(delegateGet(_testTarget, "miningCoefficient()")) == miningCoefficient);
        require(uint256(delegateGet(_testTarget, "secondsPerPeriod()")) == secondsPerPeriod);
        require(uint256(delegateGet(_testTarget, "lockedPeriodsCoefficient()")) == lockedPeriodsCoefficient);
        require(uint256(delegateGet(_testTarget, "awardedPeriods()")) == awardedPeriods);
        require(uint256(delegateGet(_testTarget, "lastMintedPeriod()")) == lastMintedPeriod);
        require(uint256(delegateGet(_testTarget, "currentSupply1()")) == currentSupply1);
        require(uint256(delegateGet(_testTarget, "currentSupply2()")) == currentSupply2);
        require(uint256(delegateGet(_testTarget, "totalSupply()")) == totalSupply);
    }

    function finishUpgrade(address _target) public onlyOwner {
        Issuer issuer = Issuer(_target);
        token = issuer.token();
        miningCoefficient = issuer.miningCoefficient();
        secondsPerPeriod = issuer.secondsPerPeriod();
        lockedPeriodsCoefficient = issuer.lockedPeriodsCoefficient();
        awardedPeriods = issuer.awardedPeriods();
    }
}
