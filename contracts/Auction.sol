/*----------------------------------------------------------------------------------------------*/
//
// MS: 19th Feb 2019 - Initial version
//
/*----------------------------------------------------------------------------------------------*/

// MS: WARN: Populate Settings with Dai contract address and signer address + other bits, 
//           then deploy CreateAuction with Settings address. 
//
//           refundSigner address in TEST is 0x9b19e4ef11018E94183ef65580ecE94599441cA4
//           Dai on Ropsten is 0x96a5d5D5A472F2958fDd39751Da5DE128211e5D8

//           Dai on mainnet is 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359

/*----------------------------------------------------------------------------------------------*/


pragma solidity ^0.5.0;


// Zeppelin Safe Maths

/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error
 */
library SafeMath {
    /**
     * @dev Multiplies two unsigned integers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
     * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Adds two unsigned integers, reverts on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
     * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
     * reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

/*--------------*/
/* MS: Our code */
/*--------------*/


interface tokenRecipient {
    function receiveApproval(address _from, uint256 _value, address _token, bytes calldata _extraData) external;
}

contract PausableListERC20 {

    string public name;
    string public symbol;
    uint8 public decimals = 18;
    
    uint256 public totalSupply;

    address owner;
    bool isPaused = false;

    // This creates an array with all balances
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    // This generates a public event on the blockchain that will notify clients
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);

    // maintain iteratable list of balances
    mapping (address => mapping (bool => address) ) public list;
    bool constant NEXT = true;
    bool constant PREV = false;
    address constant HEAD = address(0);
    
    /**
     *  Add entry to head of list
     * 
     */
    function addToList(address a) private {
        list[a][PREV] = HEAD;             
        list[a][NEXT] = list[HEAD][NEXT];   
        if ( list[HEAD][NEXT] != HEAD ) {
            list[ list[HEAD][NEXT] ][PREV] = a;
        }
        list[HEAD][NEXT] = a;   
    }

    /**
     *  Remove entry from list
     *
     */
    function removeFromList(address a) private {
        address prev_entry = list[a][PREV];
        address next_entry = list[a][NEXT];
        list[next_entry][PREV] = prev_entry;
        list[prev_entry][NEXT] = next_entry;
        delete list[a][PREV];
        delete list[a][NEXT];
    }


    /**
     * Constructor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    constructor(
        uint256 initialSupply,
        string memory tokenName,
        string memory tokenSymbol
    ) public {
        totalSupply = initialSupply;                        // in wei
        balanceOf[msg.sender] = totalSupply;                // Give the creator all initial tokens
        addToList(msg.sender);
        name = tokenName;                                   // Set the name for display purposes
        symbol = tokenSymbol;                               // Set the symbol for display purposes
        owner = msg.sender;
    }

    function pause() public {
        require( msg.sender == owner );
        isPaused = true;
    }

    function unpause() public {
        require( msg.sender == owner );
        isPaused = false;
    }

    function rescindOwnership() public {
        require( msg.sender == owner );
        owner = address(0);
    }


    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint _value) internal {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != address(0x0));
        // Check if the sender has enough
        require(balanceOf[_from] >= _value, "Insufficient Funds");
        // Check for overflows
        require(balanceOf[_to] + _value >= balanceOf[_to]);
        // Save this for an assertion in the future
        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        // Subtract from the sender
        balanceOf[_from] -= _value;
        
        if( balanceOf[_from] == 0) {
            removeFromList(_from);
        }        
        
        if (balanceOf[_to]==0 && _value > 0) {
            addToList(_to);
        }
        
        // Add the same to the recipient
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }

    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` on behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= allowance[_from][msg.sender]);     // Check allowance
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens on your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value) public
        returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * Set allowance for other address and notify
     *
     * Allows `_spender` to spend no more than `_value` tokens on your behalf, and then ping the contract about it
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     * @param _extraData some extra information to send to the approved contract
     */
    function approveAndCall(address _spender, uint256 _value, bytes memory _extraData)
        public
        returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, address(this), _extraData);
            return true;
        }
    }

    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value);   // Check if the sender has enough
        balanceOf[msg.sender] -= _value;            // Subtract from the sender
        if( balanceOf[msg.sender] == 0) {
            removeFromList(msg.sender);
        } 
        totalSupply -= _value;                      // Updates totalSupply
        emit Burn(msg.sender, _value);
        return true;
    }

    /**
     * Destroy tokens from other account
     *
     * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _value the amount of money to burn
     */
    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] >= _value);                // Check if the targeted balance is enough
        require(_value <= allowance[_from][msg.sender]);    // Check allowance
        balanceOf[_from] -= _value;                         // Subtract from the targeted balance
        if( balanceOf[_from] == 0) {
            removeFromList(_from);
        } 
        allowance[_from][msg.sender] -= _value;             // Subtract from the sender's allowance
        totalSupply -= _value;                              // Update totalSupply
        emit Burn(_from, _value);
        return true;
    }
}




interface PaymentToken {
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function transfer(address to, uint tokens) external returns (bool success);
}

contract Settings {
    
    address admin;
    
    address public refundSigner;
    address public paymentToken;
    address public auctionFactory;
    address public rewardTokenFactory;
    uint32  public tokenizeBatchSize = 10000;
    
    constructor() public {
        admin=msg.sender;
    }
    
    modifier onlyAdmin {
        require(msg.sender==admin);
        _;
    }
    
    function setRefundSigner(address _refundSigner) public onlyAdmin {
        refundSigner = _refundSigner;
    }
    
    function setPaymentToken(address _paymentToken) public onlyAdmin {
        paymentToken = _paymentToken;
    }
    
    function setAuctionFactory(address _auctionFactory) public onlyAdmin {
        auctionFactory = _auctionFactory;
    }

    function setRewardTokenFactory(address _rewardTokenFactory) public onlyAdmin {
        rewardTokenFactory = _rewardTokenFactory;
    }

    function setTokenizeBatchSize(uint32 _tokenizeBatchSize) public onlyAdmin {
        tokenizeBatchSize = _tokenizeBatchSize;
    }
}


interface AuctionFactoryInterface {
    function newAuction(address admin, address sender, uint rId, string calldata rSymbol, string calldata rDescr, uint numOwnerTokens, uint ownerMinBidPrice) 
               external returns(address);
}

contract AuctionFactory {
    function newAuction(address admin, address sender, uint rId, string calldata rSymbol, string calldata rDescr, uint numOwnerTokens, uint ownerMinBidPrice) 
               external returns(address) {
        Auction a = new Auction(admin, sender, rId, rSymbol, rDescr, numOwnerTokens, ownerMinBidPrice);
        return address(a);
    }
}
 
contract CreateAuction {

    //--------
    // Events
    //--------

    event CreateAuctionContract(address indexed factoryAddress, address indexed actionedBy, address indexed child, uint rId);

    event PauseAuction(address indexed factoryAddress, address indexed actionedBy, address indexed child, uint rId);
    event ResumeAuction(address indexed factoryAddress, address indexed actionedBy, address indexed child, uint rId);
    event EditAuction(address indexed factoryAddress, address indexed actionedBy, address indexed child, uint rId, 
                      string symbol, string descr, uint closeUTC);

    event DeleteAuction(address indexed factoryAddress, address indexed actionedBy, address indexed child, uint rId);

    //------------------
    // Contract storage
    //------------------

    address public admin;

    Settings public settings;

    // Maintain a double-linked list of created contracts

    bool constant NEXT_ENTRY = true;
    bool constant PREV_ENTRY = false;
    address constant HEAD = address(0x0);

    mapping (address => mapping (bool => address) ) public rContractsList;
    mapping (address => uint) public rContractIds;

    //-------------------
    // Private functions
    //-------------------

    function addToContractList(address newContract, uint rId) private {
        
        // Add new entries at the head of the list

        rContractsList[newContract][PREV_ENTRY] = HEAD;                               // Point new entry's prev-link to head of list 

        rContractsList[newContract][NEXT_ENTRY] = rContractsList[HEAD][NEXT_ENTRY];   // Point new entry's next-link at the current head entry

        // Point current head entry's prev-link to the new entry provided there is one, otherwise leave as 0x0

        if ( rContractsList[HEAD][NEXT_ENTRY] != HEAD ) {
            rContractsList[ rContractsList[HEAD][NEXT_ENTRY] ][PREV_ENTRY] = newContract; 
        }
 
        rContractsList[HEAD][NEXT_ENTRY] = newContract;    // Point head of list next-link to new entry        

        rContractIds[newContract] = rId;                   // Store Rights ID in separate mapping
    }


    function removeFromContractList(address rmContract) private {

        address prev_entry = rContractsList[rmContract][PREV_ENTRY];
        address next_entry = rContractsList[rmContract][NEXT_ENTRY];

        // Point the previous and next entries at each other

        rContractsList[next_entry][PREV_ENTRY] = prev_entry;
        rContractsList[prev_entry][NEXT_ENTRY] = next_entry;

        // Remove
 
        delete rContractsList[rmContract][PREV_ENTRY];
        delete rContractsList[rmContract][NEXT_ENTRY];

        delete rContractIds[rmContract];                
    }   

    function checkValidSymbol(string memory symbol) pure private {

        if( bytes(symbol).length < 6 ) {
            revert("Supplied symbol too short, must be between 6 and 9 inclusive.");
        }  

        if( bytes(symbol).length > 9 ) {
            revert("Supplied symbol too long, must be between 6 and 9 inclusive.");
        }  
    }

 
    function checkValidDescr(string memory descr) pure private {

        if( bytes(descr).length < 25 ) {
            revert("Supplied description too short, must be between 25 and 160 inclusive.");
        }  

        if( bytes(descr).length > 160 ) {
            revert("Supplied description too long, must be between 25 and 160 inclusive.");
        }  
    }

    function checkValidTime(uint unixtimestamp) view private {

        // should always be in the future

        if ( unixtimestamp < block.timestamp ) {
            revert("Supplied Unix Time is wrong");
        } 

    }

    function checkManagedContract(address c) view private returns (uint) {
        uint id = rContractIds[c];
        if(id==0) {
            revert("Not a managed contract");
        }
        return id; 
    }

    //------------- 
    // Constructor
    //------------- 

    constructor(address _settings) public {

        require( _settings != address(0), "No settings contract supplied" );

        admin = msg.sender;  
        settings = Settings(_settings);

        settings.setAuctionFactory(address(this));

    }


    //------------------
    // Public functions
    //------------------

    //-------------------------------------------------------------------------
    // Create a new rights auction   
    // 
    // Called by rights owner:
    //
    //     _rId      - system generated rights ID
    //     _rSymbol  - system generated token symbol RT_50SOG1 (max 9 char)
    //     _rDescr   - description of auction and token 
    //
    //-------------------------------------------------------------------------

    function createAuction (uint _rId, string memory _rSymbol, string memory _rDescr, uint _numOwnerTokens, uint _ownerMinBidPrice ) public returns (address) {

        // MS: TODO: We should control who can create these using a whitelist
        //           Require onlyAdmin functions: addWhiteList(address user), removeWhiteList(address user)
        //           Require a check right here that reverts if msg.sender not on whitelist

        checkValidSymbol(_rSymbol);
        checkValidDescr(_rDescr);

        AuctionFactoryInterface afi = AuctionFactoryInterface(settings.auctionFactory());

        address auction = afi.newAuction(admin, msg.sender, _rId,  _rSymbol, _rDescr, _numOwnerTokens, _ownerMinBidPrice);

        addToContractList(auction, _rId);

        // The following event must be picked up by the system and the newContract address stored on the database

        emit CreateAuctionContract(address(this), msg.sender, auction, _rId);
    }

    //-------------------------------------------------------------------------
    // Admin functions
    //
    // MS: TODO: 
    // Current scheme there is one admin, the creator of the factory contract.
    // Things could be changed in the future to separate out: 
    // - could be multiple admins
    // - wallet address receiving payments not admin
    //
    //-------------------------------------------------------------------------

    modifier onlyAdmin {
        require(msg.sender == admin);
        _;
    }

    //-------------------------------------------------------------------------
    // Pause an auction
    //-------------------------------------------------------------------------
    
    function pauseAuction(address targetContract) public onlyAdmin {

        uint rId = checkManagedContract(targetContract);
 
        Auction a = Auction(targetContract);
        a.pauseAuction(); 

        emit PauseAuction(address(this), msg.sender, targetContract, rId);
    }

    //-------------------------------------------------------------------------
    // Resume an auction
    //-------------------------------------------------------------------------
    
    function resumeAuction(address targetContract) public onlyAdmin {

        uint rId = checkManagedContract(targetContract);
 
        Auction a = Auction(targetContract);
        a.resumeAuction(); 

        emit ResumeAuction(address(this), msg.sender, targetContract, rId);
    }

    //---------------------------------------------------------------------------
    // Edit an auction
    //
    // Change one or all of: symbol, description, block number when auction ends
    //---------------------------------------------------------------------------
    
    function editAuction(address targetContract, string memory symbol, string memory descr, uint closeTime) public onlyAdmin {

        uint rId = checkManagedContract(targetContract);
 
        if ( bytes(symbol).length > 0 ) {
            checkValidSymbol(symbol);
        }

        if ( bytes(descr).length > 0 ) {
            checkValidDescr(descr);
        }

        if ( closeTime > 0 ) {
            checkValidTime(closeTime);
        }

        Auction a = Auction(targetContract);
        a.editAuction(symbol, descr, closeTime); 

        emit EditAuction(address(this), msg.sender, targetContract, rId, symbol, descr, closeTime);
    }


    //---------------------------------------------------------------------------
    // Delete an auction
    //
    // All PT on contract to admin's wallet
    //---------------------------------------------------------------------------
    
    function deleteAuction(address targetContract) public onlyAdmin {

        uint rId = checkManagedContract(targetContract);
 
        Auction a = Auction(targetContract);
        a.deleteAuction();

        removeFromContractList(targetContract);  // remove from managed list

        emit DeleteAuction(address(this), msg.sender, targetContract, rId);
    }

}  



//--------------------------------------------------------------------------------------
// MS: Auction for tokenised rights - at close of auction, winning bids become tokens
//--------------------------------------------------------------------------------------
 
interface RewardTokenFactoryInterface {
    function newRewardToken(uint numTotalTokens, string calldata tokenName, string calldata tokenSymbol) external returns(address);
}

contract RewardTokenFactory {
    function newRewardToken(uint numTotalTokens, string calldata tokenName, string calldata tokenSymbol) external returns(address) {

        PausableListERC20 t = new PausableListERC20(numTotalTokens, tokenName, tokenSymbol);
        return address(t);

    }
}

interface RewardToken {
    function transfer(address receiver, uint amount) external;
    function pause() external;
    function unpause() external;
    function rescindOwnership() external;
}

contract Auction {

    //--------------------------------------------------------------------------------
    // NB: There is nothing in the contract that proves it is a legitimate contract
    //     anyone can call the factory and create this contract, they can create 
    //     a "fake" contract with all details looking like the real thing.
    //     The only "real" contract for a title, is the one stored in our
    //     database against the rId, our database is the authoritative record.
    //--------------------------------------------------------------------------------

    using SafeMath for uint256;

    //---------------------
    // Events
    //---------------------

    // Auction events carried out by admin

    event AuctionPaused(address indexed rightsAddress, address indexed admin);
    event AuctionResumed(address indexed rightsAddress, address indexed admin);
    event AuctionEditedSymbol(address indexed rightsAddress, address indexed admin, string oldValue, string newValue);
    event AuctionEditedDescr(address indexed rightsAddress, address indexed admin, string oldValue, string newValue);
    event AuctionEditedClose(address indexed rightsAddress, address indexed admin, uint oldValue, uint newValue);
    event AuctionDeleted(address indexed rightsAddress, address indexed admin);

    // Auction events carried out by investors

    event Bid(address indexed rightsAddress, address indexed investor, uint bidPrice, uint bidQty, uint bidAmt);
    event BidAmended(address indexed rightsAddress, address indexed investor, uint oldBidPrice, uint oldBidQty, uint oldBidAmt, 
                       uint newBidPrice, uint newBidQty, uint newBidAmt);
    event AuctionExtended(address indexed rightsAddress, address indexed investor, uint previousClose, uint newClose);
    event BidRefunded(address indexed rightsAddress, address indexed investor, uint refundAmt);

    // Auction events by original rights owner

    event CreateAuctionContract(address indexed rightsAddress, address indexed owner, uint numAvailToken, uint numOwnerTokens, uint ownerMinBidPrice, uint ownerMinTotalAmt);
    event TokenizeProcess(address indexed rightsAddress, address indexed owner, uint numTokenizedSoFar, uint numAvailToken, uint ownerPotSoFar );
    event Tokenized(address indexed rightsAddress, address indexed owner, uint numTokenized, uint numOwnerTokens, uint ownerPot );


    //---------------------    
    // Contract storage
    //---------------------

    Settings public settings;

    RewardToken rt;
    PaymentToken pt;

    address adminContract;

    address payable admin;      
    address payable owner;   

    enum ContractState { AUCTION_OPEN, AUCTION_CLOSED, AUCTION_FAILED, TOKEN, ADMIN_PAUSED, TOKENIZING } 
    ContractState cState;

    uint public rId;     
    
    string public auctionDescription; 
    string public auctionSymbol; 

    // total tokens on offer is 1 million less what the owner has reserved for themselves
    // total supply of token will normally be this, but could be less, see tokenization function

    uint public numTotalTokens = 1000000;  

    uint public numOwnerTokens;
    uint public numAvailTokens;
    uint public ownerMinBidPrice;
    uint public ownerMinTotalAmt;

    uint public openTime;
    uint public closeTime;

    uint public lastUpdateTime;  // time of last bid

    uint public numBids;         // number of non-refunded bids

    uint totalAmtInContract;     // total PT in contract


    // Maintain a double-linked list of bidPrice ordered bids

    bool constant NEXT_ENTRY = true;
    bool constant PREV_ENTRY = false;
    address constant HEAD = address(0x0);

    struct BidStruct {
        uint bidPrice;
        uint bidQty;
        uint bidAmt;
    }

    mapping (address => mapping (bool => address) ) public bidList;
    mapping (address => BidStruct) public bidData;

    // Tokenization

    uint public ownerPot;
    uint public numTokenized;
    address public tokenizeAddress;


    /*-------------------*/
    /* Private functions */
    /*-------------------*/

    //-----------------------------------------------
    // Return true if address has entry on bid list
    //-----------------------------------------------

    function bidExists(address bidder) view private returns (bool) {
         if ( bidData[bidder].bidPrice > 0 ) {
             return true;
         } else {
             return false;
         }
    }

    //-----------------------------------------------
    // Return true if bid list empty
    //-----------------------------------------------

    function emptyBidList() view private returns (bool) {
        if ( HEAD == bidList[HEAD][NEXT_ENTRY] ) {
             return true;
        } else {
             return false;
        }
    }

    function nextBidList(address a) view private returns (address) {
        return bidList[a][NEXT_ENTRY];
    }
 
    //------------------------------------------------------------------------------------
    // This function begins searching at searchAtAddress, moves down the list until it
    // encounters a lower bidPrice, it then returns the immediatley preceeding address.
    //------------------------------------------------------------------------------------

    function searchBidList( uint bidPrice, address searchAtAddress ) view private returns (address) {

        if ( HEAD != searchAtAddress ) {
            require ( bidData[searchAtAddress].bidPrice > bidPrice, "H2L");  // search hint too low
        }

        if ( emptyBidList() ) {

            if ( HEAD != searchAtAddress ) {
                revert( "SHEL" ); // search hint supplied to an empty list
            }

            return HEAD;  // don't need to search an empty list 
        }

        address currEntry = HEAD;
        address nextEntry = bidList[HEAD][NEXT_ENTRY];

        uint8 i = 0;

        while( nextEntry != HEAD && bidData[nextEntry].bidPrice >= bidPrice ) {

            currEntry = nextEntry;
            nextEntry = bidList[nextEntry][NEXT_ENTRY];

            i++;

            if ( 100 == i ) {
                revert( "SHB" ); // supplied serch hint was bad, caused prolonged search."
            }
        }

        return currEntry;
    }

    //------------------------------------------------------------------------------------
    // Insert new entry immediatley after position address  
    //------------------------------------------------------------------------------------

    function insertBidList(address bidder, uint bidPrice, uint bidQty, uint bidAmt, address position) private {
        
        bidList[bidder][PREV_ENTRY] = position;                
        bidList[bidder][NEXT_ENTRY] = bidList[position][NEXT_ENTRY];   

        if ( bidList[position][NEXT_ENTRY] != HEAD ) {                      
            bidList[ bidList[position][NEXT_ENTRY] ][PREV_ENTRY] = bidder;  
        }
 
        bidList[position][NEXT_ENTRY] = bidder;     

        bidData[bidder] = BidStruct( bidPrice, bidQty, bidAmt );
    }

    //-----------------------------
    // Remove entry from list
    //-----------------------------

    function deleteBidList(address del) private {

        address prev_entry = bidList[del][PREV_ENTRY];
        address next_entry = bidList[del][NEXT_ENTRY];

        bidList[next_entry][PREV_ENTRY] = prev_entry;
        bidList[prev_entry][NEXT_ENTRY] = next_entry;

        delete bidList[del][PREV_ENTRY];
        delete bidList[del][NEXT_ENTRY];
    }   

    //-----------------------------------
    // Returns true if price is valid
    //-----------------------------------

    function isValidBidPrice(uint bp) pure private returns (bool) {
       
        if ( bp == 0 ) {
            return false;
        }

        if ( bp > 1e24 ) {
            return false;     // bid price for 1 token cannot be over 1 million
        }
 
        return ( bp.mod( 1e16 ) ) == 0;   // must be 2dp
        
    }

    //-----------------------------------
    // Returns true if amount is valid
    //-----------------------------------

    function isValidAmt(uint amt) pure private returns (bool) {
       
        if ( amt == 0 ) {
            return false;
        }

        if ( amt > 1e26 ) {
            return false;     // amt cannot be more than 100M
        }
 
        return ( amt.mod( 1e16 ) ) == 0;   // must be 2dp
        
    }

    //-----------------------------------
    // Returns true if quantity is valid
    //-----------------------------------

    function isValidQty(uint qty) pure private returns (bool) {

        if ( qty == 0 ) {
            return false;
        }

        return true;
    }

    //--------------------------------
    // Returns current contract state
    //--------------------------------

    function getContractState() view private returns (ContractState cs) {

        if (ContractState.AUCTION_OPEN==cState && closeTime < block.timestamp && totalAmtInContract < ownerMinTotalAmt) {
            return ContractState.AUCTION_FAILED;
        } 
       
        if (ContractState.AUCTION_OPEN==cState && closeTime < block.timestamp) {
            return ContractState.AUCTION_CLOSED;
        } 
       
        return cState;

    } 


    //-------------------------------------------------
    // Modifier: must be called from Factory
    //-------------------------------------------------

    modifier onlyFromAdminContract {
        require(msg.sender == adminContract);
        _;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier onlyAdmin {
        require(msg.sender == admin);
        _;
    }

    //--------------------------------------------------------------------------------------
    // Verify a refund ticket, which is a signiture of the hashed sender and amount
    //--------------------------------------------------------------------------------------

    function verifyRefundTicket(address refundAddress, uint256 refundAmount, bytes memory sig) view private returns (bool) {

        address refundSigner = settings.refundSigner();

        require ( refundSigner != address(0) ); 

        // This recreates the data hash that was created on the client by abi.soliditySHA3 before signing

        bytes32 dataHash = keccak256(abi.encodePacked(refundAddress, refundAmount));
        
        // signing prefixes the hash and hashes it again:
        
        bytes32 dataHashEth = prefixed(dataHash);
        
        // get signing address

        address signer = recoverSigner(dataHashEth, sig);

        return ( signer == refundSigner );
    }


    // Signature methods

    function splitSignature(bytes memory sig) internal pure returns (uint8, bytes32, bytes32) {
    
        require(sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function recoverSigner(bytes32 message, bytes memory sig) internal pure returns (address) {
    
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    // Builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    //--------------------------------------------------------
    // Modifier: must be called from Externally Owned Account
    //--------------------------------------------------------

    // MS: TODO: Do we really need this? Allowing contracts to hold our tokens introduces possibilities of hacks, but this breaks interoperability....
    // need to think.

    modifier onlyFromEOA {
        require(tx.origin == msg.sender);
        _;
    }

    /*-------------*/
    /* Constructor */
    /*-------------*/

    constructor(address _admin, address _owner, uint _rId, string memory _rSymbol, string memory _rDescr, 
                  uint _numOwnerTokens, uint _ownerMinBidPrice) public onlyFromAdminContract {

        adminContract = msg.sender;

        settings = Settings(adminContract);

        pt = PaymentToken(settings.paymentToken());  // for the life of this contract

        admin = address(uint160(_admin));  // cast to payable address

        owner = address(uint160(_owner));  // cast to payable address

        rId = _rId;
        auctionDescription = _rDescr; 
        auctionSymbol = _rSymbol; 

        cState = ContractState.AUCTION_OPEN;
        openTime = block.timestamp;
        closeTime = block.timestamp + 30 days; 

        numOwnerTokens = _numOwnerTokens;
        numAvailTokens = numTotalTokens.sub( numOwnerTokens );
  
        if(!isValidBidPrice(_ownerMinBidPrice)) {
            revert("MBP2DP" ); // "Owner min bid price is not 2dp, or exceeds maximum, or is zero.");
        }

        ownerMinBidPrice = _ownerMinBidPrice;

        ownerMinTotalAmt = ownerMinBidPrice.mul( numAvailTokens );
    
        emit CreateAuctionContract(address(this), owner, numAvailTokens, numOwnerTokens, ownerMinBidPrice, ownerMinTotalAmt);
    }

    /*------------------*/
    /* Public functions */
    /*------------------*/

    //-------------
    // Bid
    //-------------

    function bid( uint bidPrice, uint bidQty, uint bidAmt, address searchAtAddress) public onlyFromEOA {

        /*-----------------------------------------------------------------------------------*/ 
        /* Dues to delays in mining the transaction, it is possible that a bid comes in late */
        /*-----------------------------------------------------------------------------------*/ 

        require( ContractState.AUCTION_OPEN == getContractState(), "Auction is closed" );

        /*----------------------------------------------------------------------------------------------*/
        /* Failure of the following checks indicate the front end is not applying constraints correctly */
        /*----------------------------------------------------------------------------------------------*/

        require( isValidBidPrice(bidPrice), "BP2DP" ); //"Bid price must be to 2dp and greater than zero." );

        require( bidPrice > ownerMinBidPrice, "BPTL" ); //"Bid price must be above owner mandated minimum bid price." );

        require( isValidAmt(bidAmt), "A2DP" ); //"Bid amount must be to 2dp and greater than zero." );

        require( bidQty > 0 && bidQty <= numAvailTokens, "QB" ); //"Bid quantity must be greater than zero and not exceed available tokens." );

        require( bidQty.mul(bidPrice)==bidAmt, "AB" ); //"Bid quantity * price must equal amount" );

        require( false==bidExists(msg.sender), "UHB" ); //"User already has bid on system");  

        if ( searchAtAddress != HEAD ) {
            require( bidExists(searchAtAddress), "SI" ); //"Supplied search address is invalid" ); 
        }

        /*---------------------------------------------------------------------------------------------*/ 
        /* The user must have authorised the amount of PT transfer...                                 */
        /* Front end is able to check this using ERC20 "allowance" call on the PT contract...         */
        /* Don't let them bid until they have "approved" the required amount, which means waiting on   */  
        /* the approval transactiont hen checking the allowance, only then displaying the bid button.  */ 
        /*---------------------------------------------------------------------------------------------*/ 

        require(pt.balanceOf(msg.sender) >= bidAmt && pt.allowance(msg.sender, address(this)) >= bidAmt);

        /*--------------------------------*/
        /* Transfer the PT into contract */
        /*--------------------------------*/
 
        pt.transferFrom(msg.sender, address(this), bidAmt);

        /*-------------*/
        /* Add the bid */
        /*-------------*/

        address position = searchBidList( bidPrice, searchAtAddress);
 
        insertBidList( msg.sender, bidPrice, bidQty, bidAmt, position );

        numBids++;  // number of bids 

        totalAmtInContract += bidAmt;  // total PT in this contract

        lastUpdateTime = block.timestamp;

        emit Bid(address(this), msg.sender, bidPrice, bidQty, bidAmt);

        /*---------------------------------------------------------*/
        /* If bid is in last X miuntes of auction, extend auction. */
        /*---------------------------------------------------------*/
       
        if ( block.timestamp > closeTime - 5 minutes ) {
            uint newCloseTime = block.timestamp + 5 minutes;
            emit AuctionExtended(address(this), msg.sender, closeTime, newCloseTime);
        }  

    }

    //-------------
    // Amend bid
    //-------------

    function amendBid( uint currBidPrice, uint currBidQty, uint currBidAmt, 
                       uint amendBidPrice, uint amendBidQty, uint amendBidAmt,
                       address searchAtAddress) public onlyFromEOA {

        /*-----------------------------------------------------------------------------------*/ 
        /* Dues to delays in mining the transaction, it is possible that a bid comes in late */
        /*-----------------------------------------------------------------------------------*/ 

        require( ContractState.AUCTION_OPEN == getContractState(), "AC" ); //"Auction is closed" );

        /*----------------------------------------------------------------------------------------------*/
        /* Failure of the following checks indicate the front end is not applying constraints correctly */
        /*----------------------------------------------------------------------------------------------*/

        require( isValidBidPrice(currBidPrice), "CBP2DP"); //"Current bid price must be to 2dp and greater than zero." );

        require( currBidPrice > ownerMinBidPrice, "CBB"); //"Current bid price must be above owner mandated minimum bid price." );

        require( currBidQty > 0 && currBidQty <= numAvailTokens, "CQB1"); //"Current bid quantity must be greater than zero and not exceed available tokens." );

        require( currBidQty.mul(currBidPrice)==currBidAmt, "CQB2"); //"Current bid quantity * price must equal current amount." );

        require( isValidAmt(currBidAmt), "CAB"); //"Current bid amount must be to 2dp and greater than zero." );


        require( isValidBidPrice(amendBidPrice), "ABP2DP"); //"Amend bid price must be to 2dp and greater than zero." );

        require( amendBidPrice > ownerMinBidPrice, "ABB"); //"Amend bid price must be above owner mandated minimum bid price." );

        require( amendBidQty > 0 && amendBidQty <= numAvailTokens, "AQB1"); //"Amend bid quantity must be greater than zero and not exceed available tokens." );

        require( amendBidQty.mul(amendBidPrice)==amendBidAmt, "AQB2"); //"Amend bid quantity * price must equal amendent amount." );

        require( isValidAmt(amendBidAmt), "AAB"); //"Amend bid amount must be to 2dp and greater than zero." );


        require( amendBidPrice >= currBidPrice, "APGC"); //"Amend bid price must be equal or greater than the current bid price." );

        require( amendBidQty >= currBidQty, "AQGC"); //"Amend bid quantity must be equal or greater than the current bid quantity." );

        require( amendBidAmt >= currBidAmt, "AAGC"); //"Amend bid amount must be equal or greater than the current bid amount." );


        if ( searchAtAddress != HEAD ) {
            require( bidExists(searchAtAddress), "SI"); //"Supplied search address is invalid" ); 
        }

        require( true==bidExists(msg.sender), "NB"); //"User does not have bid on system, nothing to amend.");  

        BidStruct memory currBid = bidData[msg.sender];

        require( currBidPrice == currBid.bidPrice, "BPNM"); //"Current bid price parameter does not match stored bid price" ); 

        require( currBidQty == currBid.bidQty, "BQNM"); //"Current bid quantity parameter does not match stored bid quantity" ); 

        require( currBidAmt == currBid.bidAmt, "BANM"); //"Current bid amount parameter does not match stored bid amount" );

        uint additionalFunds = amendBidAmt.sub( currBidAmt );

        /*----------------------------------------------------*/
        /* User must have authorised transfer of required PT */
        /*----------------------------------------------------*/

        require(pt.balanceOf(msg.sender) >= additionalFunds && pt.allowance(msg.sender, address(this)) >= additionalFunds);

        /*--------------------------------*/
        /* Transfer the PT into contract */
        /*--------------------------------*/
 
        pt.transferFrom(msg.sender, address(this), additionalFunds);
      
        /*----------------------------------*/ 
        /* Remove existing bid, add new bid */ 
        /*----------------------------------*/ 

        deleteBidList(msg.sender);

        address position = searchBidList( amendBidPrice, searchAtAddress);
 
        insertBidList( msg.sender, amendBidPrice, amendBidQty, amendBidAmt, position );


        totalAmtInContract = additionalFunds;  

        lastUpdateTime = block.timestamp;

        emit BidAmended(address(this), msg.sender, currBidPrice, currBidQty, currBidAmt, amendBidPrice, amendBidQty, amendBidAmt );

        /*---------------------------------------------------------*/
        /* If bid is in last X miuntes of auction, extend auction. */
        /*---------------------------------------------------------*/
       
        if ( block.timestamp > closeTime - 5 minutes ) {
            uint newCloseTime = block.timestamp + 5 minutes;
            emit AuctionExtended(address(this), msg.sender, closeTime, newCloseTime);
        }  

    }


    //-------------
    // Refund
    //-------------

    function refundBid( uint refundAmt, bytes memory refundTicket ) public onlyFromEOA {

        /*----------------------------------------------------------------------------------------------*/
        /* Failure of the following checks indicate the front end is not applying constraints correctly */
        /*----------------------------------------------------------------------------------------------*/

        require( isValidAmt(refundAmt), "RA2DP"); //"Refund amount must be to 2dp and greater than zero." );

        require( true==bidExists(msg.sender), "NB"); //"User does not have bid on system, nothing to refund.");  

        BidStruct memory refundBidEntry = bidData[msg.sender];

        require( refundAmt == refundBidEntry.bidAmt, "RANM"); //"Refund bid amount parameter does not match stored bid amount" );

        ContractState cs = getContractState();

        require( cs == ContractState.AUCTION_FAILED || cs == ContractState.TOKEN || cs == ContractState.AUCTION_OPEN, "CSN"); //"Contract state does not allow action" ); 

        /*----------------------------------*/
        /* Verify the ticket and refund PT */
        /*----------------------------------*/

        if ( cs == ContractState.AUCTION_OPEN ) {

            //-----------------------------------------------------------------------------------------------------
            // If the auction is over but failed to raise sufficient funds, anyone can get their PT back.
            // After tokenization, any bids not tokenized can be refunded.
            // During the auction you need a server generated ticket, because only "dead" bids may be refunded.
            //-----------------------------------------------------------------------------------------------------

            require( verifyRefundTicket( msg.sender, refundAmt, refundTicket ), "Refund ticket is invalid" );
        }

        // MS: WARN: This is an attack point, if they can somehow repeatedly refund themselves, they can drain the contract

        deleteBidList(msg.sender);

        pt.transfer( msg.sender, refundAmt );

        totalAmtInContract = totalAmtInContract.sub(refundAmt);

        assert( pt.balanceOf( address(this) ) == totalAmtInContract ); 

        emit BidRefunded(address(this), msg.sender, refundAmt );
    }

    //-------------
    // Tokenize
    //-------------

    function tokenizeRights() public onlyOwner {

        // Because there is iteration, if the number of bids is very large, this function may need to be called multiple times.

        ContractState cs = getContractState();

        require( cs == ContractState.AUCTION_CLOSED || cs == ContractState.TOKENIZING, "Auction must be closed for tokenization");

        require( totalAmtInContract >= ownerMinTotalAmt, "Auction did not raise enough funds" );

        if ( cs == ContractState.AUCTION_CLOSED ) {

            RewardTokenFactoryInterface rtfi = RewardTokenFactoryInterface(settings.rewardTokenFactory());

            rt = RewardToken( rtfi.newRewardToken(numTotalTokens, auctionDescription, auctionSymbol) );

            rt.pause();

            cState = ContractState.TOKENIZING;
            tokenizeAddress = nextBidList(HEAD);
        }

        uint32 numProcessEntries = settings.tokenizeBatchSize();  

        bool complete = false;

        // move down the linked list turning bids into tokens

        while( numProcessEntries > 0 ) {

            if( numTokenized + bidData[tokenizeAddress].bidQty <= numAvailTokens ) {
            
                // Tokenize full qty 
 
                numProcessEntries--;

                uint tokenizeQty = bidData[tokenizeAddress].bidQty;
                uint tokenizeAmt = bidData[tokenizeAddress].bidAmt;

                numTokenized = numTokenized.add( tokenizeQty );

                ownerPot = ownerPot.add( tokenizeAmt );

                rt.transfer(msg.sender, tokenizeQty);

                address next = nextBidList(tokenizeAddress);
                deleteBidList(tokenizeAddress);
                tokenizeAddress = next;
               
                if ( next == HEAD ) {
                    numProcessEntries = 0;  //end of the list
                    complete = true;
                }

                if ( numTokenized == numAvailTokens ) {
                    numProcessEntries = 0;  // all available tokens given out
                    complete = true;
                }
 
            } else {

                // Tokenize partial qty

                uint tokenizeQty = numAvailTokens.sub(numTokenized);
                uint remainQty = bidData[tokenizeAddress].bidQty.sub( tokenizeQty );

                uint tokenizeAmt = tokenizeQty.mul( bidData[tokenizeAddress].bidAmt ).div( bidData[tokenizeAddress].bidQty );
                uint remainAmt = bidData[tokenizeAddress].bidAmt.sub( tokenizeAmt );

                numTokenized = numTokenized.add( tokenizeQty );

                ownerPot = ownerPot.add( tokenizeAmt );

                rt.transfer(msg.sender, tokenizeQty);

                bidData[tokenizeAddress].bidQty = remainQty; 
                bidData[tokenizeAddress].bidAmt = remainAmt; 

                numProcessEntries = 0;
                complete = true;

            } 

        }

        if ( complete ) {

            rt.transfer(msg.sender, numTotalTokens.sub(numTokenized));  // rights issuer gets all remaining tokens

            rt.unpause();

            rt.rescindOwnership();


            // MS: TODO: subtract our cut 

            // MS: WARN: If they can somehow call this again, they can grab the remaining DAI which is for refunds

            pt.transfer( msg.sender, ownerPot );  // pay owner proceedings

      
            cState = ContractState.TOKEN; 

            emit Tokenized(address(this), msg.sender, numTokenized, numOwnerTokens, ownerPot );

        } else {

            // owner will need to call again...

            emit TokenizeProcess(address(this), msg.sender, numTokenized, numAvailTokens, ownerPot );

        }
        

    }


    //---------------
    // Admin methods
    //---------------

    function pauseAuction() public onlyFromAdminContract {

        require( getContractState() == ContractState.AUCTION_OPEN || getContractState() == ContractState.AUCTION_CLOSED, "Contract state does not allow this action");

        cState = ContractState.ADMIN_PAUSED;
    
        emit AuctionPaused(address(this), tx.origin);
    }

    function resumeAuction() public onlyFromAdminContract {

        require( getContractState() == ContractState.ADMIN_PAUSED, "Contract state does not allow this action");

        cState = getContractState();

        emit AuctionResumed(address(this), tx.origin);
    }

    function editAuction(string memory _symbol, string memory _descr, uint _closeTime) public onlyFromAdminContract {

        require( getContractState() != ContractState.TOKEN, "Contract state does not allow this action");

        if ( bytes(_symbol).length > 0 ) {
            emit AuctionEditedSymbol(address(this), tx.origin, auctionSymbol, _symbol);
            auctionSymbol = _symbol;
        }

        if ( bytes(_descr).length > 0 ) {
            emit AuctionEditedDescr(address(this), tx.origin, auctionDescription, _descr);
            auctionDescription = _descr;
        }

        if ( _closeTime > 0 ) {
            emit AuctionEditedClose(address(this), tx.origin, closeTime, _closeTime);
            closeTime = _closeTime;
        }

    }

    function deleteAuction() public onlyFromAdminContract {

        require( getContractState() == ContractState.ADMIN_PAUSED, "Contract state does not allow this action");

        uint bal = pt.balanceOf( address(this) );

        pt.transfer( admin, bal );

        emit AuctionDeleted(address(this), tx.origin);

        selfdestruct(admin); 
    }

}
