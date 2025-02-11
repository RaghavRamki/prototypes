// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {OneByTwo} from "../src/OneByTwo.sol";
import {ISRC20} from "../src/ISRC20.sol";

contract OneByTwoTest is Test {
    OneByTwo public onebytwo;

    // Declare event types for use in event emission tests.
    event Register(address Restaurant_, address tokenAddress);
    event SpentAtRestaurant(address Restaurant_, address Consumer_);

    function setUp() public {
        onebytwo = new OneByTwo();
    }

    /// @notice Ensure that the restaurant count increases upon registration.
    function test_oneNewRestaurant() public {
        uint256 start = onebytwo.restaurantCount();
        assertEq(start, 0);
        onebytwo.registerRestaurant("Restaurant One", "RONE");
        uint256 finish = onebytwo.restaurantCount();
        assertEq(finish, 1);
    }

    /// @notice A restaurant should not be able to register twice.
    function test_registerRestaurantTwice() public {
        onebytwo.registerRestaurant("Restaurant One", "RONE");
        vm.expectRevert("restaurant already registered");
        onebytwo.registerRestaurant("Restaurant One", "RONE");
    }

    /// @notice After registration, the restaurant’s token address should be set.
    function test_restaurantTokenMapping() public {
        onebytwo.registerRestaurant("Restaurant One", "RONE");
        address tokenAddress = onebytwo.restaurantsTokens(address(this));
        assertTrue(tokenAddress != address(0), "Token address should not be zero");
    }

    /// @notice Spending at an unregistered restaurant should revert.
    function test_spendAtRestaurantRevertsForNonRegisteredRestaurant() public {
        address unregisteredRestaurant = address(0x123);
        vm.expectRevert("restaurant is not registered");
        onebytwo.spendAtRestaurant(unregisteredRestaurant);
    }

    /// @notice Spending at a registered restaurant updates revenue and Customer spend correctly.
    function test_spendAtRestaurantUpdatesRevenue() public {
        // Use a different address for the restaurant.
        address restaurant = address(0x123);
        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        // Simulate a consumer spending 1 ether at the restaurant.
        address consumer = address(0x234);
        vm.deal(consumer, 2 ether);
        uint256 spendAmount = 1 ether;
        vm.prank(consumer);
        onebytwo.spendAtRestaurant{value: spendAmount}(restaurant);

        // Check the restaurant’s total revenue (only a registered restaurant can call this).
        vm.prank(restaurant);
        uint256 totalRevenue = onebytwo.checkTotalSpendRestaurant();
        assertEq(totalRevenue, spendAmount);

        // Check that the restaurant can view this consumer’s spend.
        vm.prank(restaurant);
        uint256 CustomerSpendAmount = onebytwo.checkCustomerSpendRestaurant(consumer);
        assertEq(CustomerSpendAmount, spendAmount);

        // Check that the consumer can view his/her spend at the restaurant.
        vm.prank(consumer);
        uint256 spendCustomer = onebytwo.checkSpendCustomer(restaurant);
        assertEq(spendCustomer, spendAmount);
    }

    /// @notice Multiple spends from the same consumer should accumulate.
    function test_multipleSpendsAccumulate() public {
        address restaurant = address(0x123);
        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        address consumer = address(0x234);
        vm.deal(consumer, 4 ether);
        uint256 spend1 = 1 ether;
        uint256 spend2 = 2 ether;
        vm.prank(consumer);
        onebytwo.spendAtRestaurant{value: spend1}(restaurant);
        vm.prank(consumer);
        onebytwo.spendAtRestaurant{value: spend2}(restaurant);

        vm.prank(restaurant);
        uint256 totalRevenue = onebytwo.checkTotalSpendRestaurant();
        assertEq(totalRevenue, spend1 + spend2);

        vm.prank(restaurant);
        uint256 CustomerSpendAmount = onebytwo.checkCustomerSpendRestaurant(consumer);
        assertEq(CustomerSpendAmount, spend1 + spend2);

        vm.prank(consumer);
        uint256 spendCustomer = onebytwo.checkSpendCustomer(restaurant);
        assertEq(spendCustomer, spend1 + spend2);
    }

    /// @notice Multiple spends from the different consumers should accumulate.
    function test_multipleDifSpendsAccumulate() public {
        address restaurant = address(0x123);
        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        address consumer = address(0x234);
        address consumer2 = address(0x2345);
        vm.deal(consumer, 4 ether);
        vm.deal(consumer2, 4 ether);

        uint256 spend1 = 1 ether;
        uint256 spend2 = 2 ether;

        vm.prank(consumer);
        onebytwo.spendAtRestaurant{value: spend1}(restaurant);
        vm.prank(consumer);
        onebytwo.spendAtRestaurant{value: spend2}(restaurant);

        vm.prank(consumer2);
        onebytwo.spendAtRestaurant{value: spend1}(restaurant);
        vm.prank(consumer2);
        onebytwo.spendAtRestaurant{value: spend2}(restaurant);

        vm.prank(restaurant);
        uint256 totalRevenue = onebytwo.checkTotalSpendRestaurant();
        assertEq(totalRevenue, 2 * (spend1 + spend2));

        vm.prank(restaurant);
        uint256 CustomerSpendAmount = onebytwo.checkCustomerSpendRestaurant(consumer);
        assertEq(CustomerSpendAmount, spend1 + spend2);
    
        vm.prank(restaurant);
        uint256 CustomerSpendAmount2 = onebytwo.checkCustomerSpendRestaurant(consumer2);
        assertEq(CustomerSpendAmount2, spend1 + spend2);

        vm.prank(consumer);
        uint256 spendCustomer = onebytwo.checkSpendCustomer(restaurant);
        assertEq(spendCustomer, spend1 + spend2);

        vm.prank(consumer2);
        uint256 spendCustomer2 = onebytwo.checkSpendCustomer(restaurant);
        assertEq(spendCustomer2, spend1 + spend2);
    }

    /// @notice Only a registered restaurant can call checkTotalSpendRestaurant.
    function test_checkTotalSpendRestaurantNonRegistered() public {
        vm.expectRevert("restaurant is not registered");
        onebytwo.checkTotalSpendRestaurant();
    }

    /// @notice Only a registered restaurant can call checkCustomerSpendRestaurant.
    function test_checkCustomerSpendRestaurantNonRegistered() public {
        vm.expectRevert("restaurant is not registered");
        onebytwo.checkCustomerSpendRestaurant(address(0x234));
    }

    /// @notice A consumer calling checkSpendCustomer for an unregistered restaurant should revert.
    function test_checkSpendCustomerNonRegisteredRestaurant() public {
        address unregisteredRestaurant = address(0x123);
        vm.expectRevert("restaurant is not registered");
        onebytwo.checkSpendCustomer(unregisteredRestaurant);
    }

    /// @notice Test that the SpentAtRestaurant event is emitted with the correct parameters.
    function test_spentAtRestaurantEmitsEvent() public {
        address restaurant = address(0x123);
        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        address consumer = address(0x234);
        vm.deal(consumer, 2 ether);
        uint256 spendAmount = 1 ether;

        // Expect the SpentAtRestaurant event with the given restaurant and consumer.
        vm.expectEmit(true, true, false, false);
        emit SpentAtRestaurant(restaurant, consumer);

        vm.prank(consumer);
        onebytwo.spendAtRestaurant{value: spendAmount}(restaurant);
    }

    /// @notice Test that the Register event is emitted when a restaurant registers.
    function test_registerRestaurantEmitsEvent() public {
        // Record logs so that we can inspect emitted events.
        vm.recordLogs();
        onebytwo.registerRestaurant("Restaurant One", "RONE");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool found = false;
        // Compute the expected signature of the Register event.
        bytes32 expectedSig = keccak256("Register(address,address)");
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics.length > 0 && entries[i].topics[0] == expectedSig) {
                // Decode the event data.
                (address restaurant, address token) = abi.decode(entries[i].data, (address, address));
                assertEq(restaurant, address(this));
                assertTrue(token != address(0), "Token address in event should not be zero");
                found = true;
                break;
            }
        }
        assertTrue(found, "Register event not found");
    }

    function test_sendTokens() public {
        address restaurant = address(0x123);
        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        address consumer = address(0x234);
        vm.deal(consumer, 2 ether);

        address tokenAddress = onebytwo.restaurantsTokens(restaurant);
        ISRC20 token = ISRC20(tokenAddress);

        vm.prank(restaurant);
        token.transfer(saddress(consumer), suint256(1000));

        vm.prank(consumer);
        uint256 balance = token.balanceOf();
        assertEq(balance, 1000);
    }

    function test_sendTokensIllegal() public {
        address restaurant = address(0x123);
        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        address consumer = address(0x234);
        address consumer2 = address(0x456);
        vm.deal(consumer, 2 ether);

        address tokenAddress = onebytwo.restaurantsTokens(restaurant);
        ISRC20 token = ISRC20(tokenAddress);

        vm.prank(restaurant);
        token.transfer(saddress(consumer), suint256(1000));

        vm.prank(consumer);
        uint256 balance = token.balanceOf();
        assertEq(balance, 1000);

        vm.prank(consumer);
        vm.expectRevert();
        token.transfer(saddress(consumer2), suint256(1000));
    }

    function test_checkOutNoTokens() public {
        address restaurant = address(0x123);
        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        address buyer = address(0x234);
        address holder = address(0x456);

        vm.deal(buyer, 2 ether);
        vm.prank(buyer);
        onebytwo.spendAtRestaurant{value: 1 ether}(restaurant);

        address tokenAddress = onebytwo.restaurantsTokens(restaurant);
        ISRC20 token = ISRC20(tokenAddress);

        vm.prank(holder);
        uint256 balance = token.balanceOf();
        assertEq(balance, 0);

        vm.prank(holder);
        vm.expectRevert();
        onebytwo.checkOut(restaurant, suint256(5e8));
    }

    function testUserReceivesTokensAndETHRefund() public {
        // ----------- STEP 1: Customer Spends at Restaurant -----------
        // Define how much the customer spends, and where the customer / restaurant are
        uint256 spendAmount = 1 ether;
        address customer = address(0x234);
        address restaurant = address(0x456);

        vm.prank(restaurant);
        onebytwo.registerRestaurant("Restaurant One", "RONE");

        address tokenAddress = onebytwo.restaurantsTokens(restaurant);
        ISRC20 token = ISRC20(tokenAddress);
        
        // Have the customer call spendAtRestaurant sending spendAmount ETH.
        // This call should update the revenue, track customer spend, and mint tokens to the customer.
        vm.prank(customer);
        onebytwo.spendAtRestaurant{value: spendAmount}(restaurant);

        // Verify that the customer received tokens on a 1:1 basis.

        vm.prank(customer);
        uint256 cusotmerBalance = token.balanceOf();

        assertEq(cusotmerBalance, spendAmount);

        // ----------- STEP 2: Approve and Call checkOut -----------
        // Before checking out, the customer must allow the OneByTwo contract to transfer tokens
        // on their behalf via the token’s transferFrom.
        vm.prank(customer);
        token.approve(saddress(onebytwo), suint256(cusotmerBalance));

        // Record ETH balances for later assertions.
        uint256 oneByTwoBalanceBefore = address(onebytwo).balance;
        uint256 customerEthBefore = customer.balance;

        // The customer now calls checkOut to trade in their tokens for an ETH payback.
        // Note: checkOut accepts a parameter of type suint256; here we assume that casting
        // the uint256 value to suint256 works in your code.
        vm.prank(customer);
        onebytwo.checkOut(restaurant, suint256(cusotmerBalance));

        // ----------- STEP 3: Calculate and Verify the ETH Refund -----------
        // In checkOut the entitlement is computed as:
        //     entitlement = (amount * totalRev) / token.totalSupply()
        // where:
        // - amount = customerTokenBalance (spent tokens)
        // - totalRev = spendAmount (since spendAtRestaurant updates revenue with msg.value)
        // - token.totalSupply() = initial supply (set in registerRestaurant) + tokens minted during spendAtRestaurant
        uint256 totalRev = spendAmount;
        uint256 tokenTotalSupply = token.totalSupply();
        uint256 expectedEntitlement = (cusotmerBalance * totalRev) / tokenTotalSupply;

        // The OneByTwo contract should have sent the expectedEntitlement to the customer.
        uint256 oneByTwoBalanceAfter = address(onebytwo).balance;
        uint256 customerEthAfter = customer.balance;

        // Verify that OneByTwo's ETH balance decreased by expectedEntitlement.
        assertEq(
            oneByTwoBalanceAfter,
            oneByTwoBalanceBefore - expectedEntitlement,
            "OneByTwo ETH balance should decrease by the expected entitlement"
        );

        // Verify that the customer's ETH balance increased by the expected entitlement.
        assertEq(
            customerEthAfter,
            customerEthBefore + expectedEntitlement,
            "Customer ETH balance should increase by the expected entitlement"
        );

        // ----------- STEP 4: Verify Tokens Were Transferred -----------
        // After checkout, the customer's tokens should have been transferred to the restaurant.
        
        vm.prank(customer);
        uint256 customerTokenBalanceAfter = token.balanceOf();
        
        assertEq(
            customerTokenBalanceAfter,
            0,
            "Customer token balance should be zero after checkout"
        );
    }
}
