// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Constants} from "./Constants.sol";

contract MockToken is ERC20, Constants {
    constructor() ERC20("MockToken", "MTK") {
        _mint(msg.sender, MINT_AMOUNT);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
