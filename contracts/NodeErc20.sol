pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../libraries/Roles.sol";

contract NODE is 
    Initializable, 
    ERC20BurnableUpgradeable, 
    ERC20VotesUpgradeable, 
    ERC20PermitUpgradeable, 
    AccessControlUpgradeable, 
    UUPSUpgradeable 
{
    uint256 public constant MAX_SUPPLY = 1000_000_000 * 10 ** 18;
    uint256 public constant MIN_MINT_INTERVAL = 1 days;
    uint256 public constant MAX_MINT_BUFFER = 1 hours;

    uint256 public  maxMintAmount;
    uint256 public mintBuffer;
    uint256 public nextMint;
    
    string private constant NAME = "NodeOps";
    string private constant SYMBOL = "NODE";

    uint256[50] private __gap;

    /* ========== ERRORS ========== */

    error MintTimestampNotElapsed(uint256 currentTimestamp, uint256 nextMintTimestamp);
    error MaxSupplyExceeded();
    error MintCapExceeded();
    error MaxMintBufferExceeded();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // Initialize the token with the name, symbol, and operational multisig
    function initialize(address multisig) public initializer {
        __ERC20_init(NAME, SYMBOL);
        __ERC20Votes_init();
        __ERC20Burnable_init();
        __ERC20Permit_init(NAME); 
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, multisig);
        _setRoleAdmin(Roles.MINTER_ROLE, DEFAULT_ADMIN_ROLE);

        mintBuffer = MAX_MINT_BUFFER;
    }

    // UUPS upgradeability authorization function (only callable by the owner)
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // Bypass mint restrictions, only callable by the multisig
    function permissionedMint(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (totalSupply() + amount > MAX_SUPPLY) {
            revert MaxSupplyExceeded();
        }
        _mint(to, amount);
    }

    function mint(address to, uint256 amount) external onlyRole(Roles.MINTER_ROLE) {
        if (totalSupply() + amount > MAX_SUPPLY) {
            revert MaxSupplyExceeded();
        }

        uint256 allowedMintAmount;
        
        // Handle minting time checks and calculate allowed mint amount
        if (nextMint > 0) {
            if (block.timestamp < nextMint - mintBuffer) {
                revert MintTimestampNotElapsed(block.timestamp, nextMint);
            }
            
            // Calculate days elapsed since the last scheduled mint
            uint256 timeElapsed = block.timestamp - (nextMint - MIN_MINT_INTERVAL);
            uint256 daysElapsed = timeElapsed / MIN_MINT_INTERVAL;
            
            // Ensure at least 1 day multiplier
            if (daysElapsed == 0) {
                daysElapsed = 1;
            }
            
            allowedMintAmount = maxMintAmount * daysElapsed;
            nextMint += MIN_MINT_INTERVAL; // Increment for the next mint
        } else {
            // First mint initialization - allow maxMintAmount
            allowedMintAmount = maxMintAmount;
            nextMint = block.timestamp + MIN_MINT_INTERVAL;
        }

        if (amount > allowedMintAmount) {
            amount = allowedMintAmount;
        }

        _mint(to, amount);
    }

    function setMaxMintAmount(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxMintAmount = amount;
    }


    function setMintBuffer(uint256 buffer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (buffer > MAX_MINT_BUFFER) {
            revert MaxMintBufferExceeded();
        }
        mintBuffer = buffer;
    }

    // Burn function callable by any token holder
    function burn(uint256 amount) public override(ERC20BurnableUpgradeable) {
        _burn(msg.sender, amount);
    }

    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return ERC20PermitUpgradeable.nonces(owner);
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._update(from, to, amount);
    }
}