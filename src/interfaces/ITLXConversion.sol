// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

interface ITLXConversion {
    /*///////////////////////////////////////////////////////////////
                                VIEWS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Returns the amount of SNX that can be vested
    /// @return The amount of SNX that can be vested
    function vestableAmount(address) external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                            MUTATIVE FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Locks TLX and converts it to SNX
    /// @notice requires TLX to be approved
    function lockAndConvert() external;

    /// @notice Vests SNX
    /// @return The amount of SNX vested
    function vest() external returns (uint256);

    /// @notice Vests SNX
    /// @param to The account that will receive the vested SNX
    /// @return The amount of SNX vested
    function vest(address to) external returns (uint256);

    /// @notice Withdraws leftover SNX after 2 years
    /// @dev only callable by the owner
    function withdrawSNX() external;

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    ///////////////////////////////////////////////////////////////*/

    /// @notice emitted when TLX is deposited for conversion
    /// @param from The account that locked TLX
    /// @param value The amount of TLX that was locked
    event TLXLocked(address indexed from, uint256 value);

    /// @notice emitted when SNX is vested and withdrawn
    /// @param from The account that is vesting SNX
    /// @param from The account that is receiving vested SNX
    /// @param value The amount of SNX that was vested
    event SNXVested(address indexed from, address indexed to, uint256 value);

    /// @notice emitted when SNX is withdrawn
    /// @param to The account that is receiving SNX
    /// @param value The amount of SNX that was withdrawn
    event SNXWithdrawn(address indexed to, uint256 value);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice thrown when address is 0
    error AddressZero();

    /// @notice thrown when insufficient TLX is locked
    error InsufficientTLX();

    /// @notice thrown when withdrawal start time is not reached
    error WithdrawalStartTimeNotReached();

    /// @notice thrown when caller is not the owner
    error Unauthorized();

    /// @notice thrown when contract has no SNX
    error ZeroContractSNX();

    /// @notice thrown when no SNX can be vested
    error NoVestableAmount();
}
