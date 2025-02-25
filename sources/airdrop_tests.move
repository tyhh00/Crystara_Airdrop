#[test_only]
module projectOwnerAdr::airdrop_tests {
    use std::string::{String, utf8};
    use std::signer;
    use std::vector;
    use supra_framework::coin::{Self, BurnCapability, MintCapability};
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
    ): (BurnCapability<TestCoin>, MintCapability<TestCoin>) {
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
        
        (burn_cap, mint_cap)
    }
    
    #[test]
    /// Test basic initialization of the airdrop module
    fun test_initialize() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        
        // Initialize airdrop
        airdrop::initialize<TestCoin>(&project_owner);
        
        // Check that claims are initially disabled
        assert!(!airdrop::is_claims_enabled<TestCoin>(), 0);
        
        // Check that total allocation is initially 0
        assert!(airdrop::get_total_allocation<TestCoin>() == 0, 1);
        
        // Check that airdrop balance is initially 0
        assert!(airdrop::get_airdrop_balance<TestCoin>() == 0, 2);
    }
    
    #[test]
    /// Test setting and overriding allocations
    fun test_set_allocation() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Set initial allocation
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        vector::push_back(&mut addresses, USER2);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        vector::push_back(&mut amounts, 2000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"First Airdrop")
        );
        
        // Check total allocation
        assert!(airdrop::get_total_allocation<TestCoin>() == 3000, 3);
        
        // Now override the allocation with new amounts
        let addresses2 = vector::empty<address>();
        vector::push_back(&mut addresses2, USER1);
        vector::push_back(&mut addresses2, USER2);
        
        let amounts2 = vector::empty<u64>();
        vector::push_back(&mut amounts2, 1500);
        vector::push_back(&mut amounts2, 2500);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses2,
            amounts2,
            utf8(b"First Airdrop")  // Same reason, should override
        );
        
        // Check total allocation (should be updated)
        assert!(airdrop::get_total_allocation<TestCoin>() == 4000, 4);
        
        // Add another reason
        let addresses3 = vector::empty<address>();
        vector::push_back(&mut addresses3, USER1);
        
        let amounts3 = vector::empty<u64>();
        vector::push_back(&mut amounts3, 3000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses3,
            amounts3,
            utf8(b"Second Airdrop")  // New reason, should add
        );
        
        // Check total allocation (should include both reasons)
        assert!(airdrop::get_total_allocation<TestCoin>() == 7000, 5);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test depositing to airdrop and enabling claims
    fun test_deposit_and_enable() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Set allocation
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        vector::push_back(&mut addresses, USER2);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        vector::push_back(&mut amounts, 2000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Test Airdrop")
        );
        
        // Try to enable claims (should fail without deposit)
        let failed = false;
        if (!failed) {
            airdrop::enable_claims<TestCoin>(&project_owner, true);
            failed = true;  // Should not reach here
        };
        assert!(!failed, 6);
        
        // Deposit less than required and try to enable (should fail)
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 2000);
        
        failed = false;
        if (!failed) {
            airdrop::enable_claims<TestCoin>(&project_owner, true);
            failed = true;  // Should not reach here
        };
        assert!(!failed, 7);
        
        // Deposit remaining amount and enable claims (should succeed)
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 1000);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // Check that claims are enabled
        assert!(airdrop::is_claims_enabled<TestCoin>(), 8);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test basic claiming
    fun test_basic_claim() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Set allocation
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        vector::push_back(&mut addresses, USER2);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        vector::push_back(&mut amounts, 2000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Test Airdrop")
        );
        
        // Deposit and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 3000);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 9);
        
        // User2 claims
        airdrop::claim<TestCoin>(&user2);
        assert!(coin::balance<TestCoin>(USER2) == 2000, 10);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test that a user can't claim twice for the same reason
    fun test_prevent_double_claim() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Set allocation
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Test Airdrop")
        );
        
        // Deposit and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 1000);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 11);
        
        // User1 tries to claim again (should not get more tokens)
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 12);  // Balance should not increase
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test that user can claim from a new reason after claiming from old ones
    fun test_claim_new_reasons() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Set first allocation
        let addresses1 = vector::empty<address>();
        vector::push_back(&mut addresses1, USER1);
        
        let amounts1 = vector::empty<u64>();
        vector::push_back(&mut amounts1, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses1,
            amounts1,
            utf8(b"First Reason")
        );
        
        // Deposit and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 3000);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims first reason
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 13);
        
        // Set second allocation
        let addresses2 = vector::empty<address>();
        vector::push_back(&mut addresses2, USER1);
        
        let amounts2 = vector::empty<u64>();
        vector::push_back(&mut amounts2, 2000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses2,
            amounts2,
            utf8(b"Second Reason")
        );
        
        // User1 claims second reason
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 3000, 14);  // Should get additional 2000
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test that modifying an allocation after a user has claimed doesn't allow for double claims
    fun test_modify_after_claim() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Set first allocation
        let addresses1 = vector::empty<address>();
        vector::push_back(&mut addresses1, USER1);
        
        let amounts1 = vector::empty<u64>();
        vector::push_back(&mut amounts1, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses1,
            amounts1,
            utf8(b"Test Reason")
        );
        
        // Deposit and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 5000);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 15);
        
        // Now modify the allocation for the same reason
        let addresses2 = vector::empty<address>();
        vector::push_back(&mut addresses2, USER1);
        
        let amounts2 = vector::empty<u64>();
        vector::push_back(&mut amounts2, 2000);  // Increased amount
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses2,
            amounts2,
            utf8(b"Test Reason")  // Same reason as before
        );
        
        // User1 tries to claim again (should not get more tokens)
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 16);  // Balance should not increase
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test claiming all reasons at once
    fun test_claim_multiple_reasons() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Set multiple allocations with different reasons
        let reasons = vector[utf8(b"Reason1"), utf8(b"Reason2"), utf8(b"Reason3")];
        let amounts = vector[1000u64, 2000u64, 3000u64];
        
        let i = 0;
        while (i < 3) {
            let addr = vector::empty<address>();
            vector::push_back(&mut addr, USER1);
            
            let amt = vector::empty<u64>();
            vector::push_back(&mut amt, *vector::borrow(&amounts, i));
            
            airdrop::set_allocation<TestCoin>(
                &project_owner,
                addr,
                amt,
                *vector::borrow(&reasons, i)
            );
            
            i = i + 1;
        };
        
        // Deposit and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 6000);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims all at once
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 6000, 17);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test for handling missing allocations properly
    fun test_no_allocation() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Set allocation only for user1
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"First Airdrop")
        );
        
        // Deposit and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 1000);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User2 tries to claim (should not change balance)
        airdrop::claim<TestCoin>(&user2);
        assert!(coin::balance<TestCoin>(USER2) == 0, 18);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test handling a large number of allocations for a single user
    fun test_many_allocations_for_user() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Create 10 different allocations for user1
        let total_amount = 0u64;
        let i = 0;
        while (i < 10) {
            let addr = vector::empty<address>();
            vector::push_back(&mut addr, USER1);
            
            let amount = (i + 1) * 500; // Different amounts
            total_amount = total_amount + amount;
            
            let amt = vector::empty<u64>();
            vector::push_back(&mut amt, amount);
            
            let reason = utf8(b"Reason");
            let reason_str = std::string::append(&reason, utf8(std::bcs::to_bytes(&i)));
            
            airdrop::set_allocation<TestCoin>(
                &project_owner,
                addr,
                amt,
                reason_str
            );
            
            i = i + 1;
        };
        
        // Deposit and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, total_amount);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims all reasons at once
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == total_amount, 19);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Simulates a large airdrop with many users (scaled down for testing purposes)
    fun test_large_airdrop_simulation() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
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
            
            let reason = utf8(b"BatchReason");
            let reason_str = std::string::append(&reason, utf8(std::bcs::to_bytes(&r)));
            
            airdrop::set_allocation<TestCoin>(
                &project_owner,
                addresses,
                amounts,
                reason_str
            );
            
            r = r + 1;
        };
        
        // Deposit and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, total_allocation * 2); // Double to cover both users
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims all reasons at once
        airdrop::claim<TestCoin>(&user1);
        
        // To verify gas usage, we would observe the transaction costs in a real environment
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
} 