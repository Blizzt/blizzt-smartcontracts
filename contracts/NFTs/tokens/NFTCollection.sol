// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../../interfaces/INFTCollection.sol";
import "../../interfaces/INFTMarketplace.sol";

/**
 *
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */

 // TODO. Optimize in gas creating internal functions for duplicate code
contract NFTCollection is ERC165, INFTCollection, IERC1155, IERC1155MetadataURI {

    struct NFTData {
        mapping(address => uint256) balance;
        string metadata;
    }

    // Mapping from token ID to account balances
    mapping (uint256 => NFTData) private _balances;

    // Mapping from account to operator approvals
    mapping (address => mapping(address => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;

    address private nftMarketplace;
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(_owner == msg.sender, "OnlyOwner");
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155).interfaceId
            || interfaceId == type(IERC1155MetadataURI).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function initialize(address _nftMarketplace, address _newOwner, string memory uri_) external override {
        if (_owner == address(0)) {
            _setURI(uri_);

            nftMarketplace = _nftMarketplace;
            _owner = _newOwner;
        }
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256 _id) public view virtual override returns (string memory) {
        string memory metadata = _balances[_id].metadata;
        if (bytes(metadata).length >= 0) return string(abi.encodePacked(_uri, metadata));
    
        return string(abi.encodePacked(_uri, _id));
    }

    function uris(uint256[] memory _ids) public view virtual returns (string[] memory) {
        string[] memory metadatas = new string[](_ids.length);
        for (uint256 i=0; i<_ids.length; i++) {
            string memory metadata = _balances[_ids[i]].metadata;
            if (bytes(metadata).length >= 0) metadatas[i] = string(abi.encodePacked(_uri, metadata));
            else metadatas[i] = string(abi.encodePacked(_uri, _ids[i]));
        }
        
        return metadatas;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        return _balances[id].balance[account];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    )
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "BadLengths");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(msg.sender != operator, "NoMsgSender");

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        if (msg.sender == nftMarketplace) return true;
        
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    )
        public
        virtual
        override
    {
        require(to != address(0), "NoZeroAddress");
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "NotApproved"
        );

        address operator = msg.sender;

        _checkTokenRented(from, to, id, amount);

        uint256 fromBalance = _balances[id].balance[from];
        require(fromBalance >= amount, "NoFunds");
        _balances[id].balance[from] = fromBalance - amount;
        _balances[id].balance[to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        if (_isContract(to)) _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    function safeTransferForRent(
        address from,
        address to,
        uint256 id,
        uint256 amount
    )
        external
        override
    {
        require(msg.sender == nftMarketplace, "OnlyMarketPlace");
        require(to != address(0), "NoZeroAddress");
        address operator = msg.sender;

        uint256 fromBalance = _balances[id].balance[from];
        require(fromBalance >= amount, "NoFunds");
        _balances[id].balance[from] = fromBalance - amount;
        _balances[id].balance[to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        if (_isContract(to)) _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, "");
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        public
        virtual
        override
    {
        require(ids.length == amounts.length, "BadLengths");
        require(to != address(0), "NoZeroAddress");
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "NotApproved"
        );

        address operator = msg.sender;

        _checkTokensRented(from, to,  ids, amounts);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id].balance[from];
            require(fromBalance >= amount, "InsufficientBalance");
            _balances[id].balance[from] = fromBalance - amount;
            _balances[id].balance[to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        if (_isContract(to)) _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    function mint(address _account, uint256 _id, uint256 _amount, string memory _metadata) external override {
        require(msg.sender == _owner || msg.sender == nftMarketplace, "NoPermission");
        require(_existsId(_id) == false, "DuplicatedId");

        _mint(_account, _id, _amount, "");
        _balances[_id].metadata = _metadata;
    }

    function mint(address _account, uint256 _id, uint256 _amount) external override {
        require(msg.sender == _owner || msg.sender == nftMarketplace, "NoPermission");
        require(_existsId(_id) == false, "DuplicatedId");

        _mint(_account, _id, _amount, "");
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * By this mechanism, any occurrence of the `\{id\}` substring in either the
     * URI or any of the amounts in the JSON file at said URI will be replaced by
     * clients with the token type ID.
     *
     * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
     * interpreted by clients as
     * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
     * for token type ID 0x4cce0.
     *
     * See {uri}.
     *
     * Because these URIs cannot be meaningfully represented by the {URI} event,
     * this function emits no events.
     */
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `account`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - If `account` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(address account, uint256 id, uint256 amount, bytes memory data) internal virtual {
        require(account != address(0), "NoZeroAddress");

        address operator = msg.sender;

        _balances[id].balance[account] += amount;
        emit TransferSingle(operator, address(0), account, id, amount);

        if (_isContract(account)) _doSafeTransferAcceptanceCheck(operator, address(0), account, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal virtual {
        require(to != address(0), "NoZeroAddress");
        require(ids.length == amounts.length, "BadLengths");

        address operator = msg.sender;

        for (uint i = 0; i < ids.length; i++) {
            _balances[ids[i]].balance[to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        if (_isContract(to)) _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external override onlyOwner {
        _owner = newOwner;
        emit OwnershipTransferred(_owner, newOwner);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `account`
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens of token type `id`.
     */
    function _burn(address account, uint256 id, uint256 amount) internal virtual {
        require(account != address(0), "NoZeroAddress");

        address operator = msg.sender;

        uint256 accountBalance = _balances[id].balance[account];
        require(accountBalance >= amount, "NoFunds");
        _balances[id].balance[account] = accountBalance - amount;

        emit TransferSingle(operator, account, address(0), id, amount);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(address account, uint256[] memory ids, uint256[] memory amounts) internal virtual {
        require(account != address(0), "NoZeroAddress");
        require(ids.length == amounts.length, "BadLengths");

        address operator = msg.sender;

        for (uint i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 accountBalance = _balances[id].balance[account];
            require(accountBalance >= amount, "NoFunds");
            _balances[id].balance[account] = accountBalance - amount;
        }

        emit TransferBatch(operator, account, address(0), ids, amounts);
    }

    function _checkTokensRented(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    )
        internal 
        view
    {
        for (uint i=0; i<ids.length; i++) _checkTokenRented(from,to,ids[i],amounts[i]);
    }

    function _checkTokenRented(
        address from,
        address to,
        uint256 id,
        uint256 amount
    )
        internal 
        view
    {
        uint tokenAmount = _balances[id].balance[from];
        uint rentedAmount = INFTMarketplace(nftMarketplace).getUserRentedItems(to, id);
        require(tokenAmount - rentedAmount >= amount, "TokenRented");
    }

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    )
        private
    {
        try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
            if (response != IERC1155Receiver(to).onERC1155Received.selector) {
                revert("TokensRejected");
            }
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("NoERC1155Receiver");
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        private
    {
        try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 response) {
            if (response != IERC1155Receiver(to).onERC1155BatchReceived.selector) {
                revert("TokensRejected");
            }
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("NoERC1155Receiver");
        }
    }

    function _isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    function _existsId(uint256 id) internal view returns (bool) {
        return (bytes(_balances[id].metadata).length > 0);
    }
}
