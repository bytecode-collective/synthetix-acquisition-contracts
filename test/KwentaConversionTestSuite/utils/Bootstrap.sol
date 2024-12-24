// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {console2} from "lib/forge-std/src/console2.sol";
import {
    KwentaConversion,
    OptimismParameters,
    Setup,
    DeployOptimism
} from "script/DeployKwenta.s.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {MockToken} from "test/KwentaConversionTestSuite/utils/MockToken.sol";
import {Constants} from "./Constants.sol";
import {IERC20} from
    "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Bootstrap is Test, Constants {
    using console2 for *;

    /// @dev for testing
    event KWENTALocked(address indexed from, uint256 value);
    event SNXVested(address indexed from, address indexed to, uint256 value);

    KwentaConversion internal conversion;
    MockToken internal KWENTAMock;
    MockToken internal SNXMock;
    IERC20 internal KWENTA;
    IERC20 internal SNX;
    BootstrapLocal internal bootstrapLocal;
    BootstrapOptimism internal bootstrapOptimism;

    function initializeLocal() internal {
        KWENTAMock = new MockToken();
        SNXMock = new MockToken();
        bootstrapLocal = new BootstrapLocal();
        (address conversionAddress) =
            bootstrapLocal.init(address(KWENTAMock), address(SNXMock));
        SNXMock.transfer(conversionAddress, MINT_AMOUNT);
        conversion = KwentaConversion(conversionAddress);
    }

    function initializeOptimism() internal {
        vm.rollFork(OPTIMISM_BLOCK_NUMBER);
        bootstrapOptimism = new BootstrapOptimism();
        (address conversionAddress, address kwenta, address snx) =
            bootstrapOptimism.init();

        conversion = KwentaConversion(conversionAddress);
        KWENTA = IERC20(kwenta);
        SNX = IERC20(snx);
        vm.prank(LARGEST_SNX_HOLDER);
        SNX.transfer(conversionAddress, MINT_AMOUNT);
    }
}

contract BootstrapLocal is Setup {
    function init(address _kwenta, address _snx) public returns (address) {
        address conversionAddress = Setup.deploySystem(_kwenta, _snx);

        return conversionAddress;
    }
}

contract BootstrapOptimism is DeployOptimism {
    function init() public returns (address, address, address) {
        address conversionAddress = DeployOptimism.run();

        return (conversionAddress, OPTIMISM_KWENTA, OPTIMISM_SNX);
    }
}
