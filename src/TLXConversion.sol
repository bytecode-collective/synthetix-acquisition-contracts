// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ITLXConversion} from "./interfaces/ITLXConversion.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title TLX Acquisition Token Conversion Contract
/// @notice Responsible for converting TLX tokens to SNX at a fixed rate of 18:1
/// @author Jeremy Chiaramonte (jeremy@bytecode.llc)
/// @author Andrew Chiaramonte (andrew@definative.xyz)
contract TLXConversion is ITLXConversion {
    /*//////////////////////////////////////////////////////////////
                          CONSTANTS/IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Fixed rate of 18:1 for TLX to SNX conversion
    uint256 public constant CONVERSION_RATE = 18;

    /// @notice Vesting lock duration in seconds (1 month)
    uint256 public constant VESTING_LOCK_DURATION = 30 days;

    /// @notice Linear vesting duration in seconds (4 month)
    uint256 public constant LINEAR_VESTING_DURATION = 120 days;

    /// @notice Withdrawal start time in seconds (2 years)
    uint256 public constant WITHDRAW_START = 730 days;

    /// @notice Global start time for vesting
    /// @notice Thursday, December 5, 2024 12:00:00 AM (GMT)
    /// @dev From this derive 1 month lock 4 month linear vesting
    uint256 public constant VESTING_START_TIME = 1_733_356_800;

    /// @notice Address of the Synthetix treasury
    address public constant SYNTHETIX_TREASURY =
        0xD25215758734dd3aDE497CE04De1c35820964126;

    /// @notice Time at which the lock ends
    /// @dev VESTING_START_TIME + VESTING_LOCK_DURATION
    /// @dev initialized during construction
    uint256 public immutable timeLockEnds;

    // CONTRACTS //////////////////////////////////////////

    /// @notice TLX token contract
    IERC20 public immutable TLX;

    /// @notice SNX token contract
    IERC20 public immutable SNX;

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of addresses to the amount of SNX owed
    /// @dev the amount of SNX owed is the amount of TLX / CONVERSION_RATE
    mapping(address => uint256) public owedSNX;

    /// @notice Mapping of addresses to the amount of SNX claimed
    mapping(address => uint256) public claimedSNX;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _tlx $TLX token address
    /// @param _snx $SNX token address
    constructor(address _tlx, address _snx) {
        if (_tlx == address(0) || _snx == address(0)) {
            revert AddressZero();
        }
        TLX = IERC20(_tlx);
        SNX = IERC20(_snx);
        timeLockEnds = VESTING_START_TIME + VESTING_LOCK_DURATION;
    }

    /*///////////////////////////////////////////////////////////////
                                VIEWS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITLXConversion
    function vestableAmount(address _account) public view returns (uint256) {
        if (block.timestamp < timeLockEnds) {
            return 0;
        }
        if (claimedSNX[_account] >= owedSNX[_account]) {
            return 0;
        }
        uint256 vestable;
        uint256 elapsed = block.timestamp - timeLockEnds;
        if (elapsed >= LINEAR_VESTING_DURATION) {
            vestable = owedSNX[_account] - claimedSNX[_account];
        } else {
            vestable = (owedSNX[_account] * elapsed) / LINEAR_VESTING_DURATION
                - claimedSNX[_account];
        }
        return vestable;
    }

    /*///////////////////////////////////////////////////////////////
                            MUTATIVE FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITLXConversion
    function lockAndConvert() public {
        uint256 tlxAmount = TLX.balanceOf(msg.sender);
        if (tlxAmount == 0) {
            revert InsufficientTLX();
        }
        if (SNX.balanceOf(address(this)) == 0) {
            revert ZeroContractSNX();
        }

        uint256 snxAmount = tlxAmount / CONVERSION_RATE;
        owedSNX[msg.sender] += snxAmount;
        SafeERC20.safeTransferFrom(TLX, msg.sender, address(this), tlxAmount);

        emit TLXLocked(msg.sender, tlxAmount);
    }

    /// @inheritdoc ITLXConversion
    function vest() public returns (uint256) {
        return vest(msg.sender);
    }

    /// @inheritdoc ITLXConversion
    function vest(address to) public returns (uint256 amountVested) {
        address caller = msg.sender;
        amountVested = vestableAmount(caller);
        if (amountVested == 0) {
            revert NoVestableAmount();
        }
        claimedSNX[caller] += amountVested;
        SafeERC20.safeTransfer(SNX, to, amountVested);
        emit SNXVested(caller, to, amountVested);
    }

    /// @inheritdoc ITLXConversion
    function withdrawSNX() public {
        if (msg.sender != SYNTHETIX_TREASURY) {
            revert Unauthorized();
        }
        if (block.timestamp < VESTING_START_TIME + WITHDRAW_START) {
            revert WithdrawalStartTimeNotReached();
        }
        SafeERC20.safeTransfer(SNX, msg.sender, SNX.balanceOf(address(this)));
    }
}
