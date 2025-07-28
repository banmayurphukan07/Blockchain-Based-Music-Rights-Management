// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Blockchain-Based Music Rights Management
 * @dev Smart contract for managing music rights, royalty distribution, and licensing
 * @author Music Rights Management Team
 */
contract Project {
    
    // Struct to represent a music track with rights information
    struct MusicTrack {
        uint256 id;
        string title;
        string artist;
        address owner;
        uint256 totalRoyalties;
        uint256 streamCount;
        bool isActive;
        uint256 createdAt;
    }
    
    // Struct to represent rights holders and their ownership percentage
    struct RightsHolder {
        address holder;
        uint256 percentage; // Percentage out of 100 (e.g., 60 for 60%)
        string role; // "artist", "producer", "songwriter", "label", etc.
    }
    
    // Struct for licensing agreements
    struct License {
        uint256 trackId;
        address licensee;
        uint256 fee;
        uint256 startTime;
        uint256 endTime;
        string licenseType; // "streaming", "commercial", "sync", "performance"
        bool isActive;
    }
    
    // State variables
    uint256 private trackCounter;
    uint256 private licenseCounter;
    
    // Mappings
    mapping(uint256 => MusicTrack) public tracks;
    mapping(uint256 => RightsHolder[]) public trackRightsHolders;
    mapping(uint256 => License) public licenses;
    mapping(address => uint256[]) public artistTracks;
    mapping(uint256 => uint256[]) public trackLicenses;
    
    // Events
    event TrackRegistered(uint256 indexed trackId, string title, address indexed owner);
    event RoyaltiesDistributed(uint256 indexed trackId, uint256 totalAmount, uint256 timestamp);
    event LicenseCreated(uint256 indexed licenseId, uint256 indexed trackId, address indexed licensee, uint256 fee);
    event StreamRecorded(uint256 indexed trackId, uint256 newStreamCount);
    
    // Modifiers
    modifier trackExists(uint256 _trackId) {
        require(_trackId < trackCounter, "Track does not exist");
        _;
    }
    
    modifier onlyTrackOwner(uint256 _trackId) {
        require(tracks[_trackId].owner == msg.sender, "Only track owner can perform this action");
        _;
    }
    
    /**
     * @dev Core Function 1: Register a new music track with multiple rights holders
     * @param _title The title of the music track
     * @param _artist The artist/band name
     * @param _rightsHolders Array of rights holders with their percentages and roles
     * @return trackId The unique identifier for the registered track
     */
    function registerTrack(
        string memory _title,
        string memory _artist,
        RightsHolder[] memory _rightsHolders
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Track title cannot be empty");
        require(bytes(_artist).length > 0, "Artist name cannot be empty");
        require(_rightsHolders.length > 0, "Must have at least one rights holder");
        
        // Validate that total percentage equals 100%
        uint256 totalPercentage = 0;
        for (uint256 i = 0; i < _rightsHolders.length; i++) {
            require(_rightsHolders[i].holder != address(0), "Invalid rights holder address");
            require(_rightsHolders[i].percentage > 0, "Rights holder percentage must be greater than 0");
            totalPercentage += _rightsHolders[i].percentage;
        }
        require(totalPercentage == 100, "Total rights holder percentage must equal 100%");
        
        uint256 trackId = trackCounter++;
        
        // Create and store the track
        tracks[trackId] = MusicTrack({
            id: trackId,
            title: _title,
            artist: _artist,
            owner: msg.sender,
            totalRoyalties: 0,
            streamCount: 0,
            isActive: true,
            createdAt: block.timestamp
        });
        
        // Store rights holders for this track
        for (uint256 i = 0; i < _rightsHolders.length; i++) {
            trackRightsHolders[trackId].push(_rightsHolders[i]);
        }
        
        // Add track to artist's track list
        artistTracks[msg.sender].push(trackId);
        
        emit TrackRegistered(trackId, _title, msg.sender);
        
        return trackId;
    }
    
    /**
     * @dev Core Function 2: Distribute royalties to all rights holders based on their ownership percentage
     * @param _trackId The ID of the track for which royalties are being distributed
     */
    function distributeRoyalties(uint256 _trackId) 
        external 
        payable 
        trackExists(_trackId) 
    {
        require(msg.value > 0, "Royalty amount must be greater than 0");
        require(tracks[_trackId].isActive, "Track is not active");
        
        MusicTrack storage track = tracks[_trackId];
        RightsHolder[] memory rightsHolders = trackRightsHolders[_trackId];
        
        track.totalRoyalties += msg.value;
        
        // Distribute royalties to each rights holder based on their percentage
        for (uint256 i = 0; i < rightsHolders.length; i++) {
            uint256 royaltyShare = (msg.value * rightsHolders[i].percentage) / 100;
            
            if (royaltyShare > 0) {
                // Transfer royalty share to rights holder
                (bool success, ) = rightsHolders[i].holder.call{value: royaltyShare}("");
                require(success, "Royalty transfer failed");
            }
        }
        
        emit RoyaltiesDistributed(_trackId, msg.value, block.timestamp);
    }
    
    /**
     * @dev Core Function 3: Create a licensing agreement for a music track
     * @param _trackId The ID of the track to be licensed
     * @param _licensee The address of the party obtaining the license
     * @param _duration Duration of the license in seconds
     * @param _licenseType Type of license (streaming, commercial, sync, etc.)
     * @return licenseId The unique identifier for the created license
     */
    function createLicense(
        uint256 _trackId,
        address _licensee,
        uint256 _duration,
        string memory _licenseType
    ) 
        external 
        payable 
        trackExists(_trackId) 
        onlyTrackOwner(_trackId) 
        returns (uint256) 
    {
        require(_licensee != address(0), "Invalid licensee address");
        require(_duration > 0, "License duration must be greater than 0");
        require(msg.value > 0, "License fee must be greater than 0");
        require(tracks[_trackId].isActive, "Track is not active");
        
        uint256 licenseId = licenseCounter++;
        
        // Create the license
        licenses[licenseId] = License({
            trackId: _trackId,
            licensee: _licensee,
            fee: msg.value,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            licenseType: _licenseType,
            isActive: true
        });
        
        // Add license to track's license list
        trackLicenses[_trackId].push(licenseId);
        
        // Distribute license fee as royalties to rights holders
        this.distributeRoyalties{value: msg.value}(_trackId);
        
        emit LicenseCreated(licenseId, _trackId, _licensee, msg.value);
        
        return licenseId;
    }
    
    // Additional utility functions
    
    /**
     * @dev Record a stream/play for a track
     * @param _trackId The ID of the track being streamed
     */
    function recordStream(uint256 _trackId) external trackExists(_trackId) {
        require(tracks[_trackId].isActive, "Track is not active");
        
        tracks[_trackId].streamCount++;
        emit StreamRecorded(_trackId, tracks[_trackId].streamCount);
    }
    
    /**
     * @dev Get track information
     * @param _trackId The ID of the track
     * @return track The track information
     */
    function getTrack(uint256 _trackId) 
        external 
        view 
        trackExists(_trackId) 
        returns (MusicTrack memory) 
    {
        return tracks[_trackId];
    }
    
    /**
     * @dev Get rights holders for a specific track
     * @param _trackId The ID of the track
     * @return rightsHolders Array of rights holders
     */
    function getTrackRightsHolders(uint256 _trackId) 
        external 
        view 
        trackExists(_trackId) 
        returns (RightsHolder[] memory) 
    {
        return trackRightsHolders[_trackId];
    }
    
    /**
     * @dev Get all tracks registered by an artist
     * @param _artist The address of the artist
     * @return trackIds Array of track IDs
     */
    function getArtistTracks(address _artist) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return artistTracks[_artist];
    }
    
    /**
     * @dev Check if a license is currently valid
     * @param _licenseId The ID of the license
     * @return isValid Whether the license is currently valid
     */
    function isLicenseValid(uint256 _licenseId) 
        external 
        view 
        returns (bool) 
    {
        require(_licenseId < licenseCounter, "License does not exist");
        License memory license = licenses[_licenseId];
        return license.isActive && block.timestamp <= license.endTime;
    }
    
    /**
     * @dev Get license information
     * @param _licenseId The ID of the license
     * @return license The license information
     */
    function getLicense(uint256 _licenseId) 
        external 
        view 
        returns (License memory) 
    {
        require(_licenseId < licenseCounter, "License does not exist");
        return licenses[_licenseId];
    }
    
    /**
     * @dev Toggle track active status
     * @param _trackId The ID of the track
     */
    function toggleTrackStatus(uint256 _trackId) 
        external 
        trackExists(_trackId) 
        onlyTrackOwner(_trackId) 
    {
        tracks[_trackId].isActive = !tracks[_trackId].isActive;
    }
    
    /**
     * @dev Get total number of registered tracks
     * @return count Total number of tracks
     */
    function getTotalTracks() external view returns (uint256) {
        return trackCounter;
    }
    
    /**
     * @dev Get total number of licenses created
     * @return count Total number of licenses
     */
    function getTotalLicenses() external view returns (uint256) {
        return licenseCounter;
    }
}
