// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {StablecoinPaymentGateway} from "../src/StablecoinPaymentGateway.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StablecoinPaymentGatewayTest is Test {
    /* ---------- contracts ---------- */
    StablecoinPaymentGateway gateway;
    ERC20Mock usdc;
    ERC20Mock dai;

    /* ---------- actors ---------- */
    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address forwarder = makeAddr("forwarder");

    /* ---------- helpers ---------- */
    uint256 constant USDC_DECIMALS = 6;
    uint256 constant DAI_DECIMALS = 2;

    function setUp() public {
        usdc = new ERC20Mock();
        dai = new ERC20Mock();

        vm.prank(owner);
        gateway = new StablecoinPaymentGateway(forwarder);

        usdc.mint(alice, 10_000 * 10 ** USDC_DECIMALS);
        dai.mint(alice, 10_000 * 10 ** DAI_DECIMALS);

        vm.startPrank(alice);
        usdc.approve(address(gateway), type(uint256).max);
        dai.approve(address(gateway), type(uint256).max);
        vm.stopPrank();
    }

    /* --------------------------------------------------------
                               OWNER TESTS
       -------------------------------------------------------- */

    function test_manageToken_addNewToken() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit StablecoinPaymentGateway.TokenAdded(
            address(usdc),
            "USDC",
            1 * 10 ** USDC_DECIMALS,
            50
        );
        gateway.manageToken(
            address(usdc),
            "USDC",
            1 * 10 ** USDC_DECIMALS,
            50,
            true
        );

        (
            bool active,
            uint256 fixedFee,
            uint16 percentage,
            string memory symbol
        ) = gateway.tokenConfigs(address(usdc));
        assertTrue(active);
        assertEq(fixedFee, 1 * 10 ** USDC_DECIMALS);
        assertEq(percentage, 50);
        assertEq(symbol, "USDC");
    }

    function test_manageToken_revertsInvalidToken() public {
        vm.prank(owner);
        vm.expectRevert(StablecoinPaymentGateway.InvalidToken.selector);
        gateway.manageToken(address(0), "ZERO", 0, 0, true);
    }

    function test_manageToken_revertsEmptySymbol() public {
        vm.prank(owner);
        vm.expectRevert(StablecoinPaymentGateway.EmptySymbol.selector);
        gateway.manageToken(address(usdc), "", 0, 0, true);
    }

    function test_manageToken_revertsFixedFeeTooHigh() public {
        vm.prank(owner);
        vm.expectRevert(StablecoinPaymentGateway.FixedFeeTooHigh.selector);
        gateway.manageToken(
            address(usdc),
            "USDC",
            1_000_001 * 10 ** 18,
            0,
            true
        );
    }

    function test_manageToken_revertsPercentageFeeTooHigh() public {
        vm.prank(owner);
        vm.expectRevert(StablecoinPaymentGateway.PercentageFeeTooHigh.selector);
        gateway.manageToken(address(usdc), "USDC", 0, 501, true);
    }

    function test_toggleTokenActive() public {
        _addUsdc();

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit StablecoinPaymentGateway.TokenStatusChanged(address(usdc), false);
        gateway.toggleTokenActive(address(usdc));

        (bool active, , , ) = gateway.tokenConfigs(address(usdc));
        assertFalse(active);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit StablecoinPaymentGateway.TokenStatusChanged(address(usdc), true);
        gateway.toggleTokenActive(address(usdc));

        (active, , , ) = gateway.tokenConfigs(address(usdc));
        assertTrue(active);
    }

    function test_toggleTokenActive_revertsInvalidToken() public {
        vm.prank(owner);
        vm.expectRevert(StablecoinPaymentGateway.InvalidToken.selector);
        gateway.toggleTokenActive(address(0));
    }

    function test_toggleTokenActive_revertsTokenUnknown() public {
        vm.prank(owner);
        vm.expectRevert(StablecoinPaymentGateway.TokenUnknown.selector);
        gateway.toggleTokenActive(makeAddr("unknown"));
    }

    function test_updateTokenFees() public {
        _addUsdc();

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit StablecoinPaymentGateway.TokenFeeUpdated(
            address(usdc),
            2 * 10 ** USDC_DECIMALS,
            100
        );
        gateway.updateTokenFees(address(usdc), 2 * 10 ** USDC_DECIMALS, 100);

        (, uint256 fixedFee, uint16 percentage, ) = gateway.tokenConfigs(
            address(usdc)
        );
        assertEq(fixedFee, 2 * 10 ** USDC_DECIMALS);
        assertEq(percentage, 100);
    }

    function test_updateTokenFees_revertsInvalidToken() public {
        vm.prank(owner);
        vm.expectRevert(StablecoinPaymentGateway.InvalidToken.selector);
        gateway.updateTokenFees(address(0), 0, 0);
    }

    function test_updateTokenFees_revertsTokenNotActive() public {
        vm.prank(owner);
        gateway.manageToken(address(usdc), "USDC", 1, 1, false);

        vm.expectRevert(StablecoinPaymentGateway.TokenNotActive.selector);
        vm.prank(owner);
        gateway.updateTokenFees(address(usdc), 0, 0);
    }

    function test_updateTokenFees_revertsPercentageFeeTooHigh() public {
        _addUsdc();

        vm.prank(owner);
        vm.expectRevert(StablecoinPaymentGateway.PercentageFeeTooHigh.selector);
        gateway.updateTokenFees(address(usdc), 0, 501);
    }

    function test_updateTokenFees_revertsFixedFeeTooHigh() public {
        _addUsdc();

        vm.prank(owner);
        vm.expectRevert(StablecoinPaymentGateway.FixedFeeTooHigh.selector);
        gateway.updateTokenFees(address(usdc), 1_000_001 * 10 ** 18, 0);
    }

    function test_withdrawFees() public {
        _addUsdc();
        _alicePaysUsdc(100 * 10 ** USDC_DECIMALS);

        uint256 fee = gateway.collectedFees(address(usdc));
        assertGt(fee, 0);

        uint256 ownerBefore = usdc.balanceOf(owner);

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit StablecoinPaymentGateway.FeesWithdrawn(address(usdc), owner, fee);
        gateway.withdrawFees(address(usdc), 0);

        assertEq(usdc.balanceOf(owner), ownerBefore + fee);
        assertEq(gateway.collectedFees(address(usdc)), 0);
    }

    function test_withdrawFees_revertsInvalidToken() public {
        vm.prank(owner);
        vm.expectRevert(StablecoinPaymentGateway.InvalidToken.selector);
        gateway.withdrawFees(address(0), 0);
    }

    function test_withdrawFees_revertsInsufficientBalance() public {
        _addUsdc();
        vm.prank(owner);
        vm.expectRevert(StablecoinPaymentGateway.InsufficientBalance.selector);
        gateway.withdrawFees(address(usdc), 1);
    }

    /* --------------------------------------------------------
                            PUBLIC VIEW TESTS
       -------------------------------------------------------- */

    function test_getAllActiveTokens() public {
        _addUsdc();
        _addDai();

        (
            address[] memory tokens,
            StablecoinPaymentGateway.TokenConfig[] memory cfgs
        ) = gateway.getAllActiveTokens();

        assertEq(tokens.length, 2);
        assertEq(tokens[0], address(usdc));
        assertEq(tokens[1], address(dai));

        assertEq(cfgs[0].symbol, "USDC");
        assertEq(cfgs[1].symbol, "DAI");
    }

    function test_calculateFee() public {
        _addUsdc();

        uint256 fee = gateway.calculateFee(
            address(usdc),
            1000 * 10 ** USDC_DECIMALS
        );
        assertEq(fee, 6 * 10 ** USDC_DECIMALS);
    }

    /* --------------------------------------------------------
                           PAYMENT TESTS
       -------------------------------------------------------- */

    function test_pay() public {
        _addUsdc();

        uint256 amount = 1000 * 10 ** USDC_DECIMALS;
        uint256 fee = gateway.calculateFee(address(usdc), amount);
        uint256 bobBefore = usdc.balanceOf(bob);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit StablecoinPaymentGateway.PaymentProcessed(
            alice,
            bob,
            address(usdc),
            amount,
            fee
        );
        gateway.pay(address(usdc), bob, amount);

        assertEq(usdc.balanceOf(bob), bobBefore + amount - fee);
        assertEq(gateway.collectedFees(address(usdc)), fee);
    }

    function test_pay_revertsInvalidToken() public {
        vm.prank(alice);
        vm.expectRevert(StablecoinPaymentGateway.InvalidToken.selector);
        gateway.pay(address(0), bob, 100 * 10 ** USDC_DECIMALS);
    }

    function test_pay_revertsTokenNotActive() public {
        vm.prank(alice);
        vm.expectRevert(StablecoinPaymentGateway.TokenNotActive.selector);
        gateway.pay(address(usdc), bob, 100 * 10 ** USDC_DECIMALS);
    }

    function test_pay_revertsInvalidRecipient() public {
        _addUsdc();
        vm.prank(alice);
        vm.expectRevert(StablecoinPaymentGateway.InvalidRecipient.selector);
        gateway.pay(address(usdc), address(0), 100 * 10 ** USDC_DECIMALS);
    }

    function test_pay_revertsAmountTooSmall() public {
        _addUsdc();
        vm.prank(alice);
        vm.expectRevert(StablecoinPaymentGateway.AmountTooSmall.selector);
        gateway.pay(address(usdc), bob, 5 * 1 ** USDC_DECIMALS);
    }

    /* --------------------------------------------------------
                           INTERNAL HELPERS
       -------------------------------------------------------- */

    function _addUsdc() internal {
        vm.prank(owner);
        gateway.manageToken(
            address(usdc),
            "USDC",
            1 * 10 ** USDC_DECIMALS,
            50,
            true
        );
    }

    function _addDai() internal {
        vm.prank(owner);
        gateway.manageToken(address(dai), "DAI", 1 * 10 ** 18, 50, true);
    }

    function _alicePaysUsdc(uint256 amount) internal {
        vm.prank(alice);
        gateway.pay(address(usdc), bob, amount);
    }
}
