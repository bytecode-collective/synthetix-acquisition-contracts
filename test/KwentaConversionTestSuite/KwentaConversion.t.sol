// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Bootstrap} from "test/KwentaConversionTestSuite/utils/Bootstrap.sol";
import {IKwentaConversion} from "src/interfaces/IKwentaConversion.sol";
import {KwentaConversion} from "src/KwentaConversion.sol";

contract KwentaConversionTest is Bootstrap {
    function setUp() public {
        initializeLocal();
        /// @dev warp ahead of the vesting start time to simulate deployment conditions
        /// (i.e. the contract is deployed after the vesting start time)
        vm.warp(VESTING_START_TIME + 1 weeks);
    }

    function testConversionRateFixed17to1(uint256 amount) public {
        vm.assume(amount <= type(uint256).max / CONVERSION_RATE);
        vm.assume(amount > 0);
        KWENTAMock.mint(TEST_USER_1, amount);
        uint256 owedSNXBefore = conversion.owedSNX(TEST_USER_1);
        assertEq(owedSNXBefore, 0);

        vm.startPrank(TEST_USER_1);
        KWENTAMock.approve(address(conversion), amount);
        conversion.lockAndConvert();
        vm.stopPrank();

        uint256 owedSNXAfter = conversion.owedSNX(TEST_USER_1);
        uint256 expectedOwedSNX = amount * CONVERSION_RATE;
        assertEq(owedSNXAfter, expectedOwedSNX);
    }

    function testLockAndConvert() public {
        KWENTAMock.mint(TEST_USER_1, TEST_AMOUNT);
        uint256 owedSNXBefore = conversion.owedSNX(TEST_USER_1);
        uint256 userKWENTABefore = KWENTAMock.balanceOf(TEST_USER_1);
        uint256 contractKWENTABefore = KWENTAMock.balanceOf(address(conversion));
        assertEq(owedSNXBefore, 0);
        assertEq(userKWENTABefore, TEST_AMOUNT);
        assertEq(contractKWENTABefore, 0);

        vm.startPrank(TEST_USER_1);
        KWENTAMock.approve(address(conversion), TEST_AMOUNT);
        conversion.lockAndConvert();
        vm.stopPrank();

        uint256 owedSNXAfter = conversion.owedSNX(TEST_USER_1);
        uint256 userKWENTAAfter = KWENTAMock.balanceOf(TEST_USER_1);
        uint256 contractKWENTAAfter = KWENTAMock.balanceOf(address(conversion));
        assertEq(owedSNXAfter, CONVERTED_SNX_AMOUNT);
        assertEq(userKWENTAAfter, 0);
        assertEq(contractKWENTAAfter, TEST_AMOUNT);
    }

    function testLockAndConvertZeroContractSNX() public {
        KWENTAMock.mint(TEST_USER_1, TEST_AMOUNT);
        conversion = KwentaConversion(
            bootstrapLocal.init(address(KWENTAMock), address(SNXMock))
        );

        vm.startPrank(TEST_USER_1);
        KWENTAMock.approve(address(conversion), TEST_AMOUNT);
        vm.expectRevert(IKwentaConversion.ZeroContractSNX.selector);
        conversion.lockAndConvert();
        vm.stopPrank();
    }

    function testLockAndConvertAfterVestingDuration() public {
        vm.warp(
            block.timestamp + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
                + 1
        );

        KWENTAMock.mint(TEST_USER_1, TEST_AMOUNT);
        uint256 owedSNXBefore = conversion.owedSNX(TEST_USER_1);
        uint256 userKWENTABefore = KWENTAMock.balanceOf(TEST_USER_1);
        uint256 contractKWENTABefore = KWENTAMock.balanceOf(address(conversion));
        assertEq(owedSNXBefore, 0);
        assertEq(userKWENTABefore, TEST_AMOUNT);
        assertEq(contractKWENTABefore, 0);

        vm.startPrank(TEST_USER_1);
        KWENTAMock.approve(address(conversion), TEST_AMOUNT);
        conversion.lockAndConvert();
        vm.stopPrank();

        uint256 owedSNXAfter = conversion.owedSNX(TEST_USER_1);
        uint256 userKWENTAAfter = KWENTAMock.balanceOf(TEST_USER_1);
        uint256 contractKWENTAAfter = KWENTAMock.balanceOf(address(conversion));
        assertEq(owedSNXAfter, CONVERTED_SNX_AMOUNT);
        assertEq(userKWENTAAfter, 0);
        assertEq(contractKWENTAAfter, TEST_AMOUNT);
    }

    function testLockAndConvertEmit() public {
        KWENTAMock.mint(TEST_USER_1, TEST_AMOUNT);
        vm.startPrank(TEST_USER_1);
        KWENTAMock.approve(address(conversion), TEST_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit KWENTALocked(TEST_USER_1, TEST_AMOUNT);
        conversion.lockAndConvert();
        vm.stopPrank();
    }

    function testLockAndConvertInsufficientKWENTA() public {
        uint256 balance = KWENTAMock.balanceOf(TEST_USER_2);
        assertEq(balance, 0);

        vm.startPrank(TEST_USER_2);
        KWENTAMock.approve(address(conversion), TEST_AMOUNT);
        vm.expectRevert(IKwentaConversion.InsufficientKWENTA.selector);
        conversion.lockAndConvert();
        vm.stopPrank();
    }

    function testVestableAmountBeforeLock() public {
        basicLock();

        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(VESTING_START_TIME + VESTING_LOCK_DURATION);
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(block.timestamp + 1);
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertGt(vestableAmount, 0);
    }

    function testVestableAmountLinear() public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_LOCK_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(block.timestamp + 1);
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / LINEAR_VESTING_DURATION);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 3
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 3);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT);
    }

    function testVestableAmountLinearFuzz(uint64 amount) public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_LOCK_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(block.timestamp + amount);
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        if (amount > LINEAR_VESTING_DURATION) {
            assertEq(vestableAmount, CONVERTED_SNX_AMOUNT);
        } else {
            assertEq(
                vestableAmount,
                CONVERTED_SNX_AMOUNT * amount / LINEAR_VESTING_DURATION
            );
        }
    }

    function testVestableAmountVest() public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_LOCK_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);

        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);
    }

    function testVestableAmountLockMore() public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_LOCK_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);

        basicLock();
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT * 2);
    }

    function testVestableAmountLockMoreAndVest() public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_LOCK_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);

        basicLock();
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT);

        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT);
    }

    function testVest() public {
        basicLock();

        uint256 userSNXBefore = SNXMock.balanceOf(TEST_USER_1);
        uint256 contractSNXBefore = SNXMock.balanceOf(address(conversion));
        uint256 claimedSNXBefore = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXBefore, 0);
        assertEq(contractSNXBefore, MINT_AMOUNT);
        assertEq(claimedSNXBefore, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        uint256 userSNXAfter = SNXMock.balanceOf(TEST_USER_1);
        uint256 contractSNXAfter = SNXMock.balanceOf(address(conversion));
        uint256 claimedSNXAfter = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXAfter, CONVERTED_SNX_AMOUNT / 2);
        assertEq(contractSNXAfter, MINT_AMOUNT - (CONVERTED_SNX_AMOUNT / 2));
        assertEq(claimedSNXAfter, CONVERTED_SNX_AMOUNT / 2);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
        );
        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        uint256 userSNXFinal = SNXMock.balanceOf(TEST_USER_1);
        uint256 contractSNXFinal = SNXMock.balanceOf(address(conversion));
        uint256 claimedSNXFinal = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXFinal, CONVERTED_SNX_AMOUNT);
        assertEq(contractSNXFinal, MINT_AMOUNT - CONVERTED_SNX_AMOUNT);
        assertEq(claimedSNXFinal, CONVERTED_SNX_AMOUNT);
    }

    function testVestBasic() public {
        basicLock();

        uint256 userSNXBefore = SNXMock.balanceOf(TEST_USER_1);
        uint256 contractSNXBefore = SNXMock.balanceOf(address(conversion));
        uint256 claimedSNXBefore = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXBefore, 0);
        assertEq(contractSNXBefore, MINT_AMOUNT);
        assertEq(claimedSNXBefore, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vm.prank(TEST_USER_1);
        conversion.vest();

        uint256 userSNXAfter = SNXMock.balanceOf(TEST_USER_1);
        uint256 contractSNXAfter = SNXMock.balanceOf(address(conversion));
        uint256 claimedSNXAfter = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXAfter, CONVERTED_SNX_AMOUNT / 2);
        assertEq(contractSNXAfter, MINT_AMOUNT - (CONVERTED_SNX_AMOUNT / 2));
        assertEq(claimedSNXAfter, CONVERTED_SNX_AMOUNT / 2);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
        );
        vm.prank(TEST_USER_1);
        conversion.vest();

        uint256 userSNXFinal = SNXMock.balanceOf(TEST_USER_1);
        uint256 contractSNXFinal = SNXMock.balanceOf(address(conversion));
        uint256 claimedSNXFinal = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXFinal, CONVERTED_SNX_AMOUNT);
        assertEq(contractSNXFinal, MINT_AMOUNT - CONVERTED_SNX_AMOUNT);
        assertEq(claimedSNXFinal, CONVERTED_SNX_AMOUNT);
    }

    function testVestExploitVestPartialWaitVestFull() public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_LOCK_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);

        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
                + LINEAR_VESTING_DURATION / 2
        );

        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);

        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);
        assertEq(conversion.claimedSNX(TEST_USER_1), CONVERTED_SNX_AMOUNT);
        assertEq(SNXMock.balanceOf(TEST_USER_1), CONVERTED_SNX_AMOUNT);
    }

    function testVestBasicThenVestAgainWhenFullyVested() public {
        testVestBasic();
        uint256 userSNXBefore = SNXMock.balanceOf(TEST_USER_1);
        vm.prank(TEST_USER_1);
        vm.expectRevert(IKwentaConversion.NoVestableAmount.selector);
        conversion.vest();
        uint256 userSNXAfter = SNXMock.balanceOf(TEST_USER_1);
        assertEq(userSNXAfter, userSNXBefore);

        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);
        assertEq(conversion.claimedSNX(TEST_USER_1), CONVERTED_SNX_AMOUNT);
        assertEq(SNXMock.balanceOf(TEST_USER_1), CONVERTED_SNX_AMOUNT);
    }

    function testVestBasicThenWaitAndVestAgainWhenFullyVested() public {
        testVestBasic();
        vm.warp(block.timestamp + 30 days);
        uint256 userSNXBefore = SNXMock.balanceOf(TEST_USER_1);
        vm.prank(TEST_USER_1);
        vm.expectRevert(IKwentaConversion.NoVestableAmount.selector);
        conversion.vest();
        uint256 userSNXAfter = SNXMock.balanceOf(TEST_USER_1);
        assertEq(userSNXAfter, userSNXBefore);

        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);
        assertEq(conversion.claimedSNX(TEST_USER_1), CONVERTED_SNX_AMOUNT);
        assertEq(SNXMock.balanceOf(TEST_USER_1), CONVERTED_SNX_AMOUNT);
    }

    function testVestBasicAndLockAndVestAgain() public {
        testVestBasic();

        uint256 userSNXBefore = SNXMock.balanceOf(TEST_USER_1);
        uint256 contractSNXBefore = SNXMock.balanceOf(address(conversion));
        uint256 claimedSNXBefore = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXBefore, CONVERTED_SNX_AMOUNT);
        assertEq(contractSNXBefore, MINT_AMOUNT - CONVERTED_SNX_AMOUNT);
        assertEq(claimedSNXBefore, CONVERTED_SNX_AMOUNT);

        /// @dev note that the KWENTA will be fully vested by this point
        basicLock();
        vm.prank(TEST_USER_1);
        conversion.vest();

        uint256 userSNXAfter = SNXMock.balanceOf(TEST_USER_1);
        uint256 contractSNXAfter = SNXMock.balanceOf(address(conversion));
        uint256 claimedSNXAfter = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXAfter, CONVERTED_SNX_AMOUNT * 2);
        assertEq(contractSNXAfter, MINT_AMOUNT - (CONVERTED_SNX_AMOUNT * 2));
        assertEq(claimedSNXAfter, CONVERTED_SNX_AMOUNT * 2);
    }

    function testVestAfterWithdraw() public {
        basicLock();

        uint256 userSNXBefore = SNXMock.balanceOf(TEST_USER_1);
        uint256 contractSNXBefore = SNXMock.balanceOf(address(conversion));
        uint256 claimedSNXBefore = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXBefore, 0);
        assertEq(contractSNXBefore, MINT_AMOUNT);
        assertEq(claimedSNXBefore, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vm.prank(TEST_USER_1);
        conversion.vest();

        uint256 userSNXAfter = SNXMock.balanceOf(TEST_USER_1);
        uint256 contractSNXAfter = SNXMock.balanceOf(address(conversion));
        uint256 claimedSNXAfter = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXAfter, CONVERTED_SNX_AMOUNT / 2);
        assertEq(contractSNXAfter, MINT_AMOUNT - (CONVERTED_SNX_AMOUNT / 2));
        assertEq(claimedSNXAfter, CONVERTED_SNX_AMOUNT / 2);

        // withdraw

        uint256 contractSNXBeforeWithdraw =
            SNXMock.balanceOf(address(conversion));
        uint256 ownerSNXBeforeWithdraw = SNXMock.balanceOf(SYNTHETIX_TREASURY);
        assertEq(
            contractSNXBeforeWithdraw, MINT_AMOUNT - (CONVERTED_SNX_AMOUNT / 2)
        );
        assertEq(ownerSNXBeforeWithdraw, 0);

        vm.warp(VESTING_START_TIME + WITHDRAW_START);
        vm.prank(SYNTHETIX_TREASURY);
        conversion.withdrawSNX();
        vm.prank(TEST_USER_1);
        vm.expectRevert();
        conversion.vest();

        uint256 userSNXFinal = SNXMock.balanceOf(TEST_USER_1);
        uint256 contractSNXFinal = SNXMock.balanceOf(address(conversion));
        uint256 claimedSNXFinal = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXFinal, CONVERTED_SNX_AMOUNT / 2);
        assertEq(contractSNXFinal, 0);
        assertEq(claimedSNXFinal, CONVERTED_SNX_AMOUNT / 2);

        uint256 contractSNXAfterWithdraw =
            SNXMock.balanceOf(address(conversion));
        uint256 ownerSNXAfterWithdraw = SNXMock.balanceOf(SYNTHETIX_TREASURY);
        assertEq(contractSNXAfterWithdraw, 0);
        assertEq(ownerSNXAfterWithdraw, MINT_AMOUNT - CONVERTED_SNX_AMOUNT / 2);
    }

    function testVestEmit() public {
        basicLock();

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vm.prank(TEST_USER_1);
        vm.expectEmit(true, true, true, true);
        emit SNXVested(TEST_USER_1, TEST_USER_1, CONVERTED_SNX_AMOUNT / 2);
        conversion.vest(TEST_USER_1);
    }

    function testWithdrawSNX() public {
        uint256 contractSNXBefore = SNXMock.balanceOf(address(conversion));
        uint256 ownerSNXBefore = SNXMock.balanceOf(SYNTHETIX_TREASURY);
        assertEq(contractSNXBefore, MINT_AMOUNT);
        assertEq(ownerSNXBefore, 0);

        vm.warp(VESTING_START_TIME + WITHDRAW_START);
        vm.prank(SYNTHETIX_TREASURY);
        conversion.withdrawSNX();

        uint256 contractSNXAfter = SNXMock.balanceOf(address(conversion));
        uint256 ownerSNXAfter = SNXMock.balanceOf(SYNTHETIX_TREASURY);
        assertEq(contractSNXAfter, 0);
        assertEq(ownerSNXAfter, MINT_AMOUNT);
    }

    function testWithdrawSNXOnlyOwner() public {
        vm.prank(TEST_USER_1);
        vm.expectRevert(IKwentaConversion.Unauthorized.selector);
        conversion.withdrawSNX();
    }

    function testWithdrawSNXWithdrawalStartTimeNotReached() public {
        vm.warp(VESTING_START_TIME + WITHDRAW_START - 1);
        vm.prank(SYNTHETIX_TREASURY);
        vm.expectRevert(
            IKwentaConversion.WithdrawalStartTimeNotReached.selector
        );
        conversion.withdrawSNX();

        vm.warp(block.timestamp + 1);
        vm.prank(SYNTHETIX_TREASURY);
        conversion.withdrawSNX();
    }

    function testWithdrawSNXWithdrawalStartTimeNotReachedFuzz(uint128 amount)
        public
    {
        vm.warp(VESTING_START_TIME + amount);
        if (amount < WITHDRAW_START) {
            vm.prank(SYNTHETIX_TREASURY);
            vm.expectRevert(
                IKwentaConversion.WithdrawalStartTimeNotReached.selector
            );
            conversion.withdrawSNX();
        } else {
            vm.prank(SYNTHETIX_TREASURY);
            conversion.withdrawSNX();
        }
    }

    function testDeploymentAddressZero() public {
        vm.expectRevert(IKwentaConversion.AddressZero.selector);
        bootstrapLocal.init(address(0), address(0));
        vm.expectRevert(IKwentaConversion.AddressZero.selector);
        bootstrapLocal.init(address(KWENTAMock), address(0));
        vm.expectRevert(IKwentaConversion.AddressZero.selector);
        bootstrapLocal.init(address(0), address(SNXMock));
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function basicLock() public {
        KWENTAMock.mint(TEST_USER_1, TEST_AMOUNT);
        vm.startPrank(TEST_USER_1);
        KWENTAMock.approve(address(conversion), TEST_AMOUNT);
        conversion.lockAndConvert();
        vm.stopPrank();
    }
}
