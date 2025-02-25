module projectOwnerAdr::airdrop {
    use std::string::{String, Self};
    use std::signer;
    use std::vector;
    use std::error;
    use supra_framework::coin::{Self};
    use supra_framework::account;
    use supra_framework::event;

    // Error codes
    const ENOT_OWNER: u64 = 1;
    const EVECTOR_LENGTH_MISMATCH: u64 = 2;
    const EINSUFFICIENT_FUNDS: u64 = 3;
    const ECLAIMS_NOT_ENABLED: u64 = 4;
    const ENO_ALLOCATION: u64 = 5;
    const EALREADY_INITIALIZED: u64 = 6;
    const ENOT_INITIALIZED: u64 = 7;
    const ECLAIMS_MUST_BE_DISABLED: u64 = 8;

    // Represents a single airdrop allocation
    struct Allocation has store, drop {
        addresses: vector<address>,
        amounts: vector<u64>,
    }

    // Main airdrop storage with allocations grouped by reason
    struct AirdropStore<phantom CoinType> has key {
        allocations: vector<AllocationWithReason>,
        claims_enabled: bool,
        resource_signer_cap: account::SignerCapability
    }

    // Allocation with a specific reason
    struct AllocationWithReason has store, drop {
        reason: String,
        allocation: Allocation,
    }

    // Tracks which reasons a user has claimed
    struct ClaimRecord<phantom CoinType> has key {
        claimed_reasons: vector<String>
    }

    // Events
    #[event]
    struct AllocationSetEvent has drop, store {
        reason: String,
        total_amount: u64,
        recipient_count: u64
    }

    #[event]
    struct ClaimEvent has drop, store {
        recipient: address,
        reason: String,
        amount: u64
    }

    #[event]
    struct DepositEvent has drop, store {
        amount: u64
    }

    #[event]
    struct ClaimsEnabledEvent has drop, store {
        enabled: bool
    }

    const AIRDROP_SEED: vector<u8> = b"SUPRA_AIRDROP_RESOURCE";

    // Initialize the airdrop module with a resource account to hold funds
    public entry fun initialize<CoinType>(owner: &signer) {
        let owner_addr = signer::address_of(owner);
        assert!(owner_addr == @projectOwnerAdr, error::permission_denied(ENOT_OWNER));
        assert!(!exists<AirdropStore<CoinType>>(owner_addr), error::already_exists(EALREADY_INITIALIZED));

        // Create resource account for storing funds
        let seed = AIRDROP_SEED;
        let (resource_signer, resource_signer_cap) = account::create_resource_account(owner, seed);
        
        // Register the resource account to receive the coin type
        if (!coin::is_account_registered<CoinType>(signer::address_of(&resource_signer))) {
            coin::register<CoinType>(&resource_signer);
        };

        move_to(owner, AirdropStore<CoinType> {
            allocations: vector::empty(),
            claims_enabled: false,
            resource_signer_cap
        });
    }

    public entry fun set_allocation_v2<CoinType>(
        owner: &signer,
        recipients: vector<address>,
        amounts: vector<u64>,
        reason: vector<u8>
    ) acquires AirdropStore {
        set_allocation<CoinType>(owner, recipients, amounts, string::utf8(reason));
    }

    // Set an airdrop allocation for a specific reason
    // If the reason already exists, it will be updated with new addresses and amounts
    public entry fun set_allocation<CoinType>(
        owner: &signer,
        recipients: vector<address>,
        amounts: vector<u64>,
        reason: String
    ) acquires AirdropStore {
        let owner_addr = signer::address_of(owner);
        assert!(owner_addr == @projectOwnerAdr, error::permission_denied(ENOT_OWNER));
        assert!(vector::length(&recipients) == vector::length(&amounts), error::invalid_argument(EVECTOR_LENGTH_MISMATCH));
        assert!(exists<AirdropStore<CoinType>>(@projectOwnerAdr), error::not_found(ENOT_INITIALIZED));


        let airdrop_store = borrow_global_mut<AirdropStore<CoinType>>(@projectOwnerAdr);
        assert!(!airdrop_store.claims_enabled, error::invalid_state(ECLAIMS_MUST_BE_DISABLED));
        
        // Calculate total amount for the allocation
        let total_amount = 0u64;
        let j = 0;
        let amounts_len = vector::length(&amounts);
        while (j < amounts_len) {
            total_amount = total_amount + *vector::borrow(&amounts, j);
            j = j + 1;
        };

        // Check if reason already exists and update or add
        let allocations_ref = &mut airdrop_store.allocations;
        let i = 0;
        let len = vector::length(allocations_ref);
        let found_idx = len; // Default to end (not found)
        
        while (i < len) {
            let allocation_with_reason = vector::borrow(allocations_ref, i);
            if (allocation_with_reason.reason == reason) {
                found_idx = i;
                break
            };
            i = i + 1;
        };

        // If reason exists, update it; otherwise add new allocation
        if (found_idx < len) {
            let allocation_with_reason = vector::borrow_mut(allocations_ref, found_idx);
            allocation_with_reason.allocation = Allocation {
                addresses: recipients,
                amounts: amounts,
            };
        } else {
            vector::push_back(allocations_ref, AllocationWithReason {
                reason,
                allocation: Allocation {
                    addresses: recipients,
                    amounts: amounts,
                }
            });
        };

        // Emit event
        event::emit(AllocationSetEvent {
            reason,
            total_amount,
            recipient_count: vector::length(&recipients)
        });
    }

    // Deposit funds to the airdrop
    public entry fun deposit_to_airdrop<CoinType>(owner: &signer, amount: u64) acquires AirdropStore {
        let owner_addr = signer::address_of(owner);
        assert!(owner_addr == @projectOwnerAdr, error::permission_denied(ENOT_OWNER));
        assert!(exists<AirdropStore<CoinType>>(@projectOwnerAdr), error::not_found(ENOT_INITIALIZED));
        
        let airdrop_store = borrow_global<AirdropStore<CoinType>>(@projectOwnerAdr);
        let resource_signer = account::create_signer_with_capability(&airdrop_store.resource_signer_cap);
        let resource_addr = signer::address_of(&resource_signer);
        
        coin::transfer<CoinType>(owner, resource_addr, amount);
        
        event::emit(DepositEvent { amount });
    }

    // Calculate total allocation amount across all reasons
    fun calculate_total_allocation<CoinType>(): u64 acquires AirdropStore {
        let airdrop_store = borrow_global<AirdropStore<CoinType>>(@projectOwnerAdr);
        let total = 0u64;
        
        let i = 0;
        let allocations_len = vector::length(&airdrop_store.allocations);
        
        while (i < allocations_len) {
            let allocation_with_reason = vector::borrow(&airdrop_store.allocations, i);
            let amounts = &allocation_with_reason.allocation.amounts;
            let j = 0;
            let amounts_len = vector::length(amounts);
            
            while (j < amounts_len) {
                total = total + *vector::borrow(amounts, j);
                j = j + 1;
            };
            
            i = i + 1;
        };
        
        total
    }

    // Calculate total unclaimed allocation amount across all reasons
    fun calculate_total_unclaimed_allocation<CoinType>(): u64 acquires AirdropStore, ClaimRecord {
        let airdrop_store = borrow_global<AirdropStore<CoinType>>(@projectOwnerAdr);
        let total = 0u64;
        
        let i = 0;
        let allocations_len = vector::length(&airdrop_store.allocations);
        
        while (i < allocations_len) {
            let allocation_with_reason = vector::borrow(&airdrop_store.allocations, i);
            let reason = &allocation_with_reason.reason;
            let addresses = &allocation_with_reason.allocation.addresses;
            let amounts = &allocation_with_reason.allocation.amounts;
            
            let j = 0;
            let addresses_len = vector::length(addresses);
            
            while (j < addresses_len) {
                let addr = *vector::borrow(addresses, j);
                let amount = *vector::borrow(amounts, j);
                
                // Check if this user has already claimed this reason
                let already_claimed = false;
                
                if (exists<ClaimRecord<CoinType>>(addr)) {
                    let claim_record = borrow_global<ClaimRecord<CoinType>>(addr);
                    let claimed_reasons = &claim_record.claimed_reasons;
                    
                    let k = 0;
                    let claimed_len = vector::length(claimed_reasons);
                    
                    while (k < claimed_len && !already_claimed) {
                        if (*reason == *vector::borrow(claimed_reasons, k)) {
                            already_claimed = true;
                        };
                        k = k + 1;
                    };
                };
                
                // If not claimed, add to total
                if (!already_claimed) {
                    total = total + amount;
                };
                
                j = j + 1;
            };
            
            i = i + 1;
        };
        
        total
    }

    // Enable or disable claims
    // Claims can only be enabled if there are sufficient funds to cover all unclaimed allocations
    public entry fun enable_claims<CoinType>(owner: &signer, enable: bool) acquires AirdropStore, ClaimRecord {
        let owner_addr = signer::address_of(owner);
        assert!(owner_addr == @projectOwnerAdr, error::permission_denied(ENOT_OWNER));
        assert!(exists<AirdropStore<CoinType>>(@projectOwnerAdr), error::not_found(ENOT_INITIALIZED));
        
        if (enable) {
            // Calculate total amount needed for all unclaimed allocations - do this BEFORE borrowing
            let total_needed = calculate_total_unclaimed_allocation<CoinType>();
            
            // Now we can borrow
            let airdrop_store = borrow_global_mut<AirdropStore<CoinType>>(@projectOwnerAdr);
            
            // Get current balance
            let resource_signer = account::create_signer_with_capability(&airdrop_store.resource_signer_cap);
            let balance = coin::balance<CoinType>(signer::address_of(&resource_signer));
            
            // Ensure there are enough funds
            assert!(balance >= total_needed, error::invalid_state(EINSUFFICIENT_FUNDS));
            
            airdrop_store.claims_enabled = true;
        } else {
            // Just disable claims, no calculations needed
            let airdrop_store = borrow_global_mut<AirdropStore<CoinType>>(@projectOwnerAdr);
            airdrop_store.claims_enabled = false;
        };
        
        event::emit(ClaimsEnabledEvent { enabled: enable });
    }

    // Find all unclaimed allocations for a user
    fun get_unclaimed_allocations<CoinType>(user: address): (vector<String>, vector<u64>) acquires AirdropStore, ClaimRecord {
        let reasons = vector::empty<String>();
        let amounts = vector::empty<u64>();
        
        let airdrop_store = borrow_global<AirdropStore<CoinType>>(@projectOwnerAdr);
        
        // Get already claimed reasons
        let claimed_reasons = if (exists<ClaimRecord<CoinType>>(user)) {
            &borrow_global<ClaimRecord<CoinType>>(user).claimed_reasons
        } else {
            &vector::empty<String>()
        };
        
        // Check each allocation for unclaimed amounts
        let i = 0;
        let allocations_len = vector::length(&airdrop_store.allocations);
        
        while (i < allocations_len) {
            let allocation_with_reason = vector::borrow(&airdrop_store.allocations, i);
            let reason = &allocation_with_reason.reason;
            
            // Check if already claimed
            let already_claimed = false;
            let j = 0;
            let claimed_len = vector::length(claimed_reasons);
            
            while (j < claimed_len && !already_claimed) {
                if (*reason == *vector::borrow(claimed_reasons, j)) {
                    already_claimed = true;
                };
                j = j + 1;
            };
            
            if (!already_claimed) {
                // Find user in the allocation
                let addresses = &allocation_with_reason.allocation.addresses;
                let allocation_amounts = &allocation_with_reason.allocation.amounts;
                let addr_len = vector::length(addresses);
                let k = 0;
                
                while (k < addr_len) {
                    if (*vector::borrow(addresses, k) == user) {
                        let amount = *vector::borrow(allocation_amounts, k);
                        if (amount > 0) {
                            vector::push_back(&mut reasons, *reason);
                            vector::push_back(&mut amounts, amount);
                        };
                        break
                    };
                    k = k + 1;
                };
            };
            
            i = i + 1;
        };
        
        (reasons, amounts)
    }

    // Claim all available airdrops for a user
    public entry fun claim<CoinType>(recipient: &signer) acquires AirdropStore, ClaimRecord {
        let recipient_addr = signer::address_of(recipient);
        assert!(exists<AirdropStore<CoinType>>(@projectOwnerAdr), error::not_found(ENOT_INITIALIZED));
        
        // Check if claims are enabled first
        {
            let airdrop_store = borrow_global<AirdropStore<CoinType>>(@projectOwnerAdr);
            assert!(airdrop_store.claims_enabled, error::invalid_state(ECLAIMS_NOT_ENABLED));
        };
        
        // Get unclaimed allocations for this user
        let (reasons_to_claim, amounts_to_claim) = get_unclaimed_allocations<CoinType>(recipient_addr);
        let claims_count = vector::length(&reasons_to_claim);
        
        // Ensure there's something to claim
        assert!(claims_count > 0, error::not_found(ENO_ALLOCATION));
        
        // Initialize claim record if it doesn't exist
        if (!exists<ClaimRecord<CoinType>>(recipient_addr)) {
            move_to(recipient, ClaimRecord<CoinType> { claimed_reasons: vector::empty() });
        };
        
        // Process claims
        let claim_record = borrow_global_mut<ClaimRecord<CoinType>>(recipient_addr);
        
        // Get airdrop store and signer for transfer
        let airdrop_store = borrow_global<AirdropStore<CoinType>>(@projectOwnerAdr);
        let resource_signer = account::create_signer_with_capability(&airdrop_store.resource_signer_cap);
        let total_amount = 0u64;
        
        let i = 0;
        while (i < claims_count) {
            let reason = vector::borrow(&reasons_to_claim, i);
            let amount = *vector::borrow(&amounts_to_claim, i);
            
            // Track claimed amount
            total_amount = total_amount + amount;
            
            // Mark as claimed
            vector::push_back(&mut claim_record.claimed_reasons, *reason);
            
            // Emit event
            event::emit(ClaimEvent {
                recipient: recipient_addr,
                reason: *reason,
                amount
            });
            
            i = i + 1;
        };
        
        // Transfer the total amount in one transaction for gas efficiency
        if (total_amount > 0) {
            coin::transfer<CoinType>(&resource_signer, recipient_addr, total_amount);
        };
    }

    // Get the current balance of the airdrop
    #[view]
    public fun get_airdrop_balance<CoinType>(): u64 acquires AirdropStore {
        let airdrop_store = borrow_global<AirdropStore<CoinType>>(@projectOwnerAdr);
        let resource_signer = account::create_signer_with_capability(&airdrop_store.resource_signer_cap);
        coin::balance<CoinType>(signer::address_of(&resource_signer))
    }

    // Get all unclaimed allocations for a user
    #[view]
    public fun get_user_allocations<CoinType>(user: address): (vector<String>, vector<u64>) acquires AirdropStore, ClaimRecord {
        get_unclaimed_allocations<CoinType>(user)
    }

    // Check if claims are enabled
    #[view]
    public fun is_claims_enabled<CoinType>(): bool acquires AirdropStore {
        borrow_global<AirdropStore<CoinType>>(@projectOwnerAdr).claims_enabled
    }

    // Get the total amount allocated across all reasons
    #[view]
    public fun get_total_allocation<CoinType>(): u64 acquires AirdropStore {
        calculate_total_allocation<CoinType>()
    }

    // Get the total amount of unclaimed allocations
    #[view]
    public fun get_total_unclaimed_allocation<CoinType>(): u64 acquires AirdropStore, ClaimRecord {
        calculate_total_unclaimed_allocation<CoinType>()
    }

    // Get all allocations for a user (claimed and unclaimed) with claim status
        // Get all allocations for a user (claimed and unclaimed) with claim status
    #[view]
    public fun get_all_user_allocations<CoinType>(user: address): (vector<String>, vector<u64>, vector<bool>) acquires AirdropStore, ClaimRecord {
        // Get airdrop store
        let airdrop_store = borrow_global<AirdropStore<CoinType>>(@projectOwnerAdr);
        
        // Prepare return vectors
        let reasons = vector::empty<String>();
        let amounts = vector::empty<u64>();
        let claim_status = vector::empty<bool>(); // true = claimed, false = unclaimed
        
        // Get user claim record if it exists
        let has_claim_record = exists<ClaimRecord<CoinType>>(user);
        let claimed_reasons = vector::empty<String>();
        
        if (has_claim_record) {
            let claim_record = borrow_global<ClaimRecord<CoinType>>(user);
            claimed_reasons = *&claim_record.claimed_reasons;
        };
        
        // For each allocation, check if it includes the user
        let allocations_len = vector::length(&airdrop_store.allocations);
        let i = 0;
        
        while (i < allocations_len) {
            let allocation_with_reason = vector::borrow(&airdrop_store.allocations, i);
            let reason = &allocation_with_reason.reason;
            
            // Find user in the allocation
            let addresses = &allocation_with_reason.allocation.addresses;
            let allocation_amounts = &allocation_with_reason.allocation.amounts;
            let addr_len = vector::length(addresses);
            let j = 0;
            
            while (j < addr_len) {
                let addr = vector::borrow(addresses, j);
                
                if (*addr == user) {
                    let amount = vector::borrow(allocation_amounts, j);
                    
                    // Add to results
                    vector::push_back(&mut reasons, *reason);
                    vector::push_back(&mut amounts, *amount);
                    
                    // Check if this reason has been claimed
                    let is_claimed = false;
                    
                    if (has_claim_record) {
                        let k = 0;
                        let claimed_len = vector::length(&claimed_reasons);
                        
                        while (k < claimed_len) {
                            let claimed_reason = vector::borrow(&claimed_reasons, k);
                            if (*claimed_reason == *reason) {
                                is_claimed = true;
                                break
                            };
                            k = k + 1;
                        };
                    };
                    
                    vector::push_back(&mut claim_status, is_claimed);
                    break // Found the user for this allocation, move to next allocation
                };
                
                j = j + 1;
            };
            
            i = i + 1;
        };
        
        (reasons, amounts, claim_status)
    }
}
