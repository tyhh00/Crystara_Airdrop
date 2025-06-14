# Airdrop Module with Unit Tests for Supra Blockchain
Hey there developers, this is a module built for Crystara to handle our incentivised testnet here on Supra. Feel free to fork and adapt these modules to your own likings for your distributed reward events.

# Function Signatures

### Initialize the module
public entry fun initialize<CoinType>(owner: &signer)

### Set allocations for a vector of users with a corresponding vector of amounts. All references to coin amounts are in quants. Cannot be set while claims are on-going
public entry fun set_allocation_v2<CoinType>(owner: &signer, recipients: vector<address>, amounts: vector<u64>, reason: vector<u8>)
public entry fun set_allocation<CoinType>(owner: &signer, recipients: vector<address>, amounts: vector<u64>, reason: String)

### Creator Authorized Route to deposit funds into the airdrop. Claims have to be disabled to deposit to prevent unintended claims.
public entry fun deposit_to_airdrop<CoinType>(owner: &signer, amount: u64)

### Claims can only be enabled if sufficient creator funds exist in the rewards pool for all unclaimed allocations. If no error pops up it means enabling was successful, and your users can start claiming their distributions
public entry fun enable_claims<CoinType>(owner: &signer, enable: bool)

### User public facing function to claim their rewards
public entry fun claim<CoinType>(recipient: &signer)

### Creator's balance that has been deposited into the airdrop fund.
#[view]
public fun get_airdrop_balance<CoinType>(): u64

### Get an individual user's allocations. This function only reflects unclaimed allocation reasons
#[view]
public fun get_user_allocations<CoinType>(user: address): (vector<String>, vector<u64>)

### Get claim status
#[view]
public fun is_claims_enabled<CoinType>(): bool

### Get total allocations that will be distributed when claims are active
#[view]
public fun get_total_allocation<CoinType>(): u64

### Get total amount of allocations unclaimed by users who can already claim their tokens.
#[view]
public fun get_total_unclaimed_allocation<CoinType>(): u64

### Get an individual user's allocations including claimed status. This function reflects all claimed and unclaimed allocation reasons
#[view]
public fun get_all_user_allocations<CoinType>(user: address): (vector<String>, vector<u64>, vector<bool>)

fun calculate_total_allocation<CoinType>(): u64
fun calculate_total_unclaimed_allocation<CoinType>(): u64
fun get_unclaimed_allocations<CoinType>(user: address): (vector<String>, vector<u64>)
