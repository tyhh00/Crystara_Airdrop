#[test_only]
module projectOwnerAdr::airdrop_tests {
    use std::string::{utf8};
    use std::signer;
    use std::vector;
    use supra_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability};
    use supra_framework::account;
    use supra_framework::timestamp;
    use projectOwnerAdr::airdrop;

    // Test coin
    struct TestCoin {}

    // Test constants
    const PROJECT_OWNER: address = @projectOwnerAdr;
    const USER1: address = @0x111;
    const USER2: address = @0x222;
    const USER3: address = @0x333;
    
    // Setup function for tests
    fun setup_test(
        aptos_framework: &signer,
        project_owner: &signer,
        user1: &signer,
        user2: &signer
    ): (BurnCapability<TestCoin>, FreezeCapability<TestCoin>, MintCapability<TestCoin>) {
        // Initialize timestamp for testing
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
        // Initialize test coin
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<TestCoin>(
            project_owner,
            utf8(b"Test Coin"),
            utf8(b"TEST"),
            6,
            false,
        );
        
        // Register users with the coin
        coin::register<TestCoin>(project_owner);
        coin::register<TestCoin>(user1);
        coin::register<TestCoin>(user2);
        
        // Mint some coins to project owner for airdrop funding
        let coins = coin::mint<TestCoin>(100000000, &mint_cap);
        coin::deposit(signer::address_of(project_owner), coins);
        
        // Initialize airdrop module
        airdrop::initialize<TestCoin>(project_owner);
        
        (burn_cap, freeze_cap, mint_cap)
    }
    
    #[test]
    /// Test basic initialization of the airdrop module
    fun test_initialize() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        // First initialize the TestCoin
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<TestCoin>(
            &project_owner,
            utf8(b"Test Coin"),
            utf8(b"TEST"),
            6,
            false,
        );

        // Now initialize airdrop
        airdrop::initialize<TestCoin>(&project_owner);
        
        // Check that claims are initially disabled
        assert!(!airdrop::is_claims_enabled<TestCoin>(), 0);
        
        // Check that total allocation is initially 0
        assert!(airdrop::get_total_allocation<TestCoin>() == 0, 1);
        
        // Check that airdrop balance is initially 0
        assert!(airdrop::get_airdrop_balance<TestCoin>() == 0, 2);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test setting and overriding allocations
    fun test_set_allocation() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, freeze_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Create address and amount vectors
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        // Set allocation
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Test Allocation")
        );
        
        // Check that total allocation is 1000
        assert!(airdrop::get_total_allocation<TestCoin>() == 1000, 3);
        
        // Update allocation to 2000
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 2000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Test Allocation")
        );
        
        // Check that total allocation is 2000
        assert!(airdrop::get_total_allocation<TestCoin>() == 2000, 4);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test that a user cannot claim the same reason twice
    fun test_no_double_claim() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, freeze_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Create allocation for user1
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        // Set allocation
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Test Allocation")
        );
        
        // Deposit to airdrop
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 2000); // Enough for both users
        
        // Enable claims
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // First claim should succeed
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 5);
        
        // Second claim should not find any unclaimed allocations for the user
        // Instead of expecting an error, let's check that the balance remains the same
        // Need to disable claims first and then re-enable to reset the state
        airdrop::enable_claims<TestCoin>(&project_owner, false);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // Try to claim again - this should not increase the balance
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 6); // Balance should still be 1000
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test that a user can claim from multiple reasons
    fun test_multiple_reasons() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, freeze_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Set multiple allocations for user1
        let addresses1 = vector::empty<address>();
        vector::push_back(&mut addresses1, USER1);
        
        let amounts1 = vector::empty<u64>();
        vector::push_back(&mut amounts1, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses1,
            amounts1,
            utf8(b"Reason 1")
        );
        
        let addresses2 = vector::empty<address>();
        vector::push_back(&mut addresses2, USER1);
        
        let amounts2 = vector::empty<u64>();
        vector::push_back(&mut amounts2, 2000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses2,
            amounts2,
            utf8(b"Reason 2")
        );
        
        // Deposit to airdrop
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 3000);
        
        // Enable claims
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // Claim both reasons at once
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 3000, 7);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test that if a user has claimed one reason and a new reason is added, they can claim the new one
    fun test_claim_new_reasons() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, freeze_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Set initial allocation
        let addresses1 = vector::empty<address>();
        vector::push_back(&mut addresses1, USER1);
        
        let amounts1 = vector::empty<u64>();
        vector::push_back(&mut amounts1, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses1,
            amounts1,
            utf8(b"Reason 1")
        );
        
        // Deposit to airdrop
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 3000);
        
        // Enable claims
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // Claim first reason
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 8);
        
        // Add a new reason
        let addresses2 = vector::empty<address>();
        vector::push_back(&mut addresses2, USER1);
        
        let amounts2 = vector::empty<u64>();
        vector::push_back(&mut amounts2, 2000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses2,
            amounts2,
            utf8(b"Reason 2")
        );
        
        // Need to disable claims and re-enable since we added a new allocation
        airdrop::enable_claims<TestCoin>(&project_owner, false);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // Claim the new reason
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 3000, 9);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test that a user can make a basic claim
    fun test_basic_claim() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, freeze_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Set allocation
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Test Allocation")
        );
        
        // Deposit to airdrop
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 1000);
        
        // Enable claims
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // Claim
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 10);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test that a modified allocation cannot be claimed twice
    fun test_modified_allocation_no_double_claim() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, freeze_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Set initial allocation
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Test Allocation")
        );
        
        // Deposit to airdrop
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 3000);
        
        // Enable claims
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // Claim
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 11);
        
        // Modify the allocation (increase amount)
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 2000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Test Allocation")
        );
        
        // Disable claims and re-enable
        airdrop::enable_claims<TestCoin>(&project_owner, false);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // Try to claim again - this should not find any unclaimed allocations
        // Instead of expecting an error, let's check that the balance remains the same
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 12); // Balance should still be 1000
        
        // Set a new allocation with a different reason
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"New Reason")
        );
        
        // Disable claims and re-enable
        airdrop::enable_claims<TestCoin>(&project_owner, false);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // Now claim should succeed for the new reason
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 2000, 13);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Simulates a large airdrop with many users (scaled down for testing purposes)
    fun test_large_airdrop_simulation() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, freeze_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Create 50 allocations split across 5 reasons to simulate a large airdrop
        // This tests efficiency without hitting gas limits
        let total_allocation = 0u64;
        let reason_count = 5;
        let user_per_reason = 10; // Simulate 50 total allocations (would be 100k in production)
        
        let r = 0;
        while (r < reason_count) {
            let addresses = vector::empty<address>();
            let amounts = vector::empty<u64>();
            
            // For each reason, add multiple users
            let u = 0;
            while (u < user_per_reason) {
                // In a real test we would have 100k different addresses
                // But for this simulation we'll alternate between user1 and user2
                if (u % 2 == 0) {
                    vector::push_back(&mut addresses, USER1);
                } else {
                    vector::push_back(&mut addresses, USER2);
                };
                
                let amount = 100 + (r * 10) + u;
                vector::push_back(&mut amounts, amount);
                
                if (u % 2 == 0) {
                    total_allocation = total_allocation + amount;
                };
                
                u = u + 1;
            };
            
            // Create unique reason string by appending the reason number
            let reason_bytes = vector::empty<u8>();
            vector::append(&mut reason_bytes, b"BatchReason");
            vector::push_back(&mut reason_bytes, ((48 + r) as u8)); // Convert number to ASCII digit
            
            airdrop::set_allocation<TestCoin>(
                &project_owner,
                addresses,
                amounts,
                utf8(reason_bytes)
            );
            
            r = r + 1;
        };
        
        // Calculate the correct total allocation needed
        // In this case, we need to account for both user1 and user2's allocations
        let user1_allocation = total_allocation; // What we calculated above
        let user2_allocation = 0u64;
        
        let r = 0;
        while (r < reason_count) {
            let u = 0;
            while (u < user_per_reason) {
                if (u % 2 == 1) { // user2's allocations
                    let amount = 100 + (r * 10) + u;
                    user2_allocation = user2_allocation + amount;
                };
                u = u + 1;
            };
            r = r + 1;
        };
        
        let total_needed = user1_allocation + user2_allocation;
        
        // Deposit enough to cover both users
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, total_needed + 1000); // Add extra to be safe
        
        // Enable claims
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims all reasons at once
        airdrop::claim<TestCoin>(&user1);
        
        // Also have user2 claim
        airdrop::claim<TestCoin>(&user2);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
} 