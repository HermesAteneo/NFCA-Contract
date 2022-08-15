// SPDX-License-Identifier: CC BY-NC-ND 4.0 International - <PPS/> Protected Public Source License 
// https://github.com/HermesAteneo/Protected-Public-Source-License-PPSL

pragma solidity ^0.8.0;

library strings {
    struct slice {
        uint _len;
        uint _ptr;
    }

    function memcpy(uint dest, uint src, uint leng) private pure {
        for(; leng >= 32; leng -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        uint mask = type(uint).max;
        if (leng > 0) {
            mask = 256 ** (32 - leng) - 1;
        }
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    function toSlice(string memory self) internal pure returns (slice memory) {
        uint ptr;
        assembly {
            ptr := add(self, 0x20)
        }
        return slice(bytes(self).length, ptr);
    }

    function len(bytes32 self) internal pure returns (uint) {
        uint ret;
        if (self == 0)
            return 0;
        if (uint(self) & type(uint128).max == 0) {
            ret += 16;
            self = bytes32(uint(self) / 0x100000000000000000000000000000000);
        }
        if (uint(self) & type(uint64).max == 0) {
            ret += 8;
            self = bytes32(uint(self) / 0x10000000000000000);
        }
        if (uint(self) & type(uint32).max == 0) {
            ret += 4;
            self = bytes32(uint(self) / 0x100000000);
        }
        if (uint(self) & type(uint16).max == 0) {
            ret += 2;
            self = bytes32(uint(self) / 0x10000);
        }
        if (uint(self) & type(uint8).max == 0) {
            ret += 1;
        }
        return 32 - ret;
    }

    function toSliceB32(bytes32 self) internal pure returns (slice memory ret) {
        assembly {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x20))
            mstore(ptr, self)
            mstore(add(ret, 0x20), ptr)
        }
        ret._len = len(self);
    }

    function copy(slice memory self) internal pure returns (slice memory) {
        return slice(self._len, self._ptr);
    }

    function toString(slice memory self) internal pure returns (string memory) {
        string memory ret = new string(self._len);
        uint retptr;
        assembly { retptr := add(ret, 32) }
        memcpy(retptr, self._ptr, self._len);
        return ret;
    }

    function len(slice memory self) internal pure returns (uint l) {
        uint ptr = self._ptr - 31;
        uint end = ptr + self._len;
        for (l = 0; ptr < end; l++) {
            uint8 b;
            assembly { b := and(mload(ptr), 0xFF) }
            if (b < 0x80) {
                ptr += 1;
            } else if(b < 0xE0) {
                ptr += 2;
            } else if(b < 0xF0) {
                ptr += 3;
            } else if(b < 0xF8) {
                ptr += 4;
            } else if(b < 0xFC) {
                ptr += 5;
            } else {
                ptr += 6;
            }
        }
    }

    function empty(slice memory self) internal pure returns (bool) {
        return self._len == 0;
    }

    function compare(slice memory self, slice memory other) internal pure returns (int) {
        uint shortest = self._len;
        if (other._len < self._len)
            shortest = other._len;

        uint selfptr = self._ptr;
        uint otherptr = other._ptr;
        for (uint idx = 0; idx < shortest; idx += 32) {
            uint a;
            uint b;
            assembly {
                a := mload(selfptr)
                b := mload(otherptr)
            }
            if (a != b) {
                uint mask = type(uint).max; // 0xffff...
                if(shortest < 32) {
                  mask = ~(2 ** (8 * (32 - shortest + idx)) - 1);
                }
                unchecked {
                    uint diff = (a & mask) - (b & mask);
                    if (diff != 0)
                        return int(diff);
                }
            }
            selfptr += 32;
            otherptr += 32;
        }
        return int(self._len) - int(other._len);
    }

    function equals(slice memory self, slice memory other) internal pure returns (bool) {
        return compare(self, other) == 0;
    }

    function nextRune(slice memory self, slice memory rune) internal pure returns (slice memory) {
        rune._ptr = self._ptr;
        if (self._len == 0) {
            rune._len = 0;
            return rune;
        }
        uint l;
        uint b;
        assembly { b := and(mload(sub(mload(add(self, 32)), 31)), 0xFF) }
        if (b < 0x80) {
            l = 1;
        } else if(b < 0xE0) {
            l = 2;
        } else if(b < 0xF0) {
            l = 3;
        } else {
            l = 4;
        }
        if (l > self._len) {
            rune._len = self._len;
            self._ptr += self._len;
            self._len = 0;
            return rune;
        }
        self._ptr += l;
        self._len -= l;
        rune._len = l;
        return rune;
    }

    function nextRune(slice memory self) internal pure returns (slice memory ret) {
        nextRune(self, ret);
    }

    function ord(slice memory self) internal pure returns (uint ret) {
        if (self._len == 0) {
            return 0;
        }
        uint word;
        uint length;
        uint divisor = 2 ** 248;
        assembly { word:= mload(mload(add(self, 32))) }
        uint b = word / divisor;
        if (b < 0x80) {
            ret = b;
            length = 1;
        } else if(b < 0xE0) {
            ret = b & 0x1F;
            length = 2;
        } else if(b < 0xF0) {
            ret = b & 0x0F;
            length = 3;
        } else {
            ret = b & 0x07;
            length = 4;
        }
        if (length > self._len) {
            return 0;
        }
        for (uint i = 1; i < length; i++) {
            divisor = divisor / 256;
            b = (word / divisor) & 0xFF;
            if (b & 0xC0 != 0x80) {
                return 0;
            }
            ret = (ret * 64) | (b & 0x3F);
        }
        return ret;
    }

    function keccak(slice memory self) internal pure returns (bytes32 ret) {
        assembly {
            ret := keccak256(mload(add(self, 32)), mload(self))
        }
    }

    function startsWith(slice memory self, slice memory needle) internal pure returns (bool) {
        if (self._len < needle._len) {
            return false;
        }
        if (self._ptr == needle._ptr) {
            return true;
        }
        bool equal;
        assembly {
            let length := mload(needle)
            let selfptr := mload(add(self, 0x20))
            let needleptr := mload(add(needle, 0x20))
            equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
        }
        return equal;
    }

    function beyond(slice memory self, slice memory needle) internal pure returns (slice memory) {
        if (self._len < needle._len) {
            return self;
        }
        bool equal = true;
        if (self._ptr != needle._ptr) {
            assembly {
                let length := mload(needle)
                let selfptr := mload(add(self, 0x20))
                let needleptr := mload(add(needle, 0x20))
                equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
            }
        }
        if (equal) {
            self._len -= needle._len;
            self._ptr += needle._len;
        }
        return self;
    }

    function endsWith(slice memory self, slice memory needle) internal pure returns (bool) {
        if (self._len < needle._len) {
            return false;
        }
        uint selfptr = self._ptr + self._len - needle._len;
        if (selfptr == needle._ptr) {
            return true;
        }
        bool equal;
        assembly {
            let length := mload(needle)
            let needleptr := mload(add(needle, 0x20))
            equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
        }
        return equal;
    }

    function until(slice memory self, slice memory needle) internal pure returns (slice memory) {
        if (self._len < needle._len) {
            return self;
        }
        uint selfptr = self._ptr + self._len - needle._len;
        bool equal = true;
        if (selfptr != needle._ptr) {
            assembly {
                let length := mload(needle)
                let needleptr := mload(add(needle, 0x20))
                equal := eq(keccak256(selfptr, length), keccak256(needleptr, length))
            }
        }
        if (equal) {
            self._len -= needle._len;
        }
        return self;
    }

    function findPtr(uint selflen, uint selfptr, uint needlelen, uint needleptr) private pure returns (uint) {
        uint ptr = selfptr;
        uint idx;
        if (needlelen <= selflen) {
            if (needlelen <= 32) {
                bytes32 mask;
                if (needlelen > 0) {
                    mask = bytes32(~(2 ** (8 * (32 - needlelen)) - 1));
                }
                bytes32 needledata;
                assembly { needledata := and(mload(needleptr), mask) }
                uint end = selfptr + selflen - needlelen;
                bytes32 ptrdata;
                assembly { ptrdata := and(mload(ptr), mask) }
                while (ptrdata != needledata) {
                    if (ptr >= end)
                        return selfptr + selflen;
                    ptr++;
                    assembly { ptrdata := and(mload(ptr), mask) }
                }
                return ptr;
            } else {
                bytes32 hash;
                assembly { hash := keccak256(needleptr, needlelen) }
                for (idx = 0; idx <= selflen - needlelen; idx++) {
                    bytes32 testHash;
                    assembly { testHash := keccak256(ptr, needlelen) }
                    if (hash == testHash)
                        return ptr;
                    ptr += 1;
                }
            }
        }
        return selfptr + selflen;
    }

    function rfindPtr(uint selflen, uint selfptr, uint needlelen, uint needleptr) private pure returns (uint) {
        uint ptr;
        if (needlelen <= selflen) {
            if (needlelen <= 32) {
                bytes32 mask;
                if (needlelen > 0) {
                    mask = bytes32(~(2 ** (8 * (32 - needlelen)) - 1));
                }
                bytes32 needledata;
                assembly { needledata := and(mload(needleptr), mask) }
                ptr = selfptr + selflen - needlelen;
                bytes32 ptrdata;
                assembly { ptrdata := and(mload(ptr), mask) }
                while (ptrdata != needledata) {
                    if (ptr <= selfptr)
                        return selfptr;
                    ptr--;
                    assembly { ptrdata := and(mload(ptr), mask) }
                }
                return ptr + needlelen;
            } else {
                bytes32 hash;
                assembly { hash := keccak256(needleptr, needlelen) }
                ptr = selfptr + (selflen - needlelen);
                while (ptr >= selfptr) {
                    bytes32 testHash;
                    assembly { testHash := keccak256(ptr, needlelen) }
                    if (hash == testHash)
                        return ptr + needlelen;
                    ptr -= 1;
                }
            }
        }
        return selfptr;
    }

    function find(slice memory self, slice memory needle) internal pure returns (slice memory) {
        uint ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr);
        self._len -= ptr - self._ptr;
        self._ptr = ptr;
        return self;
    }

    function rfind(slice memory self, slice memory needle) internal pure returns (slice memory) {
        uint ptr = rfindPtr(self._len, self._ptr, needle._len, needle._ptr);
        self._len = ptr - self._ptr;
        return self;
    }

    function split(slice memory self, slice memory needle, slice memory token) internal pure returns (slice memory) {
        uint ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr);
        token._ptr = self._ptr;
        token._len = ptr - self._ptr;
        if (ptr == self._ptr + self._len) {
            self._len = 0;
        } else {
            self._len -= token._len + needle._len;
            self._ptr = ptr + needle._len;
        }
        return token;
    }

    function split(slice memory self, slice memory needle) internal pure returns (slice memory token) {
        split(self, needle, token);
    }

    function rsplit(slice memory self, slice memory needle, slice memory token) internal pure returns (slice memory) {
        uint ptr = rfindPtr(self._len, self._ptr, needle._len, needle._ptr);
        token._ptr = ptr;
        token._len = self._len - (ptr - self._ptr);
        if (ptr == self._ptr) {
            self._len = 0;
        } else {
            self._len -= token._len + needle._len;
        }
        return token;
    }

    function rsplit(slice memory self, slice memory needle) internal pure returns (slice memory token) {
        rsplit(self, needle, token);
    }

    function count(slice memory self, slice memory needle) internal pure returns (uint cnt) {
        uint ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr) + needle._len;
        while (ptr <= self._ptr + self._len) {
            cnt++;
            ptr = findPtr(self._len - (ptr - self._ptr), ptr, needle._len, needle._ptr) + needle._len;
        }
    }

    function contains(slice memory self, slice memory needle) internal pure returns (bool) {
        return rfindPtr(self._len, self._ptr, needle._len, needle._ptr) != self._ptr;
    }

    function concat(slice memory self, slice memory other) internal pure returns (string memory) {
        string memory ret = new string(self._len + other._len);
        uint retptr;
        assembly { retptr := add(ret, 32) }
        memcpy(retptr, self._ptr, self._len);
        memcpy(retptr + self._len, other._ptr, other._len);
        return ret;
    }

    function join(slice memory self, slice[] memory parts) internal pure returns (string memory) {
        if (parts.length == 0)
            return "";
        uint length = self._len * (parts.length - 1);
        for(uint i = 0; i < parts.length; i++)
            length += parts[i]._len;
        string memory ret = new string(length);
        uint retptr;
        assembly { retptr := add(ret, 32) }
        for(uint i = 0; i < parts.length; i++) {
            memcpy(retptr, parts[i]._ptr, parts[i]._len);
            retptr += parts[i]._len;
            if (i < parts.length - 1) {
                memcpy(retptr, self._ptr, self._len);
                retptr += self._len;
            }
        }
        return ret;
    }
}

pragma solidity ^0.8.0;

library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

pragma solidity ^0.8.0;
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

pragma solidity ^0.8.0;

abstract contract Ownable is Context {
    address internal _owner;
    constructor() {
        _owner = _msgSender();
    }

    function owner() internal view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

}

pragma solidity ^0.8.0;

library Address {

    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

pragma solidity ^0.8.0;

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

pragma solidity ^0.8.0;

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

pragma solidity ^0.8.0;

abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

pragma solidity ^0.8.0;

interface IERC721 is IERC165 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

pragma solidity ^0.8.0;

interface IERC721Metadata is IERC721 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

pragma solidity ^0.8.0;

contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;
    string internal _name;
    string internal _symbol;
    mapping(uint256 => address) internal _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );
        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");
        _beforeTokenTransfer(address(0), to, tokenId);
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
        _afterTokenTransfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId); 
        _beforeTokenTransfer(owner, address(0), tokenId);
        // Clear approvals
        _approve(address(0), tokenId);
        _balances[owner] -= 1;
        delete _owners[tokenId];
        emit Transfer(owner, address(0), tokenId);
        _afterTokenTransfer(owner, address(0), tokenId);             
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");
        _beforeTokenTransfer(from, to, tokenId);
        // Clear approvals from the previous owner
        _approve(address(0), tokenId);
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
        _afterTokenTransfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

pragma solidity ^0.8.0;

abstract contract ERC721Burnable is Context, ERC721 {
    function burn(uint256 tokenId) internal virtual {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        _burn(tokenId);
    }
}


pragma solidity ^0.8.0;

//----------------------------------------------------------------------------
// Maths Library /////////////////////////////////////////////////////////////
//----------------------------------------------------------------------------

library safeMath{
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
          return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }
    function usub(uint256 a, uint256 b) internal pure returns (uint256) {
        if(a <= b){ return 0; }
        else{ return a - b; }
    }    
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}//safeMath

//Storage Contract
////////////////////////////////

contract Storage {

    struct StructRecordsA {
        string Alias;
        string CID; //Content
        string Type; //ipfs //arweave //sia //swarm //url //html //json //text //qr //...
        string KeyWords;
        string Description;
        uint256 Created_TS;
        uint256 Mint_TS;
        uint256 Update_TS;
        address WOwner;
        address WAgent;
        string MetaData;
    }

    struct StructNoValidChars { string Symbol; }
    struct StructMultiChars { string Symbol; uint Len; }

    StructRecordsA[] public RecordsA;
    StructNoValidChars[] internal NoValidChars;
    StructMultiChars[] internal MultiChars;

    //Storage to searching
    mapping (string => uint)    public   AliasIndex; //Alias -> index
    mapping (uint => uint)      public   IndexState; //index -> 0 -> non created //  1 -> reg  // 2 -> minted // 3 -> deleted/burned
    mapping (address => uint[]) public   OwnerIndexes; //RecordsByOwner  

}

//KeyControl Contract
////////////////////////////////

contract KeyControl is Storage, Ownable {

    using safeMath for uint;
    using strings for *;

    //Set URLs//
    string internal ImgURL = "";
    string internal GatewayURL = "";    
    function SetURLs(string memory _ImgURL, string memory _GatewayURL) public onlyOwner{ 
        ImgURL = _ImgURL;
        GatewayURL = _GatewayURL;
    }

    //Check if token Id was already minted
    function isNFT(uint i) public view returns (bool) {
        if(IndexState[i] == 2){ return true; }
        return false;
    }

    //Generate public Token URI 
    function GenerateTokenURI(uint256 tokenId) internal view returns (string memory){
        
        //if( !isNFT(tokenId) ){  return "Alias not minted"; }

        string memory Alias  =   RecordsA[tokenId].Alias  ;
        string memory Name_  = string( abi.encodePacked( '"name": "', Alias ,'",') );
        string memory Description_ = string( abi.encodePacked( '"description": "',  RecordsA[tokenId].Description , " " ,  GatewayURL , Alias ,'",') );
        
            string memory tokenIdToString =  Strings.toString( tokenId );

        string memory IMG_ = string( abi.encodePacked( '"image": "', ImgURL , tokenIdToString ,'",') );
        string memory URL_ = string( abi.encodePacked( '"external_url": "', GatewayURL , Alias ,'",') );
        
        string memory Owner_ = string( abi.encodePacked( '"owner": "',  Strings.toHexString(uint160(RecordsA[tokenId].WOwner), 20) ,'", "agent": "',  Strings.toHexString(uint160(RecordsA[tokenId].WAgent), 20) ,'",' ) );
        
        string memory Minted_ = string( abi.encodePacked( '"minted": "',  Strings.toString( RecordsA[tokenId].Mint_TS ) ,'",') );

            uint AliasLen =  AliasRealCharCount( RecordsA[tokenId].Alias );
        //Zora
        string memory Atrb1_ = string( abi.encodePacked( '"features":[{"Alias Length":"', Strings.toString( AliasLen ) ,'"}],') ); 
        //OpenSea
        string memory Atrb2_ = string( abi.encodePacked( '"attributes":[{"trait_type":"Alias Length","value":"', Strings.toString( AliasLen ) ,'"}]') ); //No last comma
        string memory json = string( abi.encodePacked('{',Name_,Description_,IMG_,URL_,Owner_,Minted_,Atrb1_,Atrb2_,'}'));

        return json;
    }

    uint public AMax  = 100; //Max Alias lengh
    uint public CIDMax= 11000; //Max CID lengh
    uint public KMax  = 200; //Max Keywords lengh
    uint public DMax  = 300; //Max Description lengh
    uint public SEMax = 20; //Max SE qty lengh

    function SetMax(uint _AMax, uint _CIDMax, uint _KMax, uint _DMax, uint _SEMax) public onlyOwner{ 
        AMax   = _AMax;
        CIDMax = _CIDMax;
        KMax   = _KMax;
        DMax   = _DMax;
        SEMax  = _SEMax;
    }

    //Save Data
    function SaveData(
        string memory _Alias, 
        string memory _CID, 
        string memory _Type,  
        string memory _KeyWords,  
        string memory _Description,
        address _Agent,
        address _Owner,
        string memory _MetaData
    ) internal returns (bool){

        require( 
            CountUTF8String( _Alias ) <= AMax
            && CountUTF8String( _CID ) <= CIDMax 
            && CountUTF8String( _Type ) <= 50 
            && CountUTF8String( _KeyWords ) <= KMax 
            && CountUTF8String( _Description ) <= DMax
            , "Fields too long" 
        );

        if( msg.sender != _owner){ _Owner = msg.sender; }

        AliasIndex[_Alias] = RecordsA.length;
        IndexState[RecordsA.length] = 1;
        OwnerIndexes[_Owner].push(RecordsA.length); 

        StructRecordsA memory a;

        a.Alias         = _Alias;
        a.CID           = _CID;
        a.Type          = _Type; 
        a.Description   = _Description;
        a.KeyWords      = _KeyWords;
        a.Created_TS    =  block.timestamp;
        a.Mint_TS       =  0;
        a.Update_TS     = block.timestamp;
        a.WAgent  = _Agent;
        a.WOwner  = _Owner;
        a.MetaData      = _MetaData;

        RecordsA.push(a);

        return true;  
    }

    //Edit Data
    function EditData (
        uint256 i, 
        string memory _CID, 
        string memory _Type,  
        string memory _KeyWords,  
        string memory _Description,
        string memory _MetaData
    ) internal returns (bool){

        require( 
            CountUTF8String( _Type ) <= 50 
            && CountUTF8String( _CID ) <= CIDMax 
            && CountUTF8String( _KeyWords ) <= KMax 
            && CountUTF8String( _Description ) <= DMax
            , "Fields too long" 
        );

        RecordsA[i].CID         = _CID;
        RecordsA[i].Type        = _Type;
        RecordsA[i].Description = _Description;
        RecordsA[i].KeyWords    = _KeyWords;
        RecordsA[i].Update_TS   = block.timestamp;
        RecordsA[i].MetaData    = _MetaData;

        return true;  
    }

    //Delete Data
    function DeleteData( uint256 i) internal returns (bool){

        AliasIndex[RecordsA[i].Alias] = 0;
        IndexState[i] = 3;
        for (uint x = 0; x < OwnerIndexes[RecordsA[i].WOwner].length; x++) {
            if (OwnerIndexes[RecordsA[i].WOwner][x] == i) {
                OwnerIndexes[RecordsA[i].WOwner][x] = 0; //=0
            }
        }

        RecordsA[i].Alias       = "";
        RecordsA[i].CID         = "";
        RecordsA[i].Type        = "";
        RecordsA[i].Description = "";
        RecordsA[i].KeyWords    = "";
        RecordsA[i].Mint_TS     = 0;
        RecordsA[i].Update_TS   = block.timestamp;
        RecordsA[i].WAgent= address(0);
        RecordsA[i].WOwner= address(0);
        RecordsA[i].MetaData    = "";

        return true;  
    }

    //Validate chars into alias received
    function AliasValidate (string memory alias_) public view returns (bool){

        //Fixed invalid chars
        if( keccak256( bytes( alias_ ) ) == keccak256( bytes( "" ) ) ) { return false; } //No string
        if( ContainWord( "," , alias_ ) ) { return false; } //Comma cant manage as normal string
        if( ContainWord( "/" , alias_ ) ) { return false; } //URL paths
        if( ContainWord( "%" , alias_ ) ) { return false; } 
        if( ContainWord( " " , alias_ ) ) { return false; } 

        //No valid chars
        for (uint i = 0; i < NoValidChars.length; i++) {
            //Substract the non real chars 
            if( ContainWord( NoValidChars[i].Symbol, alias_ ) ){
                return false;
            }
        }
        return true; 
    }


    //Real length of alias //
    function AliasRealCharCount (string memory alias_) public view returns (uint256 RealLength){
        RealLength = CountUTF8String(alias_); //First count (more than real count)
        uint times = 0;
        for (uint i = 0; i < MultiChars.length; i++) { 
            //Substract the non real chars
            times = HowManyRepeated( MultiChars[i].Symbol, alias_ );
            if(times!=0){
                RealLength = RealLength -  MultiChars[i].Len * times + 1 * times  ; //plus +1 * times
            }
        }
        return RealLength; 
    }

    //Special chars counts array //substract length in alias chars count
    function Admin_MultiChar2Struct(string memory str) public onlyOwner {
        strings.slice memory s = str.toSlice();
        strings.slice memory delim = "-".toSlice();                        
        string[] memory parts = new string[](s.count(delim));

        StructMultiChars memory e;
        string memory empty = "";
        bool repeated = false;

        for (uint i = 0; i < parts.length; i++) {
            repeated = false;
            string memory part = s.split(delim).toString();
            
            //Return if exist char
            for (uint k = 0; k < MultiChars.length; k++) {
                if( keccak256( bytes( MultiChars[k].Symbol )) == keccak256( bytes( part )) ){ repeated = true; }       
            }
            if(!repeated){
                if( keccak256( bytes( part )) != keccak256( bytes(empty) ) ){
                    e.Symbol = part;
                    MultiChars.push(e);  
                }
            }             
        }   
        //Set length
        for (uint x = 0; x < parts.length; x++) {
            MultiChars[x].Len =  CountUTF8String( MultiChars[x].Symbol );      
        }
    }

    function Admin_DeleteMultiChar(uint index) public onlyOwner {
        require(index < MultiChars.length);
        MultiChars[index] = MultiChars[MultiChars.length-1];
        MultiChars.pop();
    }
    
    function Admin_GetMultiChar() public view returns (string memory) {
        string memory output="";
        for (uint i = 0; i < MultiChars.length; i++) {
            output = string( abi.encodePacked( output, MultiChars[i].Symbol ,'-' ));
        }
        return output;
    }

    //Invalid chars array
    function Admin_NoValidChars2Struct(string memory str) public onlyOwner {
        //char-char-
        strings.slice memory s = str.toSlice();
        strings.slice memory delim = "-".toSlice();                        
        string[] memory parts = new string[](s.count(delim)+1);

        StructNoValidChars memory e; 
        string memory empty = "";
        bool repeated = false;

        for (uint i = 0; i < parts.length; i++) {
            repeated = false;
            string memory part = s.split(delim).toString();

            //Return if exist char
            for (uint k = 0; k < NoValidChars.length; k++) {
                if( keccak256( bytes( NoValidChars[k].Symbol )) == keccak256( bytes( part )) ){ repeated = true; }       
            }
            if(!repeated){
                if( keccak256( bytes( part )) != keccak256( bytes(empty) ) ){
                    e.Symbol = part;
                    NoValidChars.push(e);
                }
            }              
        }   
    }

    function Admin_DeleteNoValidChar(uint index) public onlyOwner {
        require(index < NoValidChars.length);
        NoValidChars[index] = NoValidChars[NoValidChars.length-1];
        NoValidChars.pop();
    }
    
    function Admin_GetNoValidChar() public view returns (string memory) {
        string memory output="";
        for (uint i = 0; i < NoValidChars.length; i++) {
            output = string( abi.encodePacked( output, NoValidChars[i].Symbol ,'-' ));
        }
        return output;    
    }


    //SE Tool
    function SE_ByKeyWord(string memory _kword, string memory _where, string memory _type, uint _mint_ts, uint _reg_ts, uint _end, uint _qty) public view returns (string memory) {
        string memory output = "";
        uint repeated = 0;

        if(_end == 0) { _end = RecordsA.length; }
        if(_qty > SEMax || _qty == 0) { _qty = SEMax; } //Avoid block out of gas attack
        uint _start = _end.usub(_qty);

        for (uint i = _start; i <= _end; i++) {
            
            if(IndexState[i]==3){ continue; } //Burned

            repeated = 0;

            //Only no minted if 0 // 1 for minted and not
            if(_mint_ts == 0){ if(RecordsA[i].Mint_TS >_mint_ts ){ continue; } }

            //Only minted after _mint_ts
            if(_mint_ts != 1 && RecordsA[i].Mint_TS < _mint_ts ){ continue; }

            //Reg after _reg_ts // 0 for all
            if(RecordsA[i].Created_TS < _reg_ts ){ continue; }

            if(keccak256(bytes(_type))== keccak256(bytes(RecordsA[i].Type)) || keccak256(bytes(_type)) == keccak256(bytes("all")) ){

                if(keccak256(bytes(_where)) == keccak256(bytes("alias")) || keccak256(bytes(_where)) == keccak256(bytes("all")) ){
                    if( ContainWord( _kword, RecordsA[i].Alias ) ){
                        repeated++;
                    }
                }
                if(keccak256(bytes(_where)) == keccak256(bytes("keywords")) || keccak256(bytes(_where)) == keccak256(bytes("all")) ){
                    if( ContainWord( _kword, RecordsA[i].KeyWords ) ){
                        repeated++;
                    }
                }
                if(keccak256(bytes(_where)) == keccak256(bytes("description")) || keccak256(bytes(_where)) == keccak256(bytes("all")) ){
                    if( ContainWord( _kword, RecordsA[i].Description ) ){
                        repeated++;
                    }
                }

            }//_type

            if( repeated > 0 ){
                output = string( abi.encodePacked(output , Strings.toString( i ), ':', Strings.toString( repeated ), '-' ));
            }
        }//for

        return output;
    }


    //Pausing new regs and mints
    bool public PausedShort = true;
    bool public PausedLong = false;
    bool public PausedMShort = true;
    bool public PausedMLong = false;
    
    function SetPauses(bool _short, bool _long, bool _Mshort, bool _Mlong) public onlyOwner{
        PausedShort = _short;
        PausedLong = _long;
        PausedMShort = _Mshort;
        PausedMLong = _Mlong;             
    }
    
    function IsOwner() internal view returns (bool){
        if(msg.sender == _owner){ return true; }
        return false;
    } 

    //Payments Control
    uint public FALen = 0; //Chars for long alias 
    function SetFALen(uint _n) public onlyOwner{
        FALen = _n;
    }  


    //Price to register Alias//
    uint public PSA = 0; //Price of 1 Char Alias 
    uint public PLA = 0; //Price of any long Alias 
    //Price to Mint existent Alias
    uint public PMSA = 0; //Price of Mint existent short Alias 
    uint public PMLA = 0; //Price of Mint existent long Alias
    //Agent Fee  /*1 -> 0.01%  //10 -> 0.1%  //100 -> 1%  //1000 -> 10% */ 
    uint public AFee = 0;

    function SetPrices(uint _psa, uint _pla, uint _pmsa, uint _pmla, uint _afee) public onlyOwner{ 
        PSA = _psa;
        PLA = _pla;
        PMSA = _pmsa;
        PMLA = _pmla;
        AFee = _afee;
    }

    //Create Payment request
    function PaymentRequest(string memory _Alias, address payable _Agent) internal returns (bool){
        if( IsOwner() ){ return true; }
        uint256 RALen = AliasRealCharCount(_Alias);  
        if( RALen < FALen){ //Alias shorter than FALen
            if(PausedShort && !IsOwner() ){ revert( string( abi.encodePacked( "Alias needs to be longer than ", Strings.toString( FALen - 1 ), " chars" ) ) ); }
            
            uint256 Price = 0;
            if(RALen == 1) { Price = PSA; }
            else{ Price = (PSA/RALen) / (RALen/2); }

            if(msg.value < Price){ return false; } PayToAgent(_Agent);
        }
        //Long Alias
        if(PausedLong && !IsOwner() ){ revert("New regs paused");}
        if(msg.value < PLA){ return false; } PayToAgent(_Agent);
        return true;   
    }

    function PayToAgent(address _agent) internal{ 
        if(_agent != 0x0000000000000000000000000000000000000000 ) { //Not Selled by contract or owner

            uint AmountToAgent  = (msg.value * ( AFee )) / 10000;     
            (bool tOK,) = _agent.call{value: AmountToAgent}(""); 
            require(tOK);          
        }
    }
    
    function Contract2Address(address _to, uint _amount) public onlyOwner {
        address payable receiver = payable(_to);
        receiver.transfer(_amount);
    }

    //KC Managment
    function Substring(string memory str, uint startIndex, uint endIndex) internal pure returns (string memory ) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex-startIndex);
        for(uint i = startIndex; i < endIndex; i++) {
            result[i-startIndex] = strBytes[i];
        }
        return string(result);
    }

    function BasicCount(string memory text) internal pure returns (uint256 count1) {
        return bytes(text).length;
    }

    function CountUTF8String(string memory str) internal pure returns (uint256 length){
        uint i=0;
        bytes memory string_rep = bytes(str);

        while (i<string_rep.length){
            if (string_rep[i]>>7==0)
                i+=1;
            else if (string_rep[i]>>5==bytes1(uint8(0x6)))
                i+=2;
            else if (string_rep[i]>>4==bytes1(uint8(0xE)))
                i+=3;
            else if (string_rep[i]>>3==bytes1(uint8(0x1E)))
                i+=4;
            else
                //For safety
                i+=1;

            length++;
        }
    }

    function ContainWord (string memory what, string memory where) internal pure returns (bool found){
        bytes memory whatBytes = bytes (what);
        bytes memory whereBytes = bytes (where);

        if(whereBytes.length < whatBytes.length){ return false; }

        found = false;
        for (uint i = 0; i <= whereBytes.length - whatBytes.length; i++) {
            bool flag = true;
            for (uint j = 0; j < whatBytes.length; j++)
                if (whereBytes [i + j] != whatBytes [j]) {
                    flag = false;
                    break;
                }
            if (flag) {
                found = true;
                break;
            }
        }
        return found;
    }

    function HowManyRepeated(string memory what, string memory where) internal pure returns(uint){
        uint times = 0;
        if( ContainWord( what, where ) ){
            uint whatLen = BasicCount(what);
            uint whereLen = BasicCount(where);
            for (uint i = 0; i < whereLen - whatLen + 1 ; i++) {
                if( ContainWord( what, Substring( where, i , i + whatLen) ) ){
                    times++;
                }
            }
        }
        return times;
    }

}//KeyControl contract


//NFCA Contract
////////////////////////////////////////////

contract NFCA is ERC721, KeyControl, ERC721Burnable{

    constructor() ERC721("Mint Alias v.3.0", "MA3") {
        //ZERO 0 - Project owner
        NewRecord( "0", "Mint Alias v.3.0 project ownership", "text", "", "Mint Alias v.3.0 project ownership", address(0), msg.sender, "", false);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return GenerateTokenURI(tokenId);
    }

    //New Record
    function NewRecord(
        string memory _Alias, 
        string memory _CID, 
        string memory _Type,  
        string memory _KeyWords,  
        string memory _Description,
        address _Agent,
        address _Owner,
        string memory _MetaData,
        bool _Mint
    ) public payable {
        require( AliasIndex[_Alias]==0, "Alias already exists" );
        require( AliasValidate(_Alias), "Invalid alias" );
        if(!_Mint){ require( PaymentRequest(_Alias, payable(_Agent) ), "Incorrect payment"); }
        require( SaveData(_Alias, _CID, _Type, _KeyWords, _Description, _Agent, _Owner, _MetaData) ,"Data not saved");
        if(_Mint){ Mint(RecordsA.length-1); }
    }

    //Edit Record
    function EditRecord(
        uint256 _index, 
        string memory _CID, 
        string memory _Type,  
        string memory _KeyWords,  
        string memory _Description,
        string memory _MetaData
    ) public {
        require( RecordsA[_index].WOwner == msg.sender, "Alias owner required" );
        require( EditData(_index, _CID, _Type, _KeyWords, _Description, _MetaData) ,"Data not edited");
    }

    //Delete Record
    function DeleteRecord( uint256 i) public {
        require( RecordsA[i].WOwner == msg.sender, "Alias owner required" );
        if( isNFT(i) ){  _burn(i); }
        require( DeleteData(i) ,"Data not deleted");
    }

    //Mint NFT safety
    function Mint(uint256 tokenId) public payable {

        string memory _Alias = RecordsA[tokenId].Alias;
        require( RecordsA[tokenId].WOwner == msg.sender || msg.sender == _owner, "Alias owner required");
        require( !isNFT(tokenId), "Already minted");

        address Agent =  RecordsA[tokenId].WAgent;

        if( AliasRealCharCount(_Alias) < FALen ){ //if short
            if(PausedMShort && !IsOwner() ){ revert("Mint short paused"); }
            if( msg.value < PMSA && !IsOwner() ){ revert("Mint short price ERROR"); }
        }
        else{ //if long
            if(PausedMLong && !IsOwner() ){ revert("Mint long paused"); }
            if( msg.value < PMLA && !IsOwner() ){ revert("Mint long price ERROR"); }
        }  
        PayToAgent(Agent);
        _safeMint(RecordsA[tokenId].WOwner, tokenId);
        RecordsA[tokenId].Mint_TS = block.timestamp;
        IndexState[tokenId] = 2;  
    }

    function RecordsByOwner() public view returns (uint[] memory) {
        return OwnerIndexes[msg.sender];
    }

    //Transfer Override
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)  internal override(ERC721){
        require( !PausedMLong && !PausedMLong, "Contract paused");
        RecordsA[tokenId].WOwner = payable(to);

        for (uint x = 0; x < OwnerIndexes[from].length; x++) {
            if (OwnerIndexes[ from ][x] == tokenId) {
                OwnerIndexes[ from ][x] = 0; //=0
            }
        }

        if(to != address(0)){
            bool toFlag = false;

            for (uint y = 0; y < OwnerIndexes[to].length; y++) {
                if (OwnerIndexes[to][y] == tokenId) { toFlag = true; }
            }
            if(!toFlag){ OwnerIndexes[to].push(tokenId); }
        }

        super._beforeTokenTransfer(from, to, tokenId);

        if(tokenId == 0){ _owner = to; }
    }

    function supportsInterface(bytes4 interfaceId) public  view override (ERC721) returns (bool){
        return super.supportsInterface(interfaceId);
    }

    function TotalRecords(uint _state) public view returns(uint qty){ //0(all)-1(reg)-2(mint)-3(reg & mint)
        //0 -> Delete records
        //1 -> All registered records, no deleted
        //2 -> All minted records, no deleted
        //3 -> All registered + minted records, no deleted
        //4 -> All records (registered, minted, deleted)

        if(_state == 4){ qty = RecordsA.length-1; return qty; }

        for (uint i = 0; i < RecordsA.length; i++) {

            if( _state == 0 ) { 
                if( IndexState[i] == 3 ){ qty++; } 
            }
            if( _state == 1 ) { 
                if( IndexState[i] == 1 ){ qty++; } 
            }
            if( _state == 2 ) { 
                if( IndexState[i] == 2 ){ qty++; } 
            }            
            if( _state == 3 ) { 
                if( IndexState[i] == 1 || IndexState[i] == 2 ){ qty++; } 
            }

        }
        return qty;
    }
    
    function totalSupply() public view virtual returns (uint256) {
        return TotalRecords(2);
    } 

}//NFCA contract 