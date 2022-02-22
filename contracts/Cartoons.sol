import '@openzeppelin/contracts/access/Ownable.sol';
import './merkle/MerkleProof.sol';
import './interfaces/IERC20.sol';
import './ReentrancyGuard.sol';
import './ERC721A.sol';

pragma solidity ^0.8.6;

/*
    .----------------.  .----------------.  .----------------.  .----------------.  .----------------.  .----------------.  .-----------------. .----------------. 
    | .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. |
    | |     ______   | || |      __      | || |  _______     | || |  _________   | || |     ____     | || |     ____     | || | ____  _____  | || |    _______   | |
    | |   .' ___  |  | || |     /  \     | || | |_   __ \    | || | |  _   _  |  | || |   .'    `.   | || |   .'    `.   | || ||_   \|_   _| | || |   /  ___  |  | |
    | |  / .'   \_|  | || |    / /\ \    | || |   | |__) |   | || | |_/ | | \_|  | || |  /  .--.  \  | || |  /  .--.  \  | || |  |   \ | |   | || |  |  (__ \_|  | |
    | |  | |         | || |   / ____ \   | || |   |  __ /    | || |     | |      | || |  | |    | |  | || |  | |    | |  | || |  | |\ \| |   | || |   '.___`-.   | |
    | |  \ `.___.'\  | || | _/ /    \ \_ | || |  _| |  \ \_  | || |    _| |_     | || |  \  `--'  /  | || |  \  `--'  /  | || | _| |_\   |_  | || |  |`\____) |  | |
    | |   `._____.'  | || ||____|  |____|| || | |____| |___| | || |   |_____|    | || |   `.____.'   | || |   `.____.'   | || ||_____|\____| | || |  |_______.'  | |
    | |              | || |              | || |              | || |              | || |              | || |              | || |              | || |              | |
    | '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' |
    '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------'                                                                                                                                                      
*/
contract Cartoons is ERC721A, Ownable, ReentrancyGuard {
    using Strings for uint256;
    
    uint256 public rootMintAmt; // Mints allocated from whitelist mint for each whitelisted address
    uint256 public pubMintMaxPerTx = 1; // Max mint per transaction for public mint
    uint256 public MAX_SUPPLY = 7777;   // Max supply allowed to be minted
    uint256 public itemPrice = 0.07 ether;   // Mint price
    bytes32 public root; // Merkle root
    string public baseURI = '';  // Base URI for tokenURI
    bool public isWhitelistActive;  // Access modifier for whitelist mint function
    bool public isPublicMintActive; // Access modifier for public mint function

    constructor (bytes32 _root, uint256 _rootMintAmt) ERC721A("Cartoons", "TOONS") {
        root = _root;
        rootMintAmt = _rootMintAmt;

        // transferOwnership(address());    // Transfer ownership to team
    }

    /*
        Mint for Whitelisted Addresses - Reentrancy Guarded
        _proof - bytes32 array to verify hash of msg.sender(leaf) is contained in merkle tree
        _amt - uint256 specifies amount to mint (must be no greater than rootMintAmt)
    */
    function whitelistMint(bytes32[] calldata _proof, uint64 _amt) external payable nonReentrant {
        require(msg.sender == tx.origin, "Minting from Contract not Allowed");
        require(isWhitelistActive, "Cartoons Whitelist Mint Not Active");
        uint64 newClaimTotal = _getAux(msg.sender) + _amt;
        require(newClaimTotal <= rootMintAmt, "Requested Claim Amount Invalid");
        require(totalSupply() + _amt <= MAX_SUPPLY, "Mint Amount Exceeds Total Supply Cap");
        require(itemPrice * _amt == msg.value,  "Insufficient Payment");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_proof,root,leaf), "Invalid Proof/Root/Leaf");

        _setAux(msg.sender, newClaimTotal);

        _safeMint(msg.sender, _amt);
    }

    /*
        Public Mint - Reentrancy Guarded
        _amt - uint256 amount to mint
    */
    function publicMint(uint256 _amt) external payable nonReentrant {
        require(msg.sender == tx.origin, "Minting from Contract not Allowed");
        require(isPublicMintActive, "Cartoons Public Mint Not Active");
        require(_amt <= pubMintMaxPerTx, "Requested Mint Amount Exceeds Limit Per Tx");
        require(totalSupply() + _amt <= MAX_SUPPLY, "Mint Amount Exceeds Total Supply Cap");
        require(itemPrice * _amt == msg.value,  "Insufficient Payment");

        _safeMint(msg.sender, _amt);
    }

    /*
        SETTORS - onlyOwner access
    */

    /* 
        Access modifier for whitelist mint function
        _val - TRUE for active / FALSE for inactive mint
    */
    function setWhitelistMintActive(bool _val) external onlyOwner {
        isWhitelistActive = _val;
    }

    /* 
        Access modifier for public mint function
        _val - TRUE for active / FALSE for inactive mint
    */
    function setPublicMintActive(bool _val) external onlyOwner {
        isPublicMintActive = _val;
    }

    /*
        Plant new merkle root to replace whitelist
        _root - bytes32 value of new merkle root
        _amt - uint256 amount each whitelisted address can mint
    */

    function plantNewRoot(bytes32 _root, uint256 _amt) external onlyOwner {
        require(!isWhitelistActive, "Whitelist Minting Not Disabled");
        root = _root;
        rootMintAmt = _amt;
    }

    /*
        Sets new base URI for Cartoons NFT as _uri
        _uri - string value to be new base URI
    */
    function setBaseURI(string memory _uri) external onlyOwner {
        baseURI = _uri;
    }

    /*
        Sets new mint price
        _price - uint256 value to be new price
    */
    function setItemPrice(uint256 _price) external onlyOwner {
		itemPrice = _price;
	}

    /*
        Sets new total supply
        _amount - uint256 value to be new total supply
    */
    function setTotalSupply(uint256 _amount) external onlyOwner {
        require(_currentIndex > _amount, "Cannot change total supply lower than current total");
		MAX_SUPPLY = _amount;
	}

    /*
        Sets new max mint amount per transaction
        _amount - uint256 value to be new max mint amount per transaction
    */
    function setMaxMintPerTx(uint256 _amt) external onlyOwner {
		pubMintMaxPerTx = _amt;
	}

    /*
        GETTORS - view functions
    */

    /*
        Getter function returns how many whitelist mints a specified _user has remaining for current merkle root
        _proof - bytes32 array used to verify that _user is a whitelisted address
        _user - address to check remaining mints for
        amount - uint256 RETURN value that specifies number of remaining mints
    */
    function getAllowedMintAmount(bytes32[] calldata _proof, address _user) public view returns (uint256 amount) {
        bytes32 leaf = keccak256(abi.encodePacked(_user));
        amount = MerkleProof.verify(_proof,root,leaf) ? (rootMintAmt - _getAux(_user)) : 0;
    }

    /*
        Returns mint price
    */
    function getItemPrice() public view returns (uint256) {
		return itemPrice;
	}

    /*
        Returns baseURI string value
    */
    function _baseURI() internal view override returns (string memory){
        return baseURI;
    }

    /*
        Returns tokenURI for specified _tokenID
    */
    function tokenURI(uint256 _tokenID) public view virtual override returns (string memory) {
        require(_exists(_tokenID), "ERC721Metadata: URI query for nonexistent token");
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(_baseURI(), _tokenID.toString(), ".json")) : "";
    }
    
    /*
        Utility Functions - onlyOwner access
    */

    /*
        Transfers ETH from this contract to Owner
    */
    function withdrawEth() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /*
        Rescue any ERC-20 tokens that are sent to this contract mistakenly
    */
    function withdrawToken(IERC20 _token, uint256 _amount) public onlyOwner {
        _token.transferFrom(address(this), owner(), _amount);
    }
}