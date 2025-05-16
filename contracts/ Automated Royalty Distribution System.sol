// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title RoyaltyDistribution
 * @dev Contract for distributing royalties to content creators based on sales of their assets
 */
contract RoyaltyDistribution {
    address public owner;
    
    struct Creator {
        address payable wallet;
        string name;
        bool isRegistered;
    }
    
    struct Asset {
        uint256 id;
        address creatorAddress;
        uint256 royaltyPercentage; // In basis points (e.g., 250 = 2.5%)
        uint256 totalSales;
        string assetURI;
        bool isActive;
    }
    
    mapping(address => Creator) public creators;
    mapping(uint256 => Asset) public assets;
    mapping(address => uint256[]) public creatorAssets;
    
    uint256 private nextAssetId = 1;
    
    event CreatorRegistered(address indexed creatorAddress, string name);
    event AssetRegistered(
        uint256 indexed assetId, 
        address indexed creatorAddress, 
        uint256 royaltyPercentage,
        string assetURI
    );
    event RoyaltyPaid(
        uint256 indexed assetId, 
        address indexed creatorAddress, 
        address indexed purchaser, 
        uint256 saleAmount, 
        uint256 royaltyAmount
    );
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyRegisteredCreator() {
        require(creators[msg.sender].isRegistered, "Creator not registered");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Register a new creator
     * @param _name Name of the creator
     */
    function registerCreator(string memory _name) external {
        require(!creators[msg.sender].isRegistered, "Creator already registered");
        
        creators[msg.sender] = Creator({
            wallet: payable(msg.sender),
            name: _name,
            isRegistered: true
        });
        
        emit CreatorRegistered(msg.sender, _name);
    }
    
    /**
     * @dev Register a new asset for royalty distribution
     * @param _royaltyPercentage Percentage of sales to be paid as royalty (in basis points)
     * @param _assetURI URI reference to the asset
     * @return The ID of the newly registered asset
     */
    function registerAsset(uint256 _royaltyPercentage, string memory _assetURI) 
        external 
        onlyRegisteredCreator 
        returns (uint256) 
    {
        require(_royaltyPercentage <= 5000, "Royalty percentage cannot exceed 50%");
        
        uint256 assetId = nextAssetId;
        nextAssetId++;
        
        assets[assetId] = Asset({
            id: assetId,
            creatorAddress: msg.sender,
            royaltyPercentage: _royaltyPercentage,
            totalSales: 0,
            assetURI: _assetURI,
            isActive: true
        });
        
        creatorAssets[msg.sender].push(assetId);
        
        emit AssetRegistered(assetId, msg.sender, _royaltyPercentage, _assetURI);
        
        return assetId;
    }
    
    /**
     * @dev Process a sale and distribute royalties
     * @param _assetId ID of the asset sold
     * @param _saleAmount Amount the asset was sold for
     */
    function processSale(uint256 _assetId, uint256 _saleAmount) external payable {
        Asset storage asset = assets[_assetId];
        require(asset.isActive, "Asset not active");
        require(msg.value > 0, "Must send payment with transaction");
        
        // Calculate royalty
        uint256 royaltyAmount = (_saleAmount * asset.royaltyPercentage) / 10000;
        
        // Transfer royalty to creator
        Creator storage creator = creators[asset.creatorAddress];
        require(creator.isRegistered, "Creator not registered");
        require(msg.value >= royaltyAmount, "Insufficient payment for royalty");
        
        // Update asset stats
        asset.totalSales += _saleAmount;
        
        // Transfer royalty to creator
        (bool sent, ) = creator.wallet.call{value: royaltyAmount}("");
        require(sent, "Failed to send royalty to creator");
        
        // Refund excess payment if any
        if (msg.value > royaltyAmount) {
            (bool refunded, ) = payable(msg.sender).call{value: msg.value - royaltyAmount}("");
            require(refunded, "Failed to refund excess payment");
        }
        
        emit RoyaltyPaid(
            _assetId, 
            asset.creatorAddress, 
            msg.sender, 
            _saleAmount, 
            royaltyAmount
        );
    }
    
    /**
     * @dev Get all assets registered by a specific creator
     * @param _creatorAddress Address of the creator
     * @return Array of asset IDs belonging to the creator
     */
    function getCreatorAssets(address _creatorAddress) external view returns (uint256[] memory) {
        return creatorAssets[_creatorAddress];
    }
    
    /**
     * @dev Toggle active status of an asset
     * @param _assetId ID of the asset to update
     */
    function toggleAssetStatus(uint256 _assetId) external {
        Asset storage asset = assets[_assetId];
        require(msg.sender == asset.creatorAddress || msg.sender == owner, "Not authorized");
        
        asset.isActive = !asset.isActive;
    }
}
