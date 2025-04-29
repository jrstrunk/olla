// build/dev/javascript/prelude.mjs
var CustomType = class {
  withFields(fields) {
    let properties = Object.keys(this).map(
      (label) => label in fields ? fields[label] : this[label]
    );
    return new this.constructor(...properties);
  }
};
var List = class {
  static fromArray(array3, tail) {
    let t = tail || new Empty();
    for (let i = array3.length - 1; i >= 0; --i) {
      t = new NonEmpty(array3[i], t);
    }
    return t;
  }
  [Symbol.iterator]() {
    return new ListIterator(this);
  }
  toArray() {
    return [...this];
  }
  // @internal
  atLeastLength(desired) {
    let current = this;
    while (desired-- > 0 && current) current = current.tail;
    return current !== void 0;
  }
  // @internal
  hasLength(desired) {
    let current = this;
    while (desired-- > 0 && current) current = current.tail;
    return desired === -1 && current instanceof Empty;
  }
  // @internal
  countLength() {
    let current = this;
    let length4 = 0;
    while (current) {
      current = current.tail;
      length4++;
    }
    return length4 - 1;
  }
};
function prepend(element4, tail) {
  return new NonEmpty(element4, tail);
}
function toList(elements, tail) {
  return List.fromArray(elements, tail);
}
var ListIterator = class {
  #current;
  constructor(current) {
    this.#current = current;
  }
  next() {
    if (this.#current instanceof Empty) {
      return { done: true };
    } else {
      let { head, tail } = this.#current;
      this.#current = tail;
      return { value: head, done: false };
    }
  }
};
var Empty = class extends List {
};
var NonEmpty = class extends List {
  constructor(head, tail) {
    super();
    this.head = head;
    this.tail = tail;
  }
};
var BitArray = class {
  /**
   * The size in bits of this bit array's data.
   *
   * @type {number}
   */
  bitSize;
  /**
   * The size in bytes of this bit array's data. If this bit array doesn't store
   * a whole number of bytes then this value is rounded up.
   *
   * @type {number}
   */
  byteSize;
  /**
   * The number of unused high bits in the first byte of this bit array's
   * buffer prior to the start of its data. The value of any unused high bits is
   * undefined.
   *
   * The bit offset will be in the range 0-7.
   *
   * @type {number}
   */
  bitOffset;
  /**
   * The raw bytes that hold this bit array's data.
   *
   * If `bitOffset` is not zero then there are unused high bits in the first
   * byte of this buffer.
   *
   * If `bitOffset + bitSize` is not a multiple of 8 then there are unused low
   * bits in the last byte of this buffer.
   *
   * @type {Uint8Array}
   */
  rawBuffer;
  /**
   * Constructs a new bit array from a `Uint8Array`, an optional size in
   * bits, and an optional bit offset.
   *
   * If no bit size is specified it is taken as `buffer.length * 8`, i.e. all
   * bytes in the buffer make up the new bit array's data.
   *
   * If no bit offset is specified it defaults to zero, i.e. there are no unused
   * high bits in the first byte of the buffer.
   *
   * @param {Uint8Array} buffer
   * @param {number} [bitSize]
   * @param {number} [bitOffset]
   */
  constructor(buffer, bitSize, bitOffset) {
    if (!(buffer instanceof Uint8Array)) {
      throw globalThis.Error(
        "BitArray can only be constructed from a Uint8Array"
      );
    }
    this.bitSize = bitSize ?? buffer.length * 8;
    this.byteSize = Math.trunc((this.bitSize + 7) / 8);
    this.bitOffset = bitOffset ?? 0;
    if (this.bitSize < 0) {
      throw globalThis.Error(`BitArray bit size is invalid: ${this.bitSize}`);
    }
    if (this.bitOffset < 0 || this.bitOffset > 7) {
      throw globalThis.Error(
        `BitArray bit offset is invalid: ${this.bitOffset}`
      );
    }
    if (buffer.length !== Math.trunc((this.bitOffset + this.bitSize + 7) / 8)) {
      throw globalThis.Error("BitArray buffer length is invalid");
    }
    this.rawBuffer = buffer;
  }
  /**
   * Returns a specific byte in this bit array. If the byte index is out of
   * range then `undefined` is returned.
   *
   * When returning the final byte of a bit array with a bit size that's not a
   * multiple of 8, the content of the unused low bits are undefined.
   *
   * @param {number} index
   * @returns {number | undefined}
   */
  byteAt(index5) {
    if (index5 < 0 || index5 >= this.byteSize) {
      return void 0;
    }
    return bitArrayByteAt(this.rawBuffer, this.bitOffset, index5);
  }
  /** @internal */
  equals(other) {
    if (this.bitSize !== other.bitSize) {
      return false;
    }
    const wholeByteCount = Math.trunc(this.bitSize / 8);
    if (this.bitOffset === 0 && other.bitOffset === 0) {
      for (let i = 0; i < wholeByteCount; i++) {
        if (this.rawBuffer[i] !== other.rawBuffer[i]) {
          return false;
        }
      }
      const trailingBitsCount = this.bitSize % 8;
      if (trailingBitsCount) {
        const unusedLowBitCount = 8 - trailingBitsCount;
        if (this.rawBuffer[wholeByteCount] >> unusedLowBitCount !== other.rawBuffer[wholeByteCount] >> unusedLowBitCount) {
          return false;
        }
      }
    } else {
      for (let i = 0; i < wholeByteCount; i++) {
        const a2 = bitArrayByteAt(this.rawBuffer, this.bitOffset, i);
        const b = bitArrayByteAt(other.rawBuffer, other.bitOffset, i);
        if (a2 !== b) {
          return false;
        }
      }
      const trailingBitsCount = this.bitSize % 8;
      if (trailingBitsCount) {
        const a2 = bitArrayByteAt(
          this.rawBuffer,
          this.bitOffset,
          wholeByteCount
        );
        const b = bitArrayByteAt(
          other.rawBuffer,
          other.bitOffset,
          wholeByteCount
        );
        const unusedLowBitCount = 8 - trailingBitsCount;
        if (a2 >> unusedLowBitCount !== b >> unusedLowBitCount) {
          return false;
        }
      }
    }
    return true;
  }
  /**
   * Returns this bit array's internal buffer.
   *
   * @deprecated Use `BitArray.byteAt()` or `BitArray.rawBuffer` instead.
   *
   * @returns {Uint8Array}
   */
  get buffer() {
    bitArrayPrintDeprecationWarning(
      "buffer",
      "Use BitArray.byteAt() or BitArray.rawBuffer instead"
    );
    if (this.bitOffset !== 0 || this.bitSize % 8 !== 0) {
      throw new globalThis.Error(
        "BitArray.buffer does not support unaligned bit arrays"
      );
    }
    return this.rawBuffer;
  }
  /**
   * Returns the length in bytes of this bit array's internal buffer.
   *
   * @deprecated Use `BitArray.bitSize` or `BitArray.byteSize` instead.
   *
   * @returns {number}
   */
  get length() {
    bitArrayPrintDeprecationWarning(
      "length",
      "Use BitArray.bitSize or BitArray.byteSize instead"
    );
    if (this.bitOffset !== 0 || this.bitSize % 8 !== 0) {
      throw new globalThis.Error(
        "BitArray.length does not support unaligned bit arrays"
      );
    }
    return this.rawBuffer.length;
  }
};
function bitArrayByteAt(buffer, bitOffset, index5) {
  if (bitOffset === 0) {
    return buffer[index5] ?? 0;
  } else {
    const a2 = buffer[index5] << bitOffset & 255;
    const b = buffer[index5 + 1] >> 8 - bitOffset;
    return a2 | b;
  }
}
var UtfCodepoint = class {
  constructor(value3) {
    this.value = value3;
  }
};
var isBitArrayDeprecationMessagePrinted = {};
function bitArrayPrintDeprecationWarning(name, message) {
  if (isBitArrayDeprecationMessagePrinted[name]) {
    return;
  }
  console.warn(
    `Deprecated BitArray.${name} property used in JavaScript FFI code. ${message}.`
  );
  isBitArrayDeprecationMessagePrinted[name] = true;
}
function bitArraySlice(bitArray, start4, end) {
  end ??= bitArray.bitSize;
  bitArrayValidateRange(bitArray, start4, end);
  if (start4 === end) {
    return new BitArray(new Uint8Array());
  }
  if (start4 === 0 && end === bitArray.bitSize) {
    return bitArray;
  }
  start4 += bitArray.bitOffset;
  end += bitArray.bitOffset;
  const startByteIndex = Math.trunc(start4 / 8);
  const endByteIndex = Math.trunc((end + 7) / 8);
  const byteLength = endByteIndex - startByteIndex;
  let buffer;
  if (startByteIndex === 0 && byteLength === bitArray.rawBuffer.byteLength) {
    buffer = bitArray.rawBuffer;
  } else {
    buffer = new Uint8Array(
      bitArray.rawBuffer.buffer,
      bitArray.rawBuffer.byteOffset + startByteIndex,
      byteLength
    );
  }
  return new BitArray(buffer, end - start4, start4 % 8);
}
function bitArraySliceToInt(bitArray, start4, end, isBigEndian, isSigned) {
  bitArrayValidateRange(bitArray, start4, end);
  if (start4 === end) {
    return 0;
  }
  start4 += bitArray.bitOffset;
  end += bitArray.bitOffset;
  const isStartByteAligned = start4 % 8 === 0;
  const isEndByteAligned = end % 8 === 0;
  if (isStartByteAligned && isEndByteAligned) {
    return intFromAlignedSlice(
      bitArray,
      start4 / 8,
      end / 8,
      isBigEndian,
      isSigned
    );
  }
  const size2 = end - start4;
  const startByteIndex = Math.trunc(start4 / 8);
  const endByteIndex = Math.trunc((end - 1) / 8);
  if (startByteIndex == endByteIndex) {
    const mask2 = 255 >> start4 % 8;
    const unusedLowBitCount = (8 - end % 8) % 8;
    let value3 = (bitArray.rawBuffer[startByteIndex] & mask2) >> unusedLowBitCount;
    if (isSigned) {
      const highBit = 2 ** (size2 - 1);
      if (value3 >= highBit) {
        value3 -= highBit * 2;
      }
    }
    return value3;
  }
  if (size2 <= 53) {
    return intFromUnalignedSliceUsingNumber(
      bitArray.rawBuffer,
      start4,
      end,
      isBigEndian,
      isSigned
    );
  } else {
    return intFromUnalignedSliceUsingBigInt(
      bitArray.rawBuffer,
      start4,
      end,
      isBigEndian,
      isSigned
    );
  }
}
function intFromAlignedSlice(bitArray, start4, end, isBigEndian, isSigned) {
  const byteSize = end - start4;
  if (byteSize <= 6) {
    return intFromAlignedSliceUsingNumber(
      bitArray.rawBuffer,
      start4,
      end,
      isBigEndian,
      isSigned
    );
  } else {
    return intFromAlignedSliceUsingBigInt(
      bitArray.rawBuffer,
      start4,
      end,
      isBigEndian,
      isSigned
    );
  }
}
function intFromAlignedSliceUsingNumber(buffer, start4, end, isBigEndian, isSigned) {
  const byteSize = end - start4;
  let value3 = 0;
  if (isBigEndian) {
    for (let i = start4; i < end; i++) {
      value3 *= 256;
      value3 += buffer[i];
    }
  } else {
    for (let i = end - 1; i >= start4; i--) {
      value3 *= 256;
      value3 += buffer[i];
    }
  }
  if (isSigned) {
    const highBit = 2 ** (byteSize * 8 - 1);
    if (value3 >= highBit) {
      value3 -= highBit * 2;
    }
  }
  return value3;
}
function intFromAlignedSliceUsingBigInt(buffer, start4, end, isBigEndian, isSigned) {
  const byteSize = end - start4;
  let value3 = 0n;
  if (isBigEndian) {
    for (let i = start4; i < end; i++) {
      value3 *= 256n;
      value3 += BigInt(buffer[i]);
    }
  } else {
    for (let i = end - 1; i >= start4; i--) {
      value3 *= 256n;
      value3 += BigInt(buffer[i]);
    }
  }
  if (isSigned) {
    const highBit = 1n << BigInt(byteSize * 8 - 1);
    if (value3 >= highBit) {
      value3 -= highBit * 2n;
    }
  }
  return Number(value3);
}
function intFromUnalignedSliceUsingNumber(buffer, start4, end, isBigEndian, isSigned) {
  const isStartByteAligned = start4 % 8 === 0;
  let size2 = end - start4;
  let byteIndex = Math.trunc(start4 / 8);
  let value3 = 0;
  if (isBigEndian) {
    if (!isStartByteAligned) {
      const leadingBitsCount = 8 - start4 % 8;
      value3 = buffer[byteIndex++] & (1 << leadingBitsCount) - 1;
      size2 -= leadingBitsCount;
    }
    while (size2 >= 8) {
      value3 *= 256;
      value3 += buffer[byteIndex++];
      size2 -= 8;
    }
    if (size2 > 0) {
      value3 *= 2 ** size2;
      value3 += buffer[byteIndex] >> 8 - size2;
    }
  } else {
    if (isStartByteAligned) {
      let size3 = end - start4;
      let scale = 1;
      while (size3 >= 8) {
        value3 += buffer[byteIndex++] * scale;
        scale *= 256;
        size3 -= 8;
      }
      value3 += (buffer[byteIndex] >> 8 - size3) * scale;
    } else {
      const highBitsCount = start4 % 8;
      const lowBitsCount = 8 - highBitsCount;
      let size3 = end - start4;
      let scale = 1;
      while (size3 >= 8) {
        const byte = buffer[byteIndex] << highBitsCount | buffer[byteIndex + 1] >> lowBitsCount;
        value3 += (byte & 255) * scale;
        scale *= 256;
        size3 -= 8;
        byteIndex++;
      }
      if (size3 > 0) {
        const lowBitsUsed = size3 - Math.max(0, size3 - lowBitsCount);
        let trailingByte = (buffer[byteIndex] & (1 << lowBitsCount) - 1) >> lowBitsCount - lowBitsUsed;
        size3 -= lowBitsUsed;
        if (size3 > 0) {
          trailingByte *= 2 ** size3;
          trailingByte += buffer[byteIndex + 1] >> 8 - size3;
        }
        value3 += trailingByte * scale;
      }
    }
  }
  if (isSigned) {
    const highBit = 2 ** (end - start4 - 1);
    if (value3 >= highBit) {
      value3 -= highBit * 2;
    }
  }
  return value3;
}
function intFromUnalignedSliceUsingBigInt(buffer, start4, end, isBigEndian, isSigned) {
  const isStartByteAligned = start4 % 8 === 0;
  let size2 = end - start4;
  let byteIndex = Math.trunc(start4 / 8);
  let value3 = 0n;
  if (isBigEndian) {
    if (!isStartByteAligned) {
      const leadingBitsCount = 8 - start4 % 8;
      value3 = BigInt(buffer[byteIndex++] & (1 << leadingBitsCount) - 1);
      size2 -= leadingBitsCount;
    }
    while (size2 >= 8) {
      value3 *= 256n;
      value3 += BigInt(buffer[byteIndex++]);
      size2 -= 8;
    }
    if (size2 > 0) {
      value3 <<= BigInt(size2);
      value3 += BigInt(buffer[byteIndex] >> 8 - size2);
    }
  } else {
    if (isStartByteAligned) {
      let size3 = end - start4;
      let shift = 0n;
      while (size3 >= 8) {
        value3 += BigInt(buffer[byteIndex++]) << shift;
        shift += 8n;
        size3 -= 8;
      }
      value3 += BigInt(buffer[byteIndex] >> 8 - size3) << shift;
    } else {
      const highBitsCount = start4 % 8;
      const lowBitsCount = 8 - highBitsCount;
      let size3 = end - start4;
      let shift = 0n;
      while (size3 >= 8) {
        const byte = buffer[byteIndex] << highBitsCount | buffer[byteIndex + 1] >> lowBitsCount;
        value3 += BigInt(byte & 255) << shift;
        shift += 8n;
        size3 -= 8;
        byteIndex++;
      }
      if (size3 > 0) {
        const lowBitsUsed = size3 - Math.max(0, size3 - lowBitsCount);
        let trailingByte = (buffer[byteIndex] & (1 << lowBitsCount) - 1) >> lowBitsCount - lowBitsUsed;
        size3 -= lowBitsUsed;
        if (size3 > 0) {
          trailingByte <<= size3;
          trailingByte += buffer[byteIndex + 1] >> 8 - size3;
        }
        value3 += BigInt(trailingByte) << shift;
      }
    }
  }
  if (isSigned) {
    const highBit = 2n ** BigInt(end - start4 - 1);
    if (value3 >= highBit) {
      value3 -= highBit * 2n;
    }
  }
  return Number(value3);
}
function bitArrayValidateRange(bitArray, start4, end) {
  if (start4 < 0 || start4 > bitArray.bitSize || end < start4 || end > bitArray.bitSize) {
    const msg = `Invalid bit array slice: start = ${start4}, end = ${end}, bit size = ${bitArray.bitSize}`;
    throw new globalThis.Error(msg);
  }
}
var Result = class _Result extends CustomType {
  // @internal
  static isResult(data2) {
    return data2 instanceof _Result;
  }
};
var Ok = class extends Result {
  constructor(value3) {
    super();
    this[0] = value3;
  }
  // @internal
  isOk() {
    return true;
  }
};
var Error = class extends Result {
  constructor(detail) {
    super();
    this[0] = detail;
  }
  // @internal
  isOk() {
    return false;
  }
};
function isEqual(x2, y) {
  let values3 = [x2, y];
  while (values3.length) {
    let a2 = values3.pop();
    let b = values3.pop();
    if (a2 === b) continue;
    if (!isObject(a2) || !isObject(b)) return false;
    let unequal = !structurallyCompatibleObjects(a2, b) || unequalDates(a2, b) || unequalBuffers(a2, b) || unequalArrays(a2, b) || unequalMaps(a2, b) || unequalSets(a2, b) || unequalRegExps(a2, b);
    if (unequal) return false;
    const proto = Object.getPrototypeOf(a2);
    if (proto !== null && typeof proto.equals === "function") {
      try {
        if (a2.equals(b)) continue;
        else return false;
      } catch {
      }
    }
    let [keys2, get3] = getters(a2);
    for (let k of keys2(a2)) {
      values3.push(get3(a2, k), get3(b, k));
    }
  }
  return true;
}
function getters(object4) {
  if (object4 instanceof Map) {
    return [(x2) => x2.keys(), (x2, y) => x2.get(y)];
  } else {
    let extra = object4 instanceof globalThis.Error ? ["message"] : [];
    return [(x2) => [...extra, ...Object.keys(x2)], (x2, y) => x2[y]];
  }
}
function unequalDates(a2, b) {
  return a2 instanceof Date && (a2 > b || a2 < b);
}
function unequalBuffers(a2, b) {
  return !(a2 instanceof BitArray) && a2.buffer instanceof ArrayBuffer && a2.BYTES_PER_ELEMENT && !(a2.byteLength === b.byteLength && a2.every((n, i) => n === b[i]));
}
function unequalArrays(a2, b) {
  return Array.isArray(a2) && a2.length !== b.length;
}
function unequalMaps(a2, b) {
  return a2 instanceof Map && a2.size !== b.size;
}
function unequalSets(a2, b) {
  return a2 instanceof Set && (a2.size != b.size || [...a2].some((e) => !b.has(e)));
}
function unequalRegExps(a2, b) {
  return a2 instanceof RegExp && (a2.source !== b.source || a2.flags !== b.flags);
}
function isObject(a2) {
  return typeof a2 === "object" && a2 !== null;
}
function structurallyCompatibleObjects(a2, b) {
  if (typeof a2 !== "object" && typeof b !== "object" && (!a2 || !b))
    return false;
  let nonstructural = [Promise, WeakSet, WeakMap, Function];
  if (nonstructural.some((c) => a2 instanceof c)) return false;
  return a2.constructor === b.constructor;
}
function remainderInt(a2, b) {
  if (b === 0) {
    return 0;
  } else {
    return a2 % b;
  }
}
function divideInt(a2, b) {
  return Math.trunc(divideFloat(a2, b));
}
function divideFloat(a2, b) {
  if (b === 0) {
    return 0;
  } else {
    return a2 / b;
  }
}
function makeError(variant, module, line2, fn, message, extra) {
  let error2 = new globalThis.Error(message);
  error2.gleam_error = variant;
  error2.module = module;
  error2.line = line2;
  error2.function = fn;
  error2.fn = fn;
  for (let k in extra) error2[k] = extra[k];
  return error2;
}

// build/dev/javascript/gleam_stdlib/gleam/order.mjs
var Lt = class extends CustomType {
};
var Eq = class extends CustomType {
};
var Gt = class extends CustomType {
};

// build/dev/javascript/gleam_stdlib/gleam/option.mjs
var Some = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var None = class extends CustomType {
};
function is_some(option) {
  return !isEqual(option, new None());
}
function to_result(option, e) {
  if (option instanceof Some) {
    let a2 = option[0];
    return new Ok(a2);
  } else {
    return new Error(e);
  }
}
function unwrap(option, default$) {
  if (option instanceof Some) {
    let x2 = option[0];
    return x2;
  } else {
    return default$;
  }
}
function map(option, fun) {
  if (option instanceof Some) {
    let x2 = option[0];
    return new Some(fun(x2));
  } else {
    return new None();
  }
}
function flatten(option) {
  if (option instanceof Some) {
    let x2 = option[0];
    return x2;
  } else {
    return new None();
  }
}

// build/dev/javascript/gleam_stdlib/gleam/dict.mjs
function do_has_key(key2, dict2) {
  return !isEqual(map_get(dict2, key2), new Error(void 0));
}
function has_key(dict2, key2) {
  return do_has_key(key2, dict2);
}
function insert(dict2, key2, value3) {
  return map_insert(key2, value3, dict2);
}
function from_list_loop(loop$list, loop$initial) {
  while (true) {
    let list4 = loop$list;
    let initial = loop$initial;
    if (list4.hasLength(0)) {
      return initial;
    } else {
      let key2 = list4.head[0];
      let value3 = list4.head[1];
      let rest = list4.tail;
      loop$list = rest;
      loop$initial = insert(initial, key2, value3);
    }
  }
}
function from_list(list4) {
  return from_list_loop(list4, new_map());
}
function delete$(dict2, key2) {
  return map_remove(key2, dict2);
}

// build/dev/javascript/gleam_stdlib/gleam/pair.mjs
function second(pair) {
  let a2 = pair[1];
  return a2;
}
function map_second(pair, fun) {
  let a2 = pair[0];
  let b = pair[1];
  return [a2, fun(b)];
}

// build/dev/javascript/gleam_stdlib/gleam/list.mjs
var Ascending = class extends CustomType {
};
var Descending = class extends CustomType {
};
function length_loop(loop$list, loop$count) {
  while (true) {
    let list4 = loop$list;
    let count = loop$count;
    if (list4.atLeastLength(1)) {
      let list$1 = list4.tail;
      loop$list = list$1;
      loop$count = count + 1;
    } else {
      return count;
    }
  }
}
function length(list4) {
  return length_loop(list4, 0);
}
function reverse_and_prepend(loop$prefix, loop$suffix) {
  while (true) {
    let prefix = loop$prefix;
    let suffix = loop$suffix;
    if (prefix.hasLength(0)) {
      return suffix;
    } else {
      let first$1 = prefix.head;
      let rest$1 = prefix.tail;
      loop$prefix = rest$1;
      loop$suffix = prepend(first$1, suffix);
    }
  }
}
function reverse(list4) {
  return reverse_and_prepend(list4, toList([]));
}
function contains(loop$list, loop$elem) {
  while (true) {
    let list4 = loop$list;
    let elem = loop$elem;
    if (list4.hasLength(0)) {
      return false;
    } else if (list4.atLeastLength(1) && isEqual(list4.head, elem)) {
      let first$1 = list4.head;
      return true;
    } else {
      let rest$1 = list4.tail;
      loop$list = rest$1;
      loop$elem = elem;
    }
  }
}
function first(list4) {
  if (list4.hasLength(0)) {
    return new Error(void 0);
  } else {
    let first$1 = list4.head;
    return new Ok(first$1);
  }
}
function update_group(f) {
  return (groups, elem) => {
    let $ = map_get(groups, f(elem));
    if ($.isOk()) {
      let existing = $[0];
      return insert(groups, f(elem), prepend(elem, existing));
    } else {
      return insert(groups, f(elem), toList([elem]));
    }
  };
}
function filter_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list4 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list4.hasLength(0)) {
      return reverse(acc);
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      let _block;
      let $ = fun(first$1);
      if ($) {
        _block = prepend(first$1, acc);
      } else {
        _block = acc;
      }
      let new_acc = _block;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = new_acc;
    }
  }
}
function filter(list4, predicate) {
  return filter_loop(list4, predicate, toList([]));
}
function filter_map_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list4 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list4.hasLength(0)) {
      return reverse(acc);
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      let _block;
      let $ = fun(first$1);
      if ($.isOk()) {
        let first$2 = $[0];
        _block = prepend(first$2, acc);
      } else {
        _block = acc;
      }
      let new_acc = _block;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = new_acc;
    }
  }
}
function filter_map(list4, fun) {
  return filter_map_loop(list4, fun, toList([]));
}
function map_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list4 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list4.hasLength(0)) {
      return reverse(acc);
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = prepend(fun(first$1), acc);
    }
  }
}
function map2(list4, fun) {
  return map_loop(list4, fun, toList([]));
}
function index_map_loop(loop$list, loop$fun, loop$index, loop$acc) {
  while (true) {
    let list4 = loop$list;
    let fun = loop$fun;
    let index5 = loop$index;
    let acc = loop$acc;
    if (list4.hasLength(0)) {
      return reverse(acc);
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      let acc$1 = prepend(fun(first$1, index5), acc);
      loop$list = rest$1;
      loop$fun = fun;
      loop$index = index5 + 1;
      loop$acc = acc$1;
    }
  }
}
function index_map(list4, fun) {
  return index_map_loop(list4, fun, 0, toList([]));
}
function take_loop(loop$list, loop$n, loop$acc) {
  while (true) {
    let list4 = loop$list;
    let n = loop$n;
    let acc = loop$acc;
    let $ = n <= 0;
    if ($) {
      return reverse(acc);
    } else {
      if (list4.hasLength(0)) {
        return reverse(acc);
      } else {
        let first$1 = list4.head;
        let rest$1 = list4.tail;
        loop$list = rest$1;
        loop$n = n - 1;
        loop$acc = prepend(first$1, acc);
      }
    }
  }
}
function take(list4, n) {
  return take_loop(list4, n, toList([]));
}
function append_loop(loop$first, loop$second) {
  while (true) {
    let first2 = loop$first;
    let second2 = loop$second;
    if (first2.hasLength(0)) {
      return second2;
    } else {
      let first$1 = first2.head;
      let rest$1 = first2.tail;
      loop$first = rest$1;
      loop$second = prepend(first$1, second2);
    }
  }
}
function append(first2, second2) {
  return append_loop(reverse(first2), second2);
}
function prepend2(list4, item) {
  return prepend(item, list4);
}
function flatten_loop(loop$lists, loop$acc) {
  while (true) {
    let lists = loop$lists;
    let acc = loop$acc;
    if (lists.hasLength(0)) {
      return reverse(acc);
    } else {
      let list4 = lists.head;
      let further_lists = lists.tail;
      loop$lists = further_lists;
      loop$acc = reverse_and_prepend(list4, acc);
    }
  }
}
function flatten2(lists) {
  return flatten_loop(lists, toList([]));
}
function flat_map(list4, fun) {
  let _pipe = map2(list4, fun);
  return flatten2(_pipe);
}
function fold(loop$list, loop$initial, loop$fun) {
  while (true) {
    let list4 = loop$list;
    let initial = loop$initial;
    let fun = loop$fun;
    if (list4.hasLength(0)) {
      return initial;
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      loop$list = rest$1;
      loop$initial = fun(initial, first$1);
      loop$fun = fun;
    }
  }
}
function group(list4, key2) {
  return fold(list4, new_map(), update_group(key2));
}
function map_fold(list4, initial, fun) {
  let _pipe = fold(
    list4,
    [initial, toList([])],
    (acc, item) => {
      let current_acc = acc[0];
      let items = acc[1];
      let $ = fun(current_acc, item);
      let next_acc = $[0];
      let next_item = $[1];
      return [next_acc, prepend(next_item, items)];
    }
  );
  return map_second(_pipe, reverse);
}
function index_fold_loop(loop$over, loop$acc, loop$with, loop$index) {
  while (true) {
    let over = loop$over;
    let acc = loop$acc;
    let with$ = loop$with;
    let index5 = loop$index;
    if (over.hasLength(0)) {
      return acc;
    } else {
      let first$1 = over.head;
      let rest$1 = over.tail;
      loop$over = rest$1;
      loop$acc = with$(acc, first$1, index5);
      loop$with = with$;
      loop$index = index5 + 1;
    }
  }
}
function index_fold(list4, initial, fun) {
  return index_fold_loop(list4, initial, fun, 0);
}
function find(loop$list, loop$is_desired) {
  while (true) {
    let list4 = loop$list;
    let is_desired = loop$is_desired;
    if (list4.hasLength(0)) {
      return new Error(void 0);
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      let $ = is_desired(first$1);
      if ($) {
        return new Ok(first$1);
      } else {
        loop$list = rest$1;
        loop$is_desired = is_desired;
      }
    }
  }
}
function unique_loop(loop$list, loop$seen, loop$acc) {
  while (true) {
    let list4 = loop$list;
    let seen = loop$seen;
    let acc = loop$acc;
    if (list4.hasLength(0)) {
      return reverse(acc);
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      let $ = has_key(seen, first$1);
      if ($) {
        loop$list = rest$1;
        loop$seen = seen;
        loop$acc = acc;
      } else {
        loop$list = rest$1;
        loop$seen = insert(seen, first$1, void 0);
        loop$acc = prepend(first$1, acc);
      }
    }
  }
}
function unique(list4) {
  return unique_loop(list4, new_map(), toList([]));
}
function sequences(loop$list, loop$compare, loop$growing, loop$direction, loop$prev, loop$acc) {
  while (true) {
    let list4 = loop$list;
    let compare5 = loop$compare;
    let growing = loop$growing;
    let direction = loop$direction;
    let prev = loop$prev;
    let acc = loop$acc;
    let growing$1 = prepend(prev, growing);
    if (list4.hasLength(0)) {
      if (direction instanceof Ascending) {
        return prepend(reverse(growing$1), acc);
      } else {
        return prepend(growing$1, acc);
      }
    } else {
      let new$1 = list4.head;
      let rest$1 = list4.tail;
      let $ = compare5(prev, new$1);
      if ($ instanceof Gt && direction instanceof Descending) {
        loop$list = rest$1;
        loop$compare = compare5;
        loop$growing = growing$1;
        loop$direction = direction;
        loop$prev = new$1;
        loop$acc = acc;
      } else if ($ instanceof Lt && direction instanceof Ascending) {
        loop$list = rest$1;
        loop$compare = compare5;
        loop$growing = growing$1;
        loop$direction = direction;
        loop$prev = new$1;
        loop$acc = acc;
      } else if ($ instanceof Eq && direction instanceof Ascending) {
        loop$list = rest$1;
        loop$compare = compare5;
        loop$growing = growing$1;
        loop$direction = direction;
        loop$prev = new$1;
        loop$acc = acc;
      } else if ($ instanceof Gt && direction instanceof Ascending) {
        let _block;
        if (direction instanceof Ascending) {
          _block = prepend(reverse(growing$1), acc);
        } else {
          _block = prepend(growing$1, acc);
        }
        let acc$1 = _block;
        if (rest$1.hasLength(0)) {
          return prepend(toList([new$1]), acc$1);
        } else {
          let next = rest$1.head;
          let rest$2 = rest$1.tail;
          let _block$1;
          let $1 = compare5(new$1, next);
          if ($1 instanceof Lt) {
            _block$1 = new Ascending();
          } else if ($1 instanceof Eq) {
            _block$1 = new Ascending();
          } else {
            _block$1 = new Descending();
          }
          let direction$1 = _block$1;
          loop$list = rest$2;
          loop$compare = compare5;
          loop$growing = toList([new$1]);
          loop$direction = direction$1;
          loop$prev = next;
          loop$acc = acc$1;
        }
      } else if ($ instanceof Lt && direction instanceof Descending) {
        let _block;
        if (direction instanceof Ascending) {
          _block = prepend(reverse(growing$1), acc);
        } else {
          _block = prepend(growing$1, acc);
        }
        let acc$1 = _block;
        if (rest$1.hasLength(0)) {
          return prepend(toList([new$1]), acc$1);
        } else {
          let next = rest$1.head;
          let rest$2 = rest$1.tail;
          let _block$1;
          let $1 = compare5(new$1, next);
          if ($1 instanceof Lt) {
            _block$1 = new Ascending();
          } else if ($1 instanceof Eq) {
            _block$1 = new Ascending();
          } else {
            _block$1 = new Descending();
          }
          let direction$1 = _block$1;
          loop$list = rest$2;
          loop$compare = compare5;
          loop$growing = toList([new$1]);
          loop$direction = direction$1;
          loop$prev = next;
          loop$acc = acc$1;
        }
      } else {
        let _block;
        if (direction instanceof Ascending) {
          _block = prepend(reverse(growing$1), acc);
        } else {
          _block = prepend(growing$1, acc);
        }
        let acc$1 = _block;
        if (rest$1.hasLength(0)) {
          return prepend(toList([new$1]), acc$1);
        } else {
          let next = rest$1.head;
          let rest$2 = rest$1.tail;
          let _block$1;
          let $1 = compare5(new$1, next);
          if ($1 instanceof Lt) {
            _block$1 = new Ascending();
          } else if ($1 instanceof Eq) {
            _block$1 = new Ascending();
          } else {
            _block$1 = new Descending();
          }
          let direction$1 = _block$1;
          loop$list = rest$2;
          loop$compare = compare5;
          loop$growing = toList([new$1]);
          loop$direction = direction$1;
          loop$prev = next;
          loop$acc = acc$1;
        }
      }
    }
  }
}
function merge_ascendings(loop$list1, loop$list2, loop$compare, loop$acc) {
  while (true) {
    let list1 = loop$list1;
    let list22 = loop$list2;
    let compare5 = loop$compare;
    let acc = loop$acc;
    if (list1.hasLength(0)) {
      let list4 = list22;
      return reverse_and_prepend(list4, acc);
    } else if (list22.hasLength(0)) {
      let list4 = list1;
      return reverse_and_prepend(list4, acc);
    } else {
      let first1 = list1.head;
      let rest1 = list1.tail;
      let first2 = list22.head;
      let rest2 = list22.tail;
      let $ = compare5(first1, first2);
      if ($ instanceof Lt) {
        loop$list1 = rest1;
        loop$list2 = list22;
        loop$compare = compare5;
        loop$acc = prepend(first1, acc);
      } else if ($ instanceof Gt) {
        loop$list1 = list1;
        loop$list2 = rest2;
        loop$compare = compare5;
        loop$acc = prepend(first2, acc);
      } else {
        loop$list1 = list1;
        loop$list2 = rest2;
        loop$compare = compare5;
        loop$acc = prepend(first2, acc);
      }
    }
  }
}
function merge_ascending_pairs(loop$sequences, loop$compare, loop$acc) {
  while (true) {
    let sequences2 = loop$sequences;
    let compare5 = loop$compare;
    let acc = loop$acc;
    if (sequences2.hasLength(0)) {
      return reverse(acc);
    } else if (sequences2.hasLength(1)) {
      let sequence = sequences2.head;
      return reverse(prepend(reverse(sequence), acc));
    } else {
      let ascending1 = sequences2.head;
      let ascending2 = sequences2.tail.head;
      let rest$1 = sequences2.tail.tail;
      let descending = merge_ascendings(
        ascending1,
        ascending2,
        compare5,
        toList([])
      );
      loop$sequences = rest$1;
      loop$compare = compare5;
      loop$acc = prepend(descending, acc);
    }
  }
}
function merge_descendings(loop$list1, loop$list2, loop$compare, loop$acc) {
  while (true) {
    let list1 = loop$list1;
    let list22 = loop$list2;
    let compare5 = loop$compare;
    let acc = loop$acc;
    if (list1.hasLength(0)) {
      let list4 = list22;
      return reverse_and_prepend(list4, acc);
    } else if (list22.hasLength(0)) {
      let list4 = list1;
      return reverse_and_prepend(list4, acc);
    } else {
      let first1 = list1.head;
      let rest1 = list1.tail;
      let first2 = list22.head;
      let rest2 = list22.tail;
      let $ = compare5(first1, first2);
      if ($ instanceof Lt) {
        loop$list1 = list1;
        loop$list2 = rest2;
        loop$compare = compare5;
        loop$acc = prepend(first2, acc);
      } else if ($ instanceof Gt) {
        loop$list1 = rest1;
        loop$list2 = list22;
        loop$compare = compare5;
        loop$acc = prepend(first1, acc);
      } else {
        loop$list1 = rest1;
        loop$list2 = list22;
        loop$compare = compare5;
        loop$acc = prepend(first1, acc);
      }
    }
  }
}
function merge_descending_pairs(loop$sequences, loop$compare, loop$acc) {
  while (true) {
    let sequences2 = loop$sequences;
    let compare5 = loop$compare;
    let acc = loop$acc;
    if (sequences2.hasLength(0)) {
      return reverse(acc);
    } else if (sequences2.hasLength(1)) {
      let sequence = sequences2.head;
      return reverse(prepend(reverse(sequence), acc));
    } else {
      let descending1 = sequences2.head;
      let descending2 = sequences2.tail.head;
      let rest$1 = sequences2.tail.tail;
      let ascending = merge_descendings(
        descending1,
        descending2,
        compare5,
        toList([])
      );
      loop$sequences = rest$1;
      loop$compare = compare5;
      loop$acc = prepend(ascending, acc);
    }
  }
}
function merge_all(loop$sequences, loop$direction, loop$compare) {
  while (true) {
    let sequences2 = loop$sequences;
    let direction = loop$direction;
    let compare5 = loop$compare;
    if (sequences2.hasLength(0)) {
      return toList([]);
    } else if (sequences2.hasLength(1) && direction instanceof Ascending) {
      let sequence = sequences2.head;
      return sequence;
    } else if (sequences2.hasLength(1) && direction instanceof Descending) {
      let sequence = sequences2.head;
      return reverse(sequence);
    } else if (direction instanceof Ascending) {
      let sequences$1 = merge_ascending_pairs(sequences2, compare5, toList([]));
      loop$sequences = sequences$1;
      loop$direction = new Descending();
      loop$compare = compare5;
    } else {
      let sequences$1 = merge_descending_pairs(sequences2, compare5, toList([]));
      loop$sequences = sequences$1;
      loop$direction = new Ascending();
      loop$compare = compare5;
    }
  }
}
function sort(list4, compare5) {
  if (list4.hasLength(0)) {
    return toList([]);
  } else if (list4.hasLength(1)) {
    let x2 = list4.head;
    return toList([x2]);
  } else {
    let x2 = list4.head;
    let y = list4.tail.head;
    let rest$1 = list4.tail.tail;
    let _block;
    let $ = compare5(x2, y);
    if ($ instanceof Lt) {
      _block = new Ascending();
    } else if ($ instanceof Eq) {
      _block = new Ascending();
    } else {
      _block = new Descending();
    }
    let direction = _block;
    let sequences$1 = sequences(
      rest$1,
      compare5,
      toList([x2]),
      direction,
      y,
      toList([])
    );
    return merge_all(sequences$1, new Ascending(), compare5);
  }
}
function repeat_loop(loop$item, loop$times, loop$acc) {
  while (true) {
    let item = loop$item;
    let times = loop$times;
    let acc = loop$acc;
    let $ = times <= 0;
    if ($) {
      return acc;
    } else {
      loop$item = item;
      loop$times = times - 1;
      loop$acc = prepend(item, acc);
    }
  }
}
function repeat(a2, times) {
  return repeat_loop(a2, times, toList([]));
}
function key_set_loop(loop$list, loop$key, loop$value, loop$inspected) {
  while (true) {
    let list4 = loop$list;
    let key2 = loop$key;
    let value3 = loop$value;
    let inspected = loop$inspected;
    if (list4.atLeastLength(1) && isEqual(list4.head[0], key2)) {
      let k = list4.head[0];
      let rest$1 = list4.tail;
      return reverse_and_prepend(inspected, prepend([k, value3], rest$1));
    } else if (list4.atLeastLength(1)) {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      loop$list = rest$1;
      loop$key = key2;
      loop$value = value3;
      loop$inspected = prepend(first$1, inspected);
    } else {
      return reverse(prepend([key2, value3], inspected));
    }
  }
}
function key_set(list4, key2, value3) {
  return key_set_loop(list4, key2, value3, toList([]));
}
function partition_loop(loop$list, loop$categorise, loop$trues, loop$falses) {
  while (true) {
    let list4 = loop$list;
    let categorise = loop$categorise;
    let trues = loop$trues;
    let falses = loop$falses;
    if (list4.hasLength(0)) {
      return [reverse(trues), reverse(falses)];
    } else {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      let $ = categorise(first$1);
      if ($) {
        loop$list = rest$1;
        loop$categorise = categorise;
        loop$trues = prepend(first$1, trues);
        loop$falses = falses;
      } else {
        loop$list = rest$1;
        loop$categorise = categorise;
        loop$trues = trues;
        loop$falses = prepend(first$1, falses);
      }
    }
  }
}
function partition(list4, categorise) {
  return partition_loop(list4, categorise, toList([]), toList([]));
}
function reduce(list4, fun) {
  if (list4.hasLength(0)) {
    return new Error(void 0);
  } else {
    let first$1 = list4.head;
    let rest$1 = list4.tail;
    return new Ok(fold(rest$1, first$1, fun));
  }
}
function last(list4) {
  return reduce(list4, (_, elem) => {
    return elem;
  });
}

// build/dev/javascript/gleam_stdlib/gleam/result.mjs
function is_ok(result) {
  if (!result.isOk()) {
    return false;
  } else {
    return true;
  }
}
function map3(result, fun) {
  if (result.isOk()) {
    let x2 = result[0];
    return new Ok(fun(x2));
  } else {
    let e = result[0];
    return new Error(e);
  }
}
function map_error(result, fun) {
  if (result.isOk()) {
    let x2 = result[0];
    return new Ok(x2);
  } else {
    let error2 = result[0];
    return new Error(fun(error2));
  }
}
function try$(result, fun) {
  if (result.isOk()) {
    let x2 = result[0];
    return fun(x2);
  } else {
    let e = result[0];
    return new Error(e);
  }
}
function then$(result, fun) {
  return try$(result, fun);
}
function unwrap2(result, default$) {
  if (result.isOk()) {
    let v = result[0];
    return v;
  } else {
    return default$;
  }
}
function replace_error(result, error2) {
  if (result.isOk()) {
    let x2 = result[0];
    return new Ok(x2);
  } else {
    return new Error(error2);
  }
}
function try_recover(result, fun) {
  if (result.isOk()) {
    let value3 = result[0];
    return new Ok(value3);
  } else {
    let error2 = result[0];
    return fun(error2);
  }
}

// build/dev/javascript/gleam_stdlib/gleam/string_tree.mjs
function reverse2(tree) {
  let _pipe = tree;
  let _pipe$1 = identity(_pipe);
  let _pipe$2 = graphemes(_pipe$1);
  let _pipe$3 = reverse(_pipe$2);
  return concat(_pipe$3);
}

// build/dev/javascript/gleam_stdlib/dict.mjs
var referenceMap = /* @__PURE__ */ new WeakMap();
var tempDataView = /* @__PURE__ */ new DataView(
  /* @__PURE__ */ new ArrayBuffer(8)
);
var referenceUID = 0;
function hashByReference(o) {
  const known = referenceMap.get(o);
  if (known !== void 0) {
    return known;
  }
  const hash = referenceUID++;
  if (referenceUID === 2147483647) {
    referenceUID = 0;
  }
  referenceMap.set(o, hash);
  return hash;
}
function hashMerge(a2, b) {
  return a2 ^ b + 2654435769 + (a2 << 6) + (a2 >> 2) | 0;
}
function hashString(s) {
  let hash = 0;
  const len = s.length;
  for (let i = 0; i < len; i++) {
    hash = Math.imul(31, hash) + s.charCodeAt(i) | 0;
  }
  return hash;
}
function hashNumber(n) {
  tempDataView.setFloat64(0, n);
  const i = tempDataView.getInt32(0);
  const j = tempDataView.getInt32(4);
  return Math.imul(73244475, i >> 16 ^ i) ^ j;
}
function hashBigInt(n) {
  return hashString(n.toString());
}
function hashObject(o) {
  const proto = Object.getPrototypeOf(o);
  if (proto !== null && typeof proto.hashCode === "function") {
    try {
      const code2 = o.hashCode(o);
      if (typeof code2 === "number") {
        return code2;
      }
    } catch {
    }
  }
  if (o instanceof Promise || o instanceof WeakSet || o instanceof WeakMap) {
    return hashByReference(o);
  }
  if (o instanceof Date) {
    return hashNumber(o.getTime());
  }
  let h = 0;
  if (o instanceof ArrayBuffer) {
    o = new Uint8Array(o);
  }
  if (Array.isArray(o) || o instanceof Uint8Array) {
    for (let i = 0; i < o.length; i++) {
      h = Math.imul(31, h) + getHash(o[i]) | 0;
    }
  } else if (o instanceof Set) {
    o.forEach((v) => {
      h = h + getHash(v) | 0;
    });
  } else if (o instanceof Map) {
    o.forEach((v, k) => {
      h = h + hashMerge(getHash(v), getHash(k)) | 0;
    });
  } else {
    const keys2 = Object.keys(o);
    for (let i = 0; i < keys2.length; i++) {
      const k = keys2[i];
      const v = o[k];
      h = h + hashMerge(getHash(v), hashString(k)) | 0;
    }
  }
  return h;
}
function getHash(u) {
  if (u === null) return 1108378658;
  if (u === void 0) return 1108378659;
  if (u === true) return 1108378657;
  if (u === false) return 1108378656;
  switch (typeof u) {
    case "number":
      return hashNumber(u);
    case "string":
      return hashString(u);
    case "bigint":
      return hashBigInt(u);
    case "object":
      return hashObject(u);
    case "symbol":
      return hashByReference(u);
    case "function":
      return hashByReference(u);
    default:
      return 0;
  }
}
var SHIFT = 5;
var BUCKET_SIZE = Math.pow(2, SHIFT);
var MASK = BUCKET_SIZE - 1;
var MAX_INDEX_NODE = BUCKET_SIZE / 2;
var MIN_ARRAY_NODE = BUCKET_SIZE / 4;
var ENTRY = 0;
var ARRAY_NODE = 1;
var INDEX_NODE = 2;
var COLLISION_NODE = 3;
var EMPTY = {
  type: INDEX_NODE,
  bitmap: 0,
  array: []
};
function mask(hash, shift) {
  return hash >>> shift & MASK;
}
function bitpos(hash, shift) {
  return 1 << mask(hash, shift);
}
function bitcount(x2) {
  x2 -= x2 >> 1 & 1431655765;
  x2 = (x2 & 858993459) + (x2 >> 2 & 858993459);
  x2 = x2 + (x2 >> 4) & 252645135;
  x2 += x2 >> 8;
  x2 += x2 >> 16;
  return x2 & 127;
}
function index(bitmap, bit) {
  return bitcount(bitmap & bit - 1);
}
function cloneAndSet(arr, at, val) {
  const len = arr.length;
  const out = new Array(len);
  for (let i = 0; i < len; ++i) {
    out[i] = arr[i];
  }
  out[at] = val;
  return out;
}
function spliceIn(arr, at, val) {
  const len = arr.length;
  const out = new Array(len + 1);
  let i = 0;
  let g = 0;
  while (i < at) {
    out[g++] = arr[i++];
  }
  out[g++] = val;
  while (i < len) {
    out[g++] = arr[i++];
  }
  return out;
}
function spliceOut(arr, at) {
  const len = arr.length;
  const out = new Array(len - 1);
  let i = 0;
  let g = 0;
  while (i < at) {
    out[g++] = arr[i++];
  }
  ++i;
  while (i < len) {
    out[g++] = arr[i++];
  }
  return out;
}
function createNode(shift, key1, val1, key2hash, key2, val2) {
  const key1hash = getHash(key1);
  if (key1hash === key2hash) {
    return {
      type: COLLISION_NODE,
      hash: key1hash,
      array: [
        { type: ENTRY, k: key1, v: val1 },
        { type: ENTRY, k: key2, v: val2 }
      ]
    };
  }
  const addedLeaf = { val: false };
  return assoc(
    assocIndex(EMPTY, shift, key1hash, key1, val1, addedLeaf),
    shift,
    key2hash,
    key2,
    val2,
    addedLeaf
  );
}
function assoc(root3, shift, hash, key2, val, addedLeaf) {
  switch (root3.type) {
    case ARRAY_NODE:
      return assocArray(root3, shift, hash, key2, val, addedLeaf);
    case INDEX_NODE:
      return assocIndex(root3, shift, hash, key2, val, addedLeaf);
    case COLLISION_NODE:
      return assocCollision(root3, shift, hash, key2, val, addedLeaf);
  }
}
function assocArray(root3, shift, hash, key2, val, addedLeaf) {
  const idx = mask(hash, shift);
  const node = root3.array[idx];
  if (node === void 0) {
    addedLeaf.val = true;
    return {
      type: ARRAY_NODE,
      size: root3.size + 1,
      array: cloneAndSet(root3.array, idx, { type: ENTRY, k: key2, v: val })
    };
  }
  if (node.type === ENTRY) {
    if (isEqual(key2, node.k)) {
      if (val === node.v) {
        return root3;
      }
      return {
        type: ARRAY_NODE,
        size: root3.size,
        array: cloneAndSet(root3.array, idx, {
          type: ENTRY,
          k: key2,
          v: val
        })
      };
    }
    addedLeaf.val = true;
    return {
      type: ARRAY_NODE,
      size: root3.size,
      array: cloneAndSet(
        root3.array,
        idx,
        createNode(shift + SHIFT, node.k, node.v, hash, key2, val)
      )
    };
  }
  const n = assoc(node, shift + SHIFT, hash, key2, val, addedLeaf);
  if (n === node) {
    return root3;
  }
  return {
    type: ARRAY_NODE,
    size: root3.size,
    array: cloneAndSet(root3.array, idx, n)
  };
}
function assocIndex(root3, shift, hash, key2, val, addedLeaf) {
  const bit = bitpos(hash, shift);
  const idx = index(root3.bitmap, bit);
  if ((root3.bitmap & bit) !== 0) {
    const node = root3.array[idx];
    if (node.type !== ENTRY) {
      const n = assoc(node, shift + SHIFT, hash, key2, val, addedLeaf);
      if (n === node) {
        return root3;
      }
      return {
        type: INDEX_NODE,
        bitmap: root3.bitmap,
        array: cloneAndSet(root3.array, idx, n)
      };
    }
    const nodeKey = node.k;
    if (isEqual(key2, nodeKey)) {
      if (val === node.v) {
        return root3;
      }
      return {
        type: INDEX_NODE,
        bitmap: root3.bitmap,
        array: cloneAndSet(root3.array, idx, {
          type: ENTRY,
          k: key2,
          v: val
        })
      };
    }
    addedLeaf.val = true;
    return {
      type: INDEX_NODE,
      bitmap: root3.bitmap,
      array: cloneAndSet(
        root3.array,
        idx,
        createNode(shift + SHIFT, nodeKey, node.v, hash, key2, val)
      )
    };
  } else {
    const n = root3.array.length;
    if (n >= MAX_INDEX_NODE) {
      const nodes = new Array(32);
      const jdx = mask(hash, shift);
      nodes[jdx] = assocIndex(EMPTY, shift + SHIFT, hash, key2, val, addedLeaf);
      let j = 0;
      let bitmap = root3.bitmap;
      for (let i = 0; i < 32; i++) {
        if ((bitmap & 1) !== 0) {
          const node = root3.array[j++];
          nodes[i] = node;
        }
        bitmap = bitmap >>> 1;
      }
      return {
        type: ARRAY_NODE,
        size: n + 1,
        array: nodes
      };
    } else {
      const newArray = spliceIn(root3.array, idx, {
        type: ENTRY,
        k: key2,
        v: val
      });
      addedLeaf.val = true;
      return {
        type: INDEX_NODE,
        bitmap: root3.bitmap | bit,
        array: newArray
      };
    }
  }
}
function assocCollision(root3, shift, hash, key2, val, addedLeaf) {
  if (hash === root3.hash) {
    const idx = collisionIndexOf(root3, key2);
    if (idx !== -1) {
      const entry = root3.array[idx];
      if (entry.v === val) {
        return root3;
      }
      return {
        type: COLLISION_NODE,
        hash,
        array: cloneAndSet(root3.array, idx, { type: ENTRY, k: key2, v: val })
      };
    }
    const size2 = root3.array.length;
    addedLeaf.val = true;
    return {
      type: COLLISION_NODE,
      hash,
      array: cloneAndSet(root3.array, size2, { type: ENTRY, k: key2, v: val })
    };
  }
  return assoc(
    {
      type: INDEX_NODE,
      bitmap: bitpos(root3.hash, shift),
      array: [root3]
    },
    shift,
    hash,
    key2,
    val,
    addedLeaf
  );
}
function collisionIndexOf(root3, key2) {
  const size2 = root3.array.length;
  for (let i = 0; i < size2; i++) {
    if (isEqual(key2, root3.array[i].k)) {
      return i;
    }
  }
  return -1;
}
function find2(root3, shift, hash, key2) {
  switch (root3.type) {
    case ARRAY_NODE:
      return findArray(root3, shift, hash, key2);
    case INDEX_NODE:
      return findIndex(root3, shift, hash, key2);
    case COLLISION_NODE:
      return findCollision(root3, key2);
  }
}
function findArray(root3, shift, hash, key2) {
  const idx = mask(hash, shift);
  const node = root3.array[idx];
  if (node === void 0) {
    return void 0;
  }
  if (node.type !== ENTRY) {
    return find2(node, shift + SHIFT, hash, key2);
  }
  if (isEqual(key2, node.k)) {
    return node;
  }
  return void 0;
}
function findIndex(root3, shift, hash, key2) {
  const bit = bitpos(hash, shift);
  if ((root3.bitmap & bit) === 0) {
    return void 0;
  }
  const idx = index(root3.bitmap, bit);
  const node = root3.array[idx];
  if (node.type !== ENTRY) {
    return find2(node, shift + SHIFT, hash, key2);
  }
  if (isEqual(key2, node.k)) {
    return node;
  }
  return void 0;
}
function findCollision(root3, key2) {
  const idx = collisionIndexOf(root3, key2);
  if (idx < 0) {
    return void 0;
  }
  return root3.array[idx];
}
function without(root3, shift, hash, key2) {
  switch (root3.type) {
    case ARRAY_NODE:
      return withoutArray(root3, shift, hash, key2);
    case INDEX_NODE:
      return withoutIndex(root3, shift, hash, key2);
    case COLLISION_NODE:
      return withoutCollision(root3, key2);
  }
}
function withoutArray(root3, shift, hash, key2) {
  const idx = mask(hash, shift);
  const node = root3.array[idx];
  if (node === void 0) {
    return root3;
  }
  let n = void 0;
  if (node.type === ENTRY) {
    if (!isEqual(node.k, key2)) {
      return root3;
    }
  } else {
    n = without(node, shift + SHIFT, hash, key2);
    if (n === node) {
      return root3;
    }
  }
  if (n === void 0) {
    if (root3.size <= MIN_ARRAY_NODE) {
      const arr = root3.array;
      const out = new Array(root3.size - 1);
      let i = 0;
      let j = 0;
      let bitmap = 0;
      while (i < idx) {
        const nv = arr[i];
        if (nv !== void 0) {
          out[j] = nv;
          bitmap |= 1 << i;
          ++j;
        }
        ++i;
      }
      ++i;
      while (i < arr.length) {
        const nv = arr[i];
        if (nv !== void 0) {
          out[j] = nv;
          bitmap |= 1 << i;
          ++j;
        }
        ++i;
      }
      return {
        type: INDEX_NODE,
        bitmap,
        array: out
      };
    }
    return {
      type: ARRAY_NODE,
      size: root3.size - 1,
      array: cloneAndSet(root3.array, idx, n)
    };
  }
  return {
    type: ARRAY_NODE,
    size: root3.size,
    array: cloneAndSet(root3.array, idx, n)
  };
}
function withoutIndex(root3, shift, hash, key2) {
  const bit = bitpos(hash, shift);
  if ((root3.bitmap & bit) === 0) {
    return root3;
  }
  const idx = index(root3.bitmap, bit);
  const node = root3.array[idx];
  if (node.type !== ENTRY) {
    const n = without(node, shift + SHIFT, hash, key2);
    if (n === node) {
      return root3;
    }
    if (n !== void 0) {
      return {
        type: INDEX_NODE,
        bitmap: root3.bitmap,
        array: cloneAndSet(root3.array, idx, n)
      };
    }
    if (root3.bitmap === bit) {
      return void 0;
    }
    return {
      type: INDEX_NODE,
      bitmap: root3.bitmap ^ bit,
      array: spliceOut(root3.array, idx)
    };
  }
  if (isEqual(key2, node.k)) {
    if (root3.bitmap === bit) {
      return void 0;
    }
    return {
      type: INDEX_NODE,
      bitmap: root3.bitmap ^ bit,
      array: spliceOut(root3.array, idx)
    };
  }
  return root3;
}
function withoutCollision(root3, key2) {
  const idx = collisionIndexOf(root3, key2);
  if (idx < 0) {
    return root3;
  }
  if (root3.array.length === 1) {
    return void 0;
  }
  return {
    type: COLLISION_NODE,
    hash: root3.hash,
    array: spliceOut(root3.array, idx)
  };
}
function forEach(root3, fn) {
  if (root3 === void 0) {
    return;
  }
  const items = root3.array;
  const size2 = items.length;
  for (let i = 0; i < size2; i++) {
    const item = items[i];
    if (item === void 0) {
      continue;
    }
    if (item.type === ENTRY) {
      fn(item.v, item.k);
      continue;
    }
    forEach(item, fn);
  }
}
var Dict = class _Dict {
  /**
   * @template V
   * @param {Record<string,V>} o
   * @returns {Dict<string,V>}
   */
  static fromObject(o) {
    const keys2 = Object.keys(o);
    let m = _Dict.new();
    for (let i = 0; i < keys2.length; i++) {
      const k = keys2[i];
      m = m.set(k, o[k]);
    }
    return m;
  }
  /**
   * @template K,V
   * @param {Map<K,V>} o
   * @returns {Dict<K,V>}
   */
  static fromMap(o) {
    let m = _Dict.new();
    o.forEach((v, k) => {
      m = m.set(k, v);
    });
    return m;
  }
  static new() {
    return new _Dict(void 0, 0);
  }
  /**
   * @param {undefined | Node<K,V>} root
   * @param {number} size
   */
  constructor(root3, size2) {
    this.root = root3;
    this.size = size2;
  }
  /**
   * @template NotFound
   * @param {K} key
   * @param {NotFound} notFound
   * @returns {NotFound | V}
   */
  get(key2, notFound) {
    if (this.root === void 0) {
      return notFound;
    }
    const found = find2(this.root, 0, getHash(key2), key2);
    if (found === void 0) {
      return notFound;
    }
    return found.v;
  }
  /**
   * @param {K} key
   * @param {V} val
   * @returns {Dict<K,V>}
   */
  set(key2, val) {
    const addedLeaf = { val: false };
    const root3 = this.root === void 0 ? EMPTY : this.root;
    const newRoot = assoc(root3, 0, getHash(key2), key2, val, addedLeaf);
    if (newRoot === this.root) {
      return this;
    }
    return new _Dict(newRoot, addedLeaf.val ? this.size + 1 : this.size);
  }
  /**
   * @param {K} key
   * @returns {Dict<K,V>}
   */
  delete(key2) {
    if (this.root === void 0) {
      return this;
    }
    const newRoot = without(this.root, 0, getHash(key2), key2);
    if (newRoot === this.root) {
      return this;
    }
    if (newRoot === void 0) {
      return _Dict.new();
    }
    return new _Dict(newRoot, this.size - 1);
  }
  /**
   * @param {K} key
   * @returns {boolean}
   */
  has(key2) {
    if (this.root === void 0) {
      return false;
    }
    return find2(this.root, 0, getHash(key2), key2) !== void 0;
  }
  /**
   * @returns {[K,V][]}
   */
  entries() {
    if (this.root === void 0) {
      return [];
    }
    const result = [];
    this.forEach((v, k) => result.push([k, v]));
    return result;
  }
  /**
   *
   * @param {(val:V,key:K)=>void} fn
   */
  forEach(fn) {
    forEach(this.root, fn);
  }
  hashCode() {
    let h = 0;
    this.forEach((v, k) => {
      h = h + hashMerge(getHash(v), getHash(k)) | 0;
    });
    return h;
  }
  /**
   * @param {unknown} o
   * @returns {boolean}
   */
  equals(o) {
    if (!(o instanceof _Dict) || this.size !== o.size) {
      return false;
    }
    try {
      this.forEach((v, k) => {
        if (!isEqual(o.get(k, !v), v)) {
          throw unequalDictSymbol;
        }
      });
      return true;
    } catch (e) {
      if (e === unequalDictSymbol) {
        return false;
      }
      throw e;
    }
  }
};
var unequalDictSymbol = /* @__PURE__ */ Symbol();

// build/dev/javascript/gleam_stdlib/gleam_stdlib.mjs
var Nil = void 0;
var NOT_FOUND = {};
function identity(x2) {
  return x2;
}
function parse_int(value3) {
  if (/^[-+]?(\d+)$/.test(value3)) {
    return new Ok(parseInt(value3));
  } else {
    return new Error(Nil);
  }
}
function to_string(term) {
  return term.toString();
}
function float_to_string(float2) {
  const string6 = float2.toString().replace("+", "");
  if (string6.indexOf(".") >= 0) {
    return string6;
  } else {
    const index5 = string6.indexOf("e");
    if (index5 >= 0) {
      return string6.slice(0, index5) + ".0" + string6.slice(index5);
    } else {
      return string6 + ".0";
    }
  }
}
function string_replace(string6, target2, substitute) {
  if (typeof string6.replaceAll !== "undefined") {
    return string6.replaceAll(target2, substitute);
  }
  return string6.replace(
    // $& means the whole matched string
    new RegExp(target2.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g"),
    substitute
  );
}
function string_length(string6) {
  if (string6 === "") {
    return 0;
  }
  const iterator = graphemes_iterator(string6);
  if (iterator) {
    let i = 0;
    for (const _ of iterator) {
      i++;
    }
    return i;
  } else {
    return string6.match(/./gsu).length;
  }
}
function graphemes(string6) {
  const iterator = graphemes_iterator(string6);
  if (iterator) {
    return List.fromArray(Array.from(iterator).map((item) => item.segment));
  } else {
    return List.fromArray(string6.match(/./gsu));
  }
}
var segmenter = void 0;
function graphemes_iterator(string6) {
  if (globalThis.Intl && Intl.Segmenter) {
    segmenter ||= new Intl.Segmenter();
    return segmenter.segment(string6)[Symbol.iterator]();
  }
}
function pop_grapheme(string6) {
  let first2;
  const iterator = graphemes_iterator(string6);
  if (iterator) {
    first2 = iterator.next().value?.segment;
  } else {
    first2 = string6.match(/./su)?.[0];
  }
  if (first2) {
    return new Ok([first2, string6.slice(first2.length)]);
  } else {
    return new Error(Nil);
  }
}
function pop_codeunit(str) {
  return [str.charCodeAt(0) | 0, str.slice(1)];
}
function lowercase(string6) {
  return string6.toLowerCase();
}
function split(xs, pattern) {
  return List.fromArray(xs.split(pattern));
}
function concat(xs) {
  let result = "";
  for (const x2 of xs) {
    result = result + x2;
  }
  return result;
}
function string_slice(string6, idx, len) {
  if (len <= 0 || idx >= string6.length) {
    return "";
  }
  const iterator = graphemes_iterator(string6);
  if (iterator) {
    while (idx-- > 0) {
      iterator.next();
    }
    let result = "";
    while (len-- > 0) {
      const v = iterator.next().value;
      if (v === void 0) {
        break;
      }
      result += v.segment;
    }
    return result;
  } else {
    return string6.match(/./gsu).slice(idx, idx + len).join("");
  }
}
function string_codeunit_slice(str, from2, length4) {
  return str.slice(from2, from2 + length4);
}
function contains_string(haystack, needle) {
  return haystack.indexOf(needle) >= 0;
}
function starts_with(haystack, needle) {
  return haystack.startsWith(needle);
}
function split_once(haystack, needle) {
  const index5 = haystack.indexOf(needle);
  if (index5 >= 0) {
    const before = haystack.slice(0, index5);
    const after = haystack.slice(index5 + needle.length);
    return new Ok([before, after]);
  } else {
    return new Error(Nil);
  }
}
var unicode_whitespaces = [
  " ",
  // Space
  "	",
  // Horizontal tab
  "\n",
  // Line feed
  "\v",
  // Vertical tab
  "\f",
  // Form feed
  "\r",
  // Carriage return
  "\x85",
  // Next line
  "\u2028",
  // Line separator
  "\u2029"
  // Paragraph separator
].join("");
var trim_start_regex = /* @__PURE__ */ new RegExp(
  `^[${unicode_whitespaces}]*`
);
var trim_end_regex = /* @__PURE__ */ new RegExp(`[${unicode_whitespaces}]*$`);
function trim_start(string6) {
  return string6.replace(trim_start_regex, "");
}
function trim_end(string6) {
  return string6.replace(trim_end_regex, "");
}
function console_log(term) {
  console.log(term);
}
function print(string6) {
  if (typeof process === "object" && process.stdout?.write) {
    process.stdout.write(string6);
  } else if (typeof Deno === "object") {
    Deno.stdout.writeSync(new TextEncoder().encode(string6));
  } else {
    console.log(string6);
  }
}
function floor(float2) {
  return Math.floor(float2);
}
function round2(float2) {
  return Math.round(float2);
}
function random_uniform() {
  const random_uniform_result = Math.random();
  if (random_uniform_result === 1) {
    return random_uniform();
  }
  return random_uniform_result;
}
function codepoint(int5) {
  return new UtfCodepoint(int5);
}
function string_to_codepoint_integer_list(string6) {
  return List.fromArray(Array.from(string6).map((item) => item.codePointAt(0)));
}
function utf_codepoint_to_int(utf_codepoint) {
  return utf_codepoint.value;
}
function new_map() {
  return Dict.new();
}
function map_remove(key2, map7) {
  return map7.delete(key2);
}
function map_get(map7, key2) {
  const value3 = map7.get(key2, NOT_FOUND);
  if (value3 === NOT_FOUND) {
    return new Error(Nil);
  }
  return new Ok(value3);
}
function map_insert(key2, value3, map7) {
  return map7.set(key2, value3);
}
function classify_dynamic(data2) {
  if (typeof data2 === "string") {
    return "String";
  } else if (typeof data2 === "boolean") {
    return "Bool";
  } else if (data2 instanceof Result) {
    return "Result";
  } else if (data2 instanceof List) {
    return "List";
  } else if (data2 instanceof BitArray) {
    return "BitArray";
  } else if (data2 instanceof Dict) {
    return "Dict";
  } else if (Number.isInteger(data2)) {
    return "Int";
  } else if (Array.isArray(data2)) {
    return `Tuple of ${data2.length} elements`;
  } else if (typeof data2 === "number") {
    return "Float";
  } else if (data2 === null) {
    return "Null";
  } else if (data2 === void 0) {
    return "Nil";
  } else {
    const type = typeof data2;
    return type.charAt(0).toUpperCase() + type.slice(1);
  }
}
function inspect(v) {
  const t = typeof v;
  if (v === true) return "True";
  if (v === false) return "False";
  if (v === null) return "//js(null)";
  if (v === void 0) return "Nil";
  if (t === "string") return inspectString(v);
  if (t === "bigint" || Number.isInteger(v)) return v.toString();
  if (t === "number") return float_to_string(v);
  if (Array.isArray(v)) return `#(${v.map(inspect).join(", ")})`;
  if (v instanceof List) return inspectList(v);
  if (v instanceof UtfCodepoint) return inspectUtfCodepoint(v);
  if (v instanceof BitArray) return `<<${bit_array_inspect(v, "")}>>`;
  if (v instanceof CustomType) return inspectCustomType(v);
  if (v instanceof Dict) return inspectDict(v);
  if (v instanceof Set) return `//js(Set(${[...v].map(inspect).join(", ")}))`;
  if (v instanceof RegExp) return `//js(${v})`;
  if (v instanceof Date) return `//js(Date("${v.toISOString()}"))`;
  if (v instanceof Function) {
    const args = [];
    for (const i of Array(v.length).keys())
      args.push(String.fromCharCode(i + 97));
    return `//fn(${args.join(", ")}) { ... }`;
  }
  return inspectObject(v);
}
function inspectString(str) {
  let new_str = '"';
  for (let i = 0; i < str.length; i++) {
    const char = str[i];
    switch (char) {
      case "\n":
        new_str += "\\n";
        break;
      case "\r":
        new_str += "\\r";
        break;
      case "	":
        new_str += "\\t";
        break;
      case "\f":
        new_str += "\\f";
        break;
      case "\\":
        new_str += "\\\\";
        break;
      case '"':
        new_str += '\\"';
        break;
      default:
        if (char < " " || char > "~" && char < "\xA0") {
          new_str += "\\u{" + char.charCodeAt(0).toString(16).toUpperCase().padStart(4, "0") + "}";
        } else {
          new_str += char;
        }
    }
  }
  new_str += '"';
  return new_str;
}
function inspectDict(map7) {
  let body2 = "dict.from_list([";
  let first2 = true;
  map7.forEach((value3, key2) => {
    if (!first2) body2 = body2 + ", ";
    body2 = body2 + "#(" + inspect(key2) + ", " + inspect(value3) + ")";
    first2 = false;
  });
  return body2 + "])";
}
function inspectObject(v) {
  const name = Object.getPrototypeOf(v)?.constructor?.name || "Object";
  const props = [];
  for (const k of Object.keys(v)) {
    props.push(`${inspect(k)}: ${inspect(v[k])}`);
  }
  const body2 = props.length ? " " + props.join(", ") + " " : "";
  const head = name === "Object" ? "" : name + " ";
  return `//js(${head}{${body2}})`;
}
function inspectCustomType(record) {
  const props = Object.keys(record).map((label) => {
    const value3 = inspect(record[label]);
    return isNaN(parseInt(label)) ? `${label}: ${value3}` : value3;
  }).join(", ");
  return props ? `${record.constructor.name}(${props})` : record.constructor.name;
}
function inspectList(list4) {
  return `[${list4.toArray().map(inspect).join(", ")}]`;
}
function inspectUtfCodepoint(codepoint2) {
  return `//utfcodepoint(${String.fromCodePoint(codepoint2.value)})`;
}
function bit_array_inspect(bits, acc) {
  if (bits.bitSize === 0) {
    return acc;
  }
  for (let i = 0; i < bits.byteSize - 1; i++) {
    acc += bits.byteAt(i).toString();
    acc += ", ";
  }
  if (bits.byteSize * 8 === bits.bitSize) {
    acc += bits.byteAt(bits.byteSize - 1).toString();
  } else {
    const trailingBitsCount = bits.bitSize % 8;
    acc += bits.byteAt(bits.byteSize - 1) >> 8 - trailingBitsCount;
    acc += `:size(${trailingBitsCount})`;
  }
  return acc;
}

// build/dev/javascript/gleam_stdlib/gleam/float.mjs
function negate(x2) {
  return -1 * x2;
}
function round(x2) {
  let $ = x2 >= 0;
  if ($) {
    return round2(x2);
  } else {
    return 0 - round2(negate(x2));
  }
}

// build/dev/javascript/gleam_stdlib/gleam/int.mjs
function min(a2, b) {
  let $ = a2 < b;
  if ($) {
    return a2;
  } else {
    return b;
  }
}
function max(a2, b) {
  let $ = a2 > b;
  if ($) {
    return a2;
  } else {
    return b;
  }
}
function random(max2) {
  let _pipe = random_uniform() * identity(max2);
  let _pipe$1 = floor(_pipe);
  return round(_pipe$1);
}

// build/dev/javascript/gleam_stdlib/gleam/string.mjs
function reverse3(string6) {
  let _pipe = string6;
  let _pipe$1 = identity(_pipe);
  let _pipe$2 = reverse2(_pipe$1);
  return identity(_pipe$2);
}
function replace(string6, pattern, substitute) {
  let _pipe = string6;
  let _pipe$1 = identity(_pipe);
  let _pipe$2 = string_replace(_pipe$1, pattern, substitute);
  return identity(_pipe$2);
}
function slice(string6, idx, len) {
  let $ = len < 0;
  if ($) {
    return "";
  } else {
    let $1 = idx < 0;
    if ($1) {
      let translated_idx = string_length(string6) + idx;
      let $2 = translated_idx < 0;
      if ($2) {
        return "";
      } else {
        return string_slice(string6, translated_idx, len);
      }
    } else {
      return string_slice(string6, idx, len);
    }
  }
}
function append2(first2, second2) {
  return first2 + second2;
}
function concat_loop(loop$strings, loop$accumulator) {
  while (true) {
    let strings = loop$strings;
    let accumulator = loop$accumulator;
    if (strings.atLeastLength(1)) {
      let string6 = strings.head;
      let strings$1 = strings.tail;
      loop$strings = strings$1;
      loop$accumulator = accumulator + string6;
    } else {
      return accumulator;
    }
  }
}
function concat2(strings) {
  return concat_loop(strings, "");
}
function join_loop(loop$strings, loop$separator, loop$accumulator) {
  while (true) {
    let strings = loop$strings;
    let separator = loop$separator;
    let accumulator = loop$accumulator;
    if (strings.hasLength(0)) {
      return accumulator;
    } else {
      let string6 = strings.head;
      let strings$1 = strings.tail;
      loop$strings = strings$1;
      loop$separator = separator;
      loop$accumulator = accumulator + separator + string6;
    }
  }
}
function join(strings, separator) {
  if (strings.hasLength(0)) {
    return "";
  } else {
    let first$1 = strings.head;
    let rest = strings.tail;
    return join_loop(rest, separator, first$1);
  }
}
function trim(string6) {
  let _pipe = string6;
  let _pipe$1 = trim_start(_pipe);
  return trim_end(_pipe$1);
}
function drop_start(loop$string, loop$num_graphemes) {
  while (true) {
    let string6 = loop$string;
    let num_graphemes = loop$num_graphemes;
    let $ = num_graphemes > 0;
    if (!$) {
      return string6;
    } else {
      let $1 = pop_grapheme(string6);
      if ($1.isOk()) {
        let string$1 = $1[0][1];
        loop$string = string$1;
        loop$num_graphemes = num_graphemes - 1;
      } else {
        return string6;
      }
    }
  }
}
function split2(x2, substring) {
  if (substring === "") {
    return graphemes(x2);
  } else {
    let _pipe = x2;
    let _pipe$1 = identity(_pipe);
    let _pipe$2 = split(_pipe$1, substring);
    return map2(_pipe$2, identity);
  }
}
function do_to_utf_codepoints(string6) {
  let _pipe = string6;
  let _pipe$1 = string_to_codepoint_integer_list(_pipe);
  return map2(_pipe$1, codepoint);
}
function to_utf_codepoints(string6) {
  return do_to_utf_codepoints(string6);
}
function inspect2(term) {
  let _pipe = inspect(term);
  return identity(_pipe);
}

// build/dev/javascript/gleam_stdlib/gleam_stdlib_decode_ffi.mjs
function index2(data2, key2) {
  if (data2 instanceof Dict || data2 instanceof WeakMap || data2 instanceof Map) {
    const token2 = {};
    const entry = data2.get(key2, token2);
    if (entry === token2) return new Ok(new None());
    return new Ok(new Some(entry));
  }
  const key_is_int = Number.isInteger(key2);
  if (key_is_int && key2 >= 0 && key2 < 8 && data2 instanceof List) {
    let i = 0;
    for (const value3 of data2) {
      if (i === key2) return new Ok(new Some(value3));
      i++;
    }
    return new Error("Indexable");
  }
  if (key_is_int && Array.isArray(data2) || data2 && typeof data2 === "object" || data2 && Object.getPrototypeOf(data2) === Object.prototype) {
    if (key2 in data2) return new Ok(new Some(data2[key2]));
    return new Ok(new None());
  }
  return new Error(key_is_int ? "Indexable" : "Dict");
}
function list(data2, decode2, pushPath, index5, emptyList) {
  if (!(data2 instanceof List || Array.isArray(data2))) {
    const error2 = new DecodeError2("List", classify_dynamic(data2), emptyList);
    return [emptyList, List.fromArray([error2])];
  }
  const decoded = [];
  for (const element4 of data2) {
    const layer = decode2(element4);
    const [out, errors] = layer;
    if (errors instanceof NonEmpty) {
      const [_, errors2] = pushPath(layer, index5.toString());
      return [emptyList, errors2];
    }
    decoded.push(out);
    index5++;
  }
  return [List.fromArray(decoded), emptyList];
}
function int(data2) {
  if (Number.isInteger(data2)) return new Ok(data2);
  return new Error(0);
}
function string2(data2) {
  if (typeof data2 === "string") return new Ok(data2);
  return new Error("");
}
function is_null(data2) {
  return data2 === null || data2 === void 0;
}

// build/dev/javascript/gleam_stdlib/gleam/dynamic/decode.mjs
var DecodeError2 = class extends CustomType {
  constructor(expected, found, path2) {
    super();
    this.expected = expected;
    this.found = found;
    this.path = path2;
  }
};
var Decoder = class extends CustomType {
  constructor(function$) {
    super();
    this.function = function$;
  }
};
function run(data2, decoder) {
  let $ = decoder.function(data2);
  let maybe_invalid_data = $[0];
  let errors = $[1];
  if (errors.hasLength(0)) {
    return new Ok(maybe_invalid_data);
  } else {
    return new Error(errors);
  }
}
function success(data2) {
  return new Decoder((_) => {
    return [data2, toList([])];
  });
}
function map4(decoder, transformer) {
  return new Decoder(
    (d) => {
      let $ = decoder.function(d);
      let data2 = $[0];
      let errors = $[1];
      return [transformer(data2), errors];
    }
  );
}
function run_decoders(loop$data, loop$failure, loop$decoders) {
  while (true) {
    let data2 = loop$data;
    let failure2 = loop$failure;
    let decoders = loop$decoders;
    if (decoders.hasLength(0)) {
      return failure2;
    } else {
      let decoder = decoders.head;
      let decoders$1 = decoders.tail;
      let $ = decoder.function(data2);
      let layer = $;
      let errors = $[1];
      if (errors.hasLength(0)) {
        return layer;
      } else {
        loop$data = data2;
        loop$failure = failure2;
        loop$decoders = decoders$1;
      }
    }
  }
}
function one_of(first2, alternatives) {
  return new Decoder(
    (dynamic_data) => {
      let $ = first2.function(dynamic_data);
      let layer = $;
      let errors = $[1];
      if (errors.hasLength(0)) {
        return layer;
      } else {
        return run_decoders(dynamic_data, layer, alternatives);
      }
    }
  );
}
function optional(inner) {
  return new Decoder(
    (data2) => {
      let $ = is_null(data2);
      if ($) {
        return [new None(), toList([])];
      } else {
        let $1 = inner.function(data2);
        let data$1 = $1[0];
        let errors = $1[1];
        return [new Some(data$1), errors];
      }
    }
  );
}
function decode_error(expected, found) {
  return toList([
    new DecodeError2(expected, classify_dynamic(found), toList([]))
  ]);
}
function run_dynamic_function(data2, name, f) {
  let $ = f(data2);
  if ($.isOk()) {
    let data$1 = $[0];
    return [data$1, toList([])];
  } else {
    let zero = $[0];
    return [
      zero,
      toList([new DecodeError2(name, classify_dynamic(data2), toList([]))])
    ];
  }
}
function decode_bool2(data2) {
  let $ = isEqual(identity(true), data2);
  if ($) {
    return [true, toList([])];
  } else {
    let $1 = isEqual(identity(false), data2);
    if ($1) {
      return [false, toList([])];
    } else {
      return [false, decode_error("Bool", data2)];
    }
  }
}
function decode_int2(data2) {
  return run_dynamic_function(data2, "Int", int);
}
function failure(zero, expected) {
  return new Decoder((d) => {
    return [zero, decode_error(expected, d)];
  });
}
var bool = /* @__PURE__ */ new Decoder(decode_bool2);
var int2 = /* @__PURE__ */ new Decoder(decode_int2);
function decode_string2(data2) {
  return run_dynamic_function(data2, "String", string2);
}
var string3 = /* @__PURE__ */ new Decoder(decode_string2);
function list2(inner) {
  return new Decoder(
    (data2) => {
      return list(
        data2,
        inner.function,
        (p2, k) => {
          return push_path(p2, toList([k]));
        },
        0,
        toList([])
      );
    }
  );
}
function push_path(layer, path2) {
  let decoder = one_of(
    string3,
    toList([
      (() => {
        let _pipe = int2;
        return map4(_pipe, to_string);
      })()
    ])
  );
  let path$1 = map2(
    path2,
    (key2) => {
      let key$1 = identity(key2);
      let $ = run(key$1, decoder);
      if ($.isOk()) {
        let key$2 = $[0];
        return key$2;
      } else {
        return "<" + classify_dynamic(key$1) + ">";
      }
    }
  );
  let errors = map2(
    layer[1],
    (error2) => {
      let _record = error2;
      return new DecodeError2(
        _record.expected,
        _record.found,
        append(path$1, error2.path)
      );
    }
  );
  return [layer[0], errors];
}
function index3(loop$path, loop$position, loop$inner, loop$data, loop$handle_miss) {
  while (true) {
    let path2 = loop$path;
    let position = loop$position;
    let inner = loop$inner;
    let data2 = loop$data;
    let handle_miss = loop$handle_miss;
    if (path2.hasLength(0)) {
      let _pipe = inner(data2);
      return push_path(_pipe, reverse(position));
    } else {
      let key2 = path2.head;
      let path$1 = path2.tail;
      let $ = index2(data2, key2);
      if ($.isOk() && $[0] instanceof Some) {
        let data$1 = $[0][0];
        loop$path = path$1;
        loop$position = prepend(key2, position);
        loop$inner = inner;
        loop$data = data$1;
        loop$handle_miss = handle_miss;
      } else if ($.isOk() && $[0] instanceof None) {
        return handle_miss(data2, prepend(key2, position));
      } else {
        let kind = $[0];
        let $1 = inner(data2);
        let default$ = $1[0];
        let _pipe = [
          default$,
          toList([new DecodeError2(kind, classify_dynamic(data2), toList([]))])
        ];
        return push_path(_pipe, reverse(position));
      }
    }
  }
}
function subfield(field_path, field_decoder, next) {
  return new Decoder(
    (data2) => {
      let $ = index3(
        field_path,
        toList([]),
        field_decoder.function,
        data2,
        (data3, position) => {
          let $12 = field_decoder.function(data3);
          let default$ = $12[0];
          let _pipe = [
            default$,
            toList([new DecodeError2("Field", "Nothing", toList([]))])
          ];
          return push_path(_pipe, reverse(position));
        }
      );
      let out = $[0];
      let errors1 = $[1];
      let $1 = next(out).function(data2);
      let out$1 = $1[0];
      let errors2 = $1[1];
      return [out$1, append(errors1, errors2)];
    }
  );
}
function field(field_name, field_decoder, next) {
  return subfield(toList([field_name]), field_decoder, next);
}

// build/dev/javascript/gleam_json/gleam_json_ffi.mjs
function json_to_string(json2) {
  return JSON.stringify(json2);
}
function object(entries) {
  return Object.fromEntries(entries);
}
function identity2(x2) {
  return x2;
}
function do_null() {
  return null;
}
function decode(string6) {
  try {
    const result = JSON.parse(string6);
    return new Ok(result);
  } catch (err) {
    return new Error(getJsonDecodeError(err, string6));
  }
}
function getJsonDecodeError(stdErr, json2) {
  if (isUnexpectedEndOfInput(stdErr)) return new UnexpectedEndOfInput();
  return toUnexpectedByteError(stdErr, json2);
}
function isUnexpectedEndOfInput(err) {
  const unexpectedEndOfInputRegex = /((unexpected (end|eof))|(end of data)|(unterminated string)|(json( parse error|\.parse)\: expected '(\:|\}|\])'))/i;
  return unexpectedEndOfInputRegex.test(err.message);
}
function toUnexpectedByteError(err, json2) {
  let converters = [
    v8UnexpectedByteError,
    oldV8UnexpectedByteError,
    jsCoreUnexpectedByteError,
    spidermonkeyUnexpectedByteError
  ];
  for (let converter of converters) {
    let result = converter(err, json2);
    if (result) return result;
  }
  return new UnexpectedByte("", 0);
}
function v8UnexpectedByteError(err) {
  const regex = /unexpected token '(.)', ".+" is not valid JSON/i;
  const match = regex.exec(err.message);
  if (!match) return null;
  const byte = toHex(match[1]);
  return new UnexpectedByte(byte, -1);
}
function oldV8UnexpectedByteError(err) {
  const regex = /unexpected token (.) in JSON at position (\d+)/i;
  const match = regex.exec(err.message);
  if (!match) return null;
  const byte = toHex(match[1]);
  const position = Number(match[2]);
  return new UnexpectedByte(byte, position);
}
function spidermonkeyUnexpectedByteError(err, json2) {
  const regex = /(unexpected character|expected .*) at line (\d+) column (\d+)/i;
  const match = regex.exec(err.message);
  if (!match) return null;
  const line2 = Number(match[2]);
  const column = Number(match[3]);
  const position = getPositionFromMultiline(line2, column, json2);
  const byte = toHex(json2[position]);
  return new UnexpectedByte(byte, position);
}
function jsCoreUnexpectedByteError(err) {
  const regex = /unexpected (identifier|token) "(.)"/i;
  const match = regex.exec(err.message);
  if (!match) return null;
  const byte = toHex(match[2]);
  return new UnexpectedByte(byte, 0);
}
function toHex(char) {
  return "0x" + char.charCodeAt(0).toString(16).toUpperCase();
}
function getPositionFromMultiline(line2, column, string6) {
  if (line2 === 1) return column - 1;
  let currentLn = 1;
  let position = 0;
  string6.split("").find((char, idx) => {
    if (char === "\n") currentLn += 1;
    if (currentLn === line2) {
      position = idx + column;
      return true;
    }
    return false;
  });
  return position;
}

// build/dev/javascript/gleam_json/gleam/json.mjs
var UnexpectedEndOfInput = class extends CustomType {
};
var UnexpectedByte = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var UnableToDecode = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
function do_parse(json2, decoder) {
  return then$(
    decode(json2),
    (dynamic_value) => {
      let _pipe = run(dynamic_value, decoder);
      return map_error(
        _pipe,
        (var0) => {
          return new UnableToDecode(var0);
        }
      );
    }
  );
}
function parse(json2, decoder) {
  return do_parse(json2, decoder);
}
function to_string2(json2) {
  return json_to_string(json2);
}
function string4(input2) {
  return identity2(input2);
}
function int3(input2) {
  return identity2(input2);
}
function null$() {
  return do_null();
}
function nullable(input2, inner_type) {
  if (input2 instanceof Some) {
    let value3 = input2[0];
    return inner_type(value3);
  } else {
    return null$();
  }
}
function object2(entries) {
  return object(entries);
}

// build/dev/javascript/gleam_stdlib/gleam/uri.mjs
var Uri = class extends CustomType {
  constructor(scheme, userinfo, host, port, path2, query, fragment3) {
    super();
    this.scheme = scheme;
    this.userinfo = userinfo;
    this.host = host;
    this.port = port;
    this.path = path2;
    this.query = query;
    this.fragment = fragment3;
  }
};
function is_valid_host_within_brackets_char(char) {
  return 48 >= char && char <= 57 || 65 >= char && char <= 90 || 97 >= char && char <= 122 || char === 58 || char === 46;
}
function parse_fragment(rest, pieces) {
  return new Ok(
    (() => {
      let _record = pieces;
      return new Uri(
        _record.scheme,
        _record.userinfo,
        _record.host,
        _record.port,
        _record.path,
        _record.query,
        new Some(rest)
      );
    })()
  );
}
function parse_query_with_question_mark_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size2 = loop$size;
    if (uri_string.startsWith("#") && size2 === 0) {
      let rest = uri_string.slice(1);
      return parse_fragment(rest, pieces);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      let query = string_codeunit_slice(original, 0, size2);
      let _block;
      let _record = pieces;
      _block = new Uri(
        _record.scheme,
        _record.userinfo,
        _record.host,
        _record.port,
        _record.path,
        new Some(query),
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_fragment(rest, pieces$1);
    } else if (uri_string === "") {
      return new Ok(
        (() => {
          let _record = pieces;
          return new Uri(
            _record.scheme,
            _record.userinfo,
            _record.host,
            _record.port,
            _record.path,
            new Some(original),
            _record.fragment
          );
        })()
      );
    } else {
      let $ = pop_codeunit(uri_string);
      let rest = $[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size2 + 1;
    }
  }
}
function parse_query_with_question_mark(uri_string, pieces) {
  return parse_query_with_question_mark_loop(uri_string, uri_string, pieces, 0);
}
function parse_path_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size2 = loop$size;
    if (uri_string.startsWith("?")) {
      let rest = uri_string.slice(1);
      let path2 = string_codeunit_slice(original, 0, size2);
      let _block;
      let _record = pieces;
      _block = new Uri(
        _record.scheme,
        _record.userinfo,
        _record.host,
        _record.port,
        path2,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_query_with_question_mark(rest, pieces$1);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      let path2 = string_codeunit_slice(original, 0, size2);
      let _block;
      let _record = pieces;
      _block = new Uri(
        _record.scheme,
        _record.userinfo,
        _record.host,
        _record.port,
        path2,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_fragment(rest, pieces$1);
    } else if (uri_string === "") {
      return new Ok(
        (() => {
          let _record = pieces;
          return new Uri(
            _record.scheme,
            _record.userinfo,
            _record.host,
            _record.port,
            original,
            _record.query,
            _record.fragment
          );
        })()
      );
    } else {
      let $ = pop_codeunit(uri_string);
      let rest = $[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size2 + 1;
    }
  }
}
function parse_path(uri_string, pieces) {
  return parse_path_loop(uri_string, uri_string, pieces, 0);
}
function parse_port_loop(loop$uri_string, loop$pieces, loop$port) {
  while (true) {
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let port = loop$port;
    if (uri_string.startsWith("0")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10;
    } else if (uri_string.startsWith("1")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 1;
    } else if (uri_string.startsWith("2")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 2;
    } else if (uri_string.startsWith("3")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 3;
    } else if (uri_string.startsWith("4")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 4;
    } else if (uri_string.startsWith("5")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 5;
    } else if (uri_string.startsWith("6")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 6;
    } else if (uri_string.startsWith("7")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 7;
    } else if (uri_string.startsWith("8")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 8;
    } else if (uri_string.startsWith("9")) {
      let rest = uri_string.slice(1);
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$port = port * 10 + 9;
    } else if (uri_string.startsWith("?")) {
      let rest = uri_string.slice(1);
      let _block;
      let _record = pieces;
      _block = new Uri(
        _record.scheme,
        _record.userinfo,
        _record.host,
        new Some(port),
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_query_with_question_mark(rest, pieces$1);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      let _block;
      let _record = pieces;
      _block = new Uri(
        _record.scheme,
        _record.userinfo,
        _record.host,
        new Some(port),
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_fragment(rest, pieces$1);
    } else if (uri_string.startsWith("/")) {
      let _block;
      let _record = pieces;
      _block = new Uri(
        _record.scheme,
        _record.userinfo,
        _record.host,
        new Some(port),
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_path(uri_string, pieces$1);
    } else if (uri_string === "") {
      return new Ok(
        (() => {
          let _record = pieces;
          return new Uri(
            _record.scheme,
            _record.userinfo,
            _record.host,
            new Some(port),
            _record.path,
            _record.query,
            _record.fragment
          );
        })()
      );
    } else {
      return new Error(void 0);
    }
  }
}
function parse_port(uri_string, pieces) {
  if (uri_string.startsWith(":0")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 0);
  } else if (uri_string.startsWith(":1")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 1);
  } else if (uri_string.startsWith(":2")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 2);
  } else if (uri_string.startsWith(":3")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 3);
  } else if (uri_string.startsWith(":4")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 4);
  } else if (uri_string.startsWith(":5")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 5);
  } else if (uri_string.startsWith(":6")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 6);
  } else if (uri_string.startsWith(":7")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 7);
  } else if (uri_string.startsWith(":8")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 8);
  } else if (uri_string.startsWith(":9")) {
    let rest = uri_string.slice(2);
    return parse_port_loop(rest, pieces, 9);
  } else if (uri_string.startsWith(":")) {
    return new Error(void 0);
  } else if (uri_string.startsWith("?")) {
    let rest = uri_string.slice(1);
    return parse_query_with_question_mark(rest, pieces);
  } else if (uri_string.startsWith("#")) {
    let rest = uri_string.slice(1);
    return parse_fragment(rest, pieces);
  } else if (uri_string.startsWith("/")) {
    return parse_path(uri_string, pieces);
  } else if (uri_string === "") {
    return new Ok(pieces);
  } else {
    return new Error(void 0);
  }
}
function parse_host_outside_of_brackets_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size2 = loop$size;
    if (uri_string === "") {
      return new Ok(
        (() => {
          let _record = pieces;
          return new Uri(
            _record.scheme,
            _record.userinfo,
            new Some(original),
            _record.port,
            _record.path,
            _record.query,
            _record.fragment
          );
        })()
      );
    } else if (uri_string.startsWith(":")) {
      let host = string_codeunit_slice(original, 0, size2);
      let _block;
      let _record = pieces;
      _block = new Uri(
        _record.scheme,
        _record.userinfo,
        new Some(host),
        _record.port,
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_port(uri_string, pieces$1);
    } else if (uri_string.startsWith("/")) {
      let host = string_codeunit_slice(original, 0, size2);
      let _block;
      let _record = pieces;
      _block = new Uri(
        _record.scheme,
        _record.userinfo,
        new Some(host),
        _record.port,
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_path(uri_string, pieces$1);
    } else if (uri_string.startsWith("?")) {
      let rest = uri_string.slice(1);
      let host = string_codeunit_slice(original, 0, size2);
      let _block;
      let _record = pieces;
      _block = new Uri(
        _record.scheme,
        _record.userinfo,
        new Some(host),
        _record.port,
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_query_with_question_mark(rest, pieces$1);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      let host = string_codeunit_slice(original, 0, size2);
      let _block;
      let _record = pieces;
      _block = new Uri(
        _record.scheme,
        _record.userinfo,
        new Some(host),
        _record.port,
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_fragment(rest, pieces$1);
    } else {
      let $ = pop_codeunit(uri_string);
      let rest = $[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size2 + 1;
    }
  }
}
function parse_host_within_brackets_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size2 = loop$size;
    if (uri_string === "") {
      return new Ok(
        (() => {
          let _record = pieces;
          return new Uri(
            _record.scheme,
            _record.userinfo,
            new Some(uri_string),
            _record.port,
            _record.path,
            _record.query,
            _record.fragment
          );
        })()
      );
    } else if (uri_string.startsWith("]") && size2 === 0) {
      let rest = uri_string.slice(1);
      return parse_port(rest, pieces);
    } else if (uri_string.startsWith("]")) {
      let rest = uri_string.slice(1);
      let host = string_codeunit_slice(original, 0, size2 + 1);
      let _block;
      let _record = pieces;
      _block = new Uri(
        _record.scheme,
        _record.userinfo,
        new Some(host),
        _record.port,
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_port(rest, pieces$1);
    } else if (uri_string.startsWith("/") && size2 === 0) {
      return parse_path(uri_string, pieces);
    } else if (uri_string.startsWith("/")) {
      let host = string_codeunit_slice(original, 0, size2);
      let _block;
      let _record = pieces;
      _block = new Uri(
        _record.scheme,
        _record.userinfo,
        new Some(host),
        _record.port,
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_path(uri_string, pieces$1);
    } else if (uri_string.startsWith("?") && size2 === 0) {
      let rest = uri_string.slice(1);
      return parse_query_with_question_mark(rest, pieces);
    } else if (uri_string.startsWith("?")) {
      let rest = uri_string.slice(1);
      let host = string_codeunit_slice(original, 0, size2);
      let _block;
      let _record = pieces;
      _block = new Uri(
        _record.scheme,
        _record.userinfo,
        new Some(host),
        _record.port,
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_query_with_question_mark(rest, pieces$1);
    } else if (uri_string.startsWith("#") && size2 === 0) {
      let rest = uri_string.slice(1);
      return parse_fragment(rest, pieces);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      let host = string_codeunit_slice(original, 0, size2);
      let _block;
      let _record = pieces;
      _block = new Uri(
        _record.scheme,
        _record.userinfo,
        new Some(host),
        _record.port,
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_fragment(rest, pieces$1);
    } else {
      let $ = pop_codeunit(uri_string);
      let char = $[0];
      let rest = $[1];
      let $1 = is_valid_host_within_brackets_char(char);
      if ($1) {
        loop$original = original;
        loop$uri_string = rest;
        loop$pieces = pieces;
        loop$size = size2 + 1;
      } else {
        return parse_host_outside_of_brackets_loop(
          original,
          original,
          pieces,
          0
        );
      }
    }
  }
}
function parse_host_within_brackets(uri_string, pieces) {
  return parse_host_within_brackets_loop(uri_string, uri_string, pieces, 0);
}
function parse_host_outside_of_brackets(uri_string, pieces) {
  return parse_host_outside_of_brackets_loop(uri_string, uri_string, pieces, 0);
}
function parse_host(uri_string, pieces) {
  if (uri_string.startsWith("[")) {
    return parse_host_within_brackets(uri_string, pieces);
  } else if (uri_string.startsWith(":")) {
    let _block;
    let _record = pieces;
    _block = new Uri(
      _record.scheme,
      _record.userinfo,
      new Some(""),
      _record.port,
      _record.path,
      _record.query,
      _record.fragment
    );
    let pieces$1 = _block;
    return parse_port(uri_string, pieces$1);
  } else if (uri_string === "") {
    return new Ok(
      (() => {
        let _record = pieces;
        return new Uri(
          _record.scheme,
          _record.userinfo,
          new Some(""),
          _record.port,
          _record.path,
          _record.query,
          _record.fragment
        );
      })()
    );
  } else {
    return parse_host_outside_of_brackets(uri_string, pieces);
  }
}
function parse_userinfo_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size2 = loop$size;
    if (uri_string.startsWith("@") && size2 === 0) {
      let rest = uri_string.slice(1);
      return parse_host(rest, pieces);
    } else if (uri_string.startsWith("@")) {
      let rest = uri_string.slice(1);
      let userinfo = string_codeunit_slice(original, 0, size2);
      let _block;
      let _record = pieces;
      _block = new Uri(
        _record.scheme,
        new Some(userinfo),
        _record.host,
        _record.port,
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_host(rest, pieces$1);
    } else if (uri_string === "") {
      return parse_host(original, pieces);
    } else if (uri_string.startsWith("/")) {
      return parse_host(original, pieces);
    } else if (uri_string.startsWith("?")) {
      return parse_host(original, pieces);
    } else if (uri_string.startsWith("#")) {
      return parse_host(original, pieces);
    } else {
      let $ = pop_codeunit(uri_string);
      let rest = $[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size2 + 1;
    }
  }
}
function parse_authority_pieces(string6, pieces) {
  return parse_userinfo_loop(string6, string6, pieces, 0);
}
function parse_authority_with_slashes(uri_string, pieces) {
  if (uri_string === "//") {
    return new Ok(
      (() => {
        let _record = pieces;
        return new Uri(
          _record.scheme,
          _record.userinfo,
          new Some(""),
          _record.port,
          _record.path,
          _record.query,
          _record.fragment
        );
      })()
    );
  } else if (uri_string.startsWith("//")) {
    let rest = uri_string.slice(2);
    return parse_authority_pieces(rest, pieces);
  } else {
    return parse_path(uri_string, pieces);
  }
}
function parse_scheme_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size2 = loop$size;
    if (uri_string.startsWith("/") && size2 === 0) {
      return parse_authority_with_slashes(uri_string, pieces);
    } else if (uri_string.startsWith("/")) {
      let scheme = string_codeunit_slice(original, 0, size2);
      let _block;
      let _record = pieces;
      _block = new Uri(
        new Some(lowercase(scheme)),
        _record.userinfo,
        _record.host,
        _record.port,
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_authority_with_slashes(uri_string, pieces$1);
    } else if (uri_string.startsWith("?") && size2 === 0) {
      let rest = uri_string.slice(1);
      return parse_query_with_question_mark(rest, pieces);
    } else if (uri_string.startsWith("?")) {
      let rest = uri_string.slice(1);
      let scheme = string_codeunit_slice(original, 0, size2);
      let _block;
      let _record = pieces;
      _block = new Uri(
        new Some(lowercase(scheme)),
        _record.userinfo,
        _record.host,
        _record.port,
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_query_with_question_mark(rest, pieces$1);
    } else if (uri_string.startsWith("#") && size2 === 0) {
      let rest = uri_string.slice(1);
      return parse_fragment(rest, pieces);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      let scheme = string_codeunit_slice(original, 0, size2);
      let _block;
      let _record = pieces;
      _block = new Uri(
        new Some(lowercase(scheme)),
        _record.userinfo,
        _record.host,
        _record.port,
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_fragment(rest, pieces$1);
    } else if (uri_string.startsWith(":") && size2 === 0) {
      return new Error(void 0);
    } else if (uri_string.startsWith(":")) {
      let rest = uri_string.slice(1);
      let scheme = string_codeunit_slice(original, 0, size2);
      let _block;
      let _record = pieces;
      _block = new Uri(
        new Some(lowercase(scheme)),
        _record.userinfo,
        _record.host,
        _record.port,
        _record.path,
        _record.query,
        _record.fragment
      );
      let pieces$1 = _block;
      return parse_authority_with_slashes(rest, pieces$1);
    } else if (uri_string === "") {
      return new Ok(
        (() => {
          let _record = pieces;
          return new Uri(
            _record.scheme,
            _record.userinfo,
            _record.host,
            _record.port,
            original,
            _record.query,
            _record.fragment
          );
        })()
      );
    } else {
      let $ = pop_codeunit(uri_string);
      let rest = $[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size2 + 1;
    }
  }
}
function remove_dot_segments_loop(loop$input, loop$accumulator) {
  while (true) {
    let input2 = loop$input;
    let accumulator = loop$accumulator;
    if (input2.hasLength(0)) {
      return reverse(accumulator);
    } else {
      let segment = input2.head;
      let rest = input2.tail;
      let _block;
      if (segment === "") {
        let accumulator$12 = accumulator;
        _block = accumulator$12;
      } else if (segment === ".") {
        let accumulator$12 = accumulator;
        _block = accumulator$12;
      } else if (segment === ".." && accumulator.hasLength(0)) {
        _block = toList([]);
      } else if (segment === ".." && accumulator.atLeastLength(1)) {
        let accumulator$12 = accumulator.tail;
        _block = accumulator$12;
      } else {
        let segment$1 = segment;
        let accumulator$12 = accumulator;
        _block = prepend(segment$1, accumulator$12);
      }
      let accumulator$1 = _block;
      loop$input = rest;
      loop$accumulator = accumulator$1;
    }
  }
}
function remove_dot_segments(input2) {
  return remove_dot_segments_loop(input2, toList([]));
}
function path_segments(path2) {
  return remove_dot_segments(split2(path2, "/"));
}
function to_string3(uri) {
  let _block;
  let $ = uri.fragment;
  if ($ instanceof Some) {
    let fragment3 = $[0];
    _block = toList(["#", fragment3]);
  } else {
    _block = toList([]);
  }
  let parts = _block;
  let _block$1;
  let $1 = uri.query;
  if ($1 instanceof Some) {
    let query = $1[0];
    _block$1 = prepend("?", prepend(query, parts));
  } else {
    _block$1 = parts;
  }
  let parts$1 = _block$1;
  let parts$2 = prepend(uri.path, parts$1);
  let _block$2;
  let $2 = uri.host;
  let $3 = starts_with(uri.path, "/");
  if ($2 instanceof Some && !$3 && $2[0] !== "") {
    let host = $2[0];
    _block$2 = prepend("/", parts$2);
  } else {
    _block$2 = parts$2;
  }
  let parts$3 = _block$2;
  let _block$3;
  let $4 = uri.host;
  let $5 = uri.port;
  if ($4 instanceof Some && $5 instanceof Some) {
    let port = $5[0];
    _block$3 = prepend(":", prepend(to_string(port), parts$3));
  } else {
    _block$3 = parts$3;
  }
  let parts$4 = _block$3;
  let _block$4;
  let $6 = uri.scheme;
  let $7 = uri.userinfo;
  let $8 = uri.host;
  if ($6 instanceof Some && $7 instanceof Some && $8 instanceof Some) {
    let s = $6[0];
    let u = $7[0];
    let h = $8[0];
    _block$4 = prepend(
      s,
      prepend(
        "://",
        prepend(u, prepend("@", prepend(h, parts$4)))
      )
    );
  } else if ($6 instanceof Some && $7 instanceof None && $8 instanceof Some) {
    let s = $6[0];
    let h = $8[0];
    _block$4 = prepend(s, prepend("://", prepend(h, parts$4)));
  } else if ($6 instanceof Some && $7 instanceof Some && $8 instanceof None) {
    let s = $6[0];
    _block$4 = prepend(s, prepend(":", parts$4));
  } else if ($6 instanceof Some && $7 instanceof None && $8 instanceof None) {
    let s = $6[0];
    _block$4 = prepend(s, prepend(":", parts$4));
  } else if ($6 instanceof None && $7 instanceof None && $8 instanceof Some) {
    let h = $8[0];
    _block$4 = prepend("//", prepend(h, parts$4));
  } else {
    _block$4 = parts$4;
  }
  let parts$5 = _block$4;
  return concat2(parts$5);
}
var empty = /* @__PURE__ */ new Uri(
  /* @__PURE__ */ new None(),
  /* @__PURE__ */ new None(),
  /* @__PURE__ */ new None(),
  /* @__PURE__ */ new None(),
  "",
  /* @__PURE__ */ new None(),
  /* @__PURE__ */ new None()
);
function parse2(uri_string) {
  return parse_scheme_loop(uri_string, uri_string, empty, 0);
}

// build/dev/javascript/gleam_stdlib/gleam/bool.mjs
function guard(requirement, consequence, alternative) {
  if (requirement) {
    return consequence;
  } else {
    return alternative();
  }
}

// build/dev/javascript/gleam_stdlib/gleam/function.mjs
function identity3(x2) {
  return x2;
}

// build/dev/javascript/gleam_stdlib/gleam/set.mjs
var Set2 = class extends CustomType {
  constructor(dict2) {
    super();
    this.dict = dict2;
  }
};
function new$() {
  return new Set2(new_map());
}
function contains2(set, member) {
  let _pipe = set.dict;
  let _pipe$1 = map_get(_pipe, member);
  return is_ok(_pipe$1);
}
function delete$2(set, member) {
  return new Set2(delete$(set.dict, member));
}
var token = void 0;
function insert2(set, member) {
  return new Set2(insert(set.dict, member, token));
}

// build/dev/javascript/lustre/lustre/internals/constants.ffi.mjs
var EMPTY_DICT = /* @__PURE__ */ Dict.new();
function empty_dict() {
  return EMPTY_DICT;
}
var EMPTY_SET = /* @__PURE__ */ new$();
function empty_set() {
  return EMPTY_SET;
}
var document2 = globalThis?.document;
var NAMESPACE_HTML = "http://www.w3.org/1999/xhtml";
var ELEMENT_NODE = 1;
var TEXT_NODE = 3;
var DOCUMENT_FRAGMENT_NODE = 11;
var SUPPORTS_MOVE_BEFORE = !!globalThis.HTMLElement?.prototype?.moveBefore;

// build/dev/javascript/lustre/lustre/internals/constants.mjs
var empty_list = /* @__PURE__ */ toList([]);
var option_none = /* @__PURE__ */ new None();

// build/dev/javascript/lustre/lustre/vdom/vattr.ffi.mjs
var GT = /* @__PURE__ */ new Gt();
var LT = /* @__PURE__ */ new Lt();
var EQ = /* @__PURE__ */ new Eq();
function compare3(a2, b) {
  if (a2.name === b.name) {
    return EQ;
  } else if (a2.name < b.name) {
    return LT;
  } else {
    return GT;
  }
}

// build/dev/javascript/lustre/lustre/vdom/vattr.mjs
var Attribute = class extends CustomType {
  constructor(kind, name, value3) {
    super();
    this.kind = kind;
    this.name = name;
    this.value = value3;
  }
};
var Property = class extends CustomType {
  constructor(kind, name, value3) {
    super();
    this.kind = kind;
    this.name = name;
    this.value = value3;
  }
};
var Event2 = class extends CustomType {
  constructor(kind, name, handler, include, prevent_default2, stop_propagation2, immediate2, limit) {
    super();
    this.kind = kind;
    this.name = name;
    this.handler = handler;
    this.include = include;
    this.prevent_default = prevent_default2;
    this.stop_propagation = stop_propagation2;
    this.immediate = immediate2;
    this.limit = limit;
  }
};
var NoLimit = class extends CustomType {
  constructor(kind) {
    super();
    this.kind = kind;
  }
};
var Debounce = class extends CustomType {
  constructor(kind, delay) {
    super();
    this.kind = kind;
    this.delay = delay;
  }
};
var Throttle = class extends CustomType {
  constructor(kind, delay) {
    super();
    this.kind = kind;
    this.delay = delay;
  }
};
function limit_equals(a2, b) {
  if (a2 instanceof NoLimit && b instanceof NoLimit) {
    return true;
  } else if (a2 instanceof Debounce && b instanceof Debounce && a2.delay === b.delay) {
    let d1 = a2.delay;
    let d2 = b.delay;
    return true;
  } else if (a2 instanceof Throttle && b instanceof Throttle && a2.delay === b.delay) {
    let d1 = a2.delay;
    let d2 = b.delay;
    return true;
  } else {
    return false;
  }
}
function merge(loop$attributes, loop$merged) {
  while (true) {
    let attributes = loop$attributes;
    let merged = loop$merged;
    if (attributes.hasLength(0)) {
      return merged;
    } else if (attributes.atLeastLength(2) && attributes.head instanceof Attribute && attributes.head.name === "class" && attributes.tail.head instanceof Attribute && attributes.tail.head.name === "class") {
      let kind = attributes.head.kind;
      let class1 = attributes.head.value;
      let class2 = attributes.tail.head.value;
      let rest = attributes.tail.tail;
      let value3 = class1 + " " + class2;
      let attribute$1 = new Attribute(kind, "class", value3);
      loop$attributes = prepend(attribute$1, rest);
      loop$merged = merged;
    } else if (attributes.atLeastLength(2) && attributes.head instanceof Attribute && attributes.head.name === "style" && attributes.tail.head instanceof Attribute && attributes.tail.head.name === "style") {
      let kind = attributes.head.kind;
      let style1 = attributes.head.value;
      let style22 = attributes.tail.head.value;
      let rest = attributes.tail.tail;
      let value3 = style1 + ";" + style22;
      let attribute$1 = new Attribute(kind, "style", value3);
      loop$attributes = prepend(attribute$1, rest);
      loop$merged = merged;
    } else {
      let attribute$1 = attributes.head;
      let rest = attributes.tail;
      loop$attributes = rest;
      loop$merged = prepend(attribute$1, merged);
    }
  }
}
function prepare(attributes) {
  if (attributes.hasLength(0)) {
    return attributes;
  } else if (attributes.hasLength(1)) {
    return attributes;
  } else {
    let _pipe = attributes;
    let _pipe$1 = sort(_pipe, (a2, b) => {
      return compare3(b, a2);
    });
    return merge(_pipe$1, empty_list);
  }
}
var attribute_kind = 0;
function attribute(name, value3) {
  return new Attribute(attribute_kind, name, value3);
}
var property_kind = 1;
var event_kind = 2;
function event(name, handler, include, prevent_default2, stop_propagation2, immediate2, limit) {
  return new Event2(
    event_kind,
    name,
    handler,
    include,
    prevent_default2,
    stop_propagation2,
    immediate2,
    limit
  );
}
var debounce_kind = 1;
var throttle_kind = 2;

// build/dev/javascript/lustre/lustre/attribute.mjs
function attribute2(name, value3) {
  return attribute(name, value3);
}
function class$(name) {
  return attribute2("class", name);
}
function data(key2, value3) {
  return attribute2("data-" + key2, value3);
}
function id(value3) {
  return attribute2("id", value3);
}
function style(property2, value3) {
  if (property2 === "") {
    return class$("");
  } else if (value3 === "") {
    return class$("");
  } else {
    return attribute2("style", property2 + ":" + value3 + ";");
  }
}
function href(url) {
  return attribute2("href", url);
}
function rel(value3) {
  return attribute2("rel", value3);
}
function placeholder(text4) {
  return attribute2("placeholder", text4);
}
function value(control_value) {
  return attribute2("value", control_value);
}

// build/dev/javascript/lustre/lustre/effect.mjs
var Effect = class extends CustomType {
  constructor(synchronous, before_paint2, after_paint) {
    super();
    this.synchronous = synchronous;
    this.before_paint = before_paint2;
    this.after_paint = after_paint;
  }
};
var empty2 = /* @__PURE__ */ new Effect(
  /* @__PURE__ */ toList([]),
  /* @__PURE__ */ toList([]),
  /* @__PURE__ */ toList([])
);
function none() {
  return empty2;
}
function from(effect) {
  let task = (actions) => {
    let dispatch = actions.dispatch;
    return effect(dispatch);
  };
  let _record = empty2;
  return new Effect(toList([task]), _record.before_paint, _record.after_paint);
}
function batch(effects) {
  return fold(
    effects,
    empty2,
    (acc, eff) => {
      return new Effect(
        fold(eff.synchronous, acc.synchronous, prepend2),
        fold(eff.before_paint, acc.before_paint, prepend2),
        fold(eff.after_paint, acc.after_paint, prepend2)
      );
    }
  );
}

// build/dev/javascript/lustre/lustre/internals/mutable_map.ffi.mjs
function empty3() {
  return null;
}
function get(map7, key2) {
  const value3 = map7?.get(key2);
  if (value3 != null) {
    return new Ok(value3);
  } else {
    return new Error(void 0);
  }
}
function insert3(map7, key2, value3) {
  map7 ??= /* @__PURE__ */ new Map();
  map7.set(key2, value3);
  return map7;
}
function remove(map7, key2) {
  map7?.delete(key2);
  return map7;
}

// build/dev/javascript/lustre/lustre/vdom/path.mjs
var Root = class extends CustomType {
};
var Key = class extends CustomType {
  constructor(key2, parent) {
    super();
    this.key = key2;
    this.parent = parent;
  }
};
var Index = class extends CustomType {
  constructor(index5, parent) {
    super();
    this.index = index5;
    this.parent = parent;
  }
};
function do_matches(loop$path, loop$candidates) {
  while (true) {
    let path2 = loop$path;
    let candidates = loop$candidates;
    if (candidates.hasLength(0)) {
      return false;
    } else {
      let candidate = candidates.head;
      let rest = candidates.tail;
      let $ = starts_with(path2, candidate);
      if ($) {
        return true;
      } else {
        loop$path = path2;
        loop$candidates = rest;
      }
    }
  }
}
function add2(parent, index5, key2) {
  if (key2 === "") {
    return new Index(index5, parent);
  } else {
    return new Key(key2, parent);
  }
}
var root2 = /* @__PURE__ */ new Root();
var separator_index = "\n";
var separator_key = "	";
function do_to_string(loop$path, loop$acc) {
  while (true) {
    let path2 = loop$path;
    let acc = loop$acc;
    if (path2 instanceof Root) {
      if (acc.hasLength(0)) {
        return "";
      } else {
        let segments = acc.tail;
        return concat2(segments);
      }
    } else if (path2 instanceof Key) {
      let key2 = path2.key;
      let parent = path2.parent;
      loop$path = parent;
      loop$acc = prepend(separator_key, prepend(key2, acc));
    } else {
      let index5 = path2.index;
      let parent = path2.parent;
      loop$path = parent;
      loop$acc = prepend(
        separator_index,
        prepend(to_string(index5), acc)
      );
    }
  }
}
function to_string4(path2) {
  return do_to_string(path2, toList([]));
}
function matches(path2, candidates) {
  if (candidates.hasLength(0)) {
    return false;
  } else {
    return do_matches(to_string4(path2), candidates);
  }
}
var separator_event = "\f";
function event2(path2, event4) {
  return do_to_string(path2, toList([separator_event, event4]));
}

// build/dev/javascript/lustre/lustre/vdom/vnode.mjs
var Fragment = class extends CustomType {
  constructor(kind, key2, mapper, children, keyed_children, children_count) {
    super();
    this.kind = kind;
    this.key = key2;
    this.mapper = mapper;
    this.children = children;
    this.keyed_children = keyed_children;
    this.children_count = children_count;
  }
};
var Element2 = class extends CustomType {
  constructor(kind, key2, mapper, namespace2, tag, attributes, children, keyed_children, self_closing, void$) {
    super();
    this.kind = kind;
    this.key = key2;
    this.mapper = mapper;
    this.namespace = namespace2;
    this.tag = tag;
    this.attributes = attributes;
    this.children = children;
    this.keyed_children = keyed_children;
    this.self_closing = self_closing;
    this.void = void$;
  }
};
var Text = class extends CustomType {
  constructor(kind, key2, mapper, content) {
    super();
    this.kind = kind;
    this.key = key2;
    this.mapper = mapper;
    this.content = content;
  }
};
var UnsafeInnerHtml = class extends CustomType {
  constructor(kind, key2, mapper, namespace2, tag, attributes, inner_html) {
    super();
    this.kind = kind;
    this.key = key2;
    this.mapper = mapper;
    this.namespace = namespace2;
    this.tag = tag;
    this.attributes = attributes;
    this.inner_html = inner_html;
  }
};
function is_void_element(tag, namespace2) {
  if (namespace2 === "") {
    if (tag === "area") {
      return true;
    } else if (tag === "base") {
      return true;
    } else if (tag === "br") {
      return true;
    } else if (tag === "col") {
      return true;
    } else if (tag === "embed") {
      return true;
    } else if (tag === "hr") {
      return true;
    } else if (tag === "img") {
      return true;
    } else if (tag === "input") {
      return true;
    } else if (tag === "link") {
      return true;
    } else if (tag === "meta") {
      return true;
    } else if (tag === "param") {
      return true;
    } else if (tag === "source") {
      return true;
    } else if (tag === "track") {
      return true;
    } else if (tag === "wbr") {
      return true;
    } else {
      return false;
    }
  } else {
    return false;
  }
}
function advance(node) {
  if (node instanceof Fragment) {
    let children_count = node.children_count;
    return 1 + children_count;
  } else {
    return 1;
  }
}
var fragment_kind = 0;
function fragment(key2, mapper, children, keyed_children, children_count) {
  return new Fragment(
    fragment_kind,
    key2,
    mapper,
    children,
    keyed_children,
    children_count
  );
}
var element_kind = 1;
function element(key2, mapper, namespace2, tag, attributes, children, keyed_children, self_closing, void$) {
  return new Element2(
    element_kind,
    key2,
    mapper,
    namespace2,
    tag,
    prepare(attributes),
    children,
    keyed_children,
    self_closing,
    void$ || is_void_element(tag, namespace2)
  );
}
var text_kind = 2;
function text(key2, mapper, content) {
  return new Text(text_kind, key2, mapper, content);
}
var unsafe_inner_html_kind = 3;
function unsafe_inner_html(key2, mapper, namespace2, tag, attributes, inner_html) {
  return new UnsafeInnerHtml(
    unsafe_inner_html_kind,
    key2,
    mapper,
    namespace2,
    tag,
    prepare(attributes),
    inner_html
  );
}
function set_fragment_key(loop$key, loop$children, loop$index, loop$new_children, loop$keyed_children) {
  while (true) {
    let key2 = loop$key;
    let children = loop$children;
    let index5 = loop$index;
    let new_children = loop$new_children;
    let keyed_children = loop$keyed_children;
    if (children.hasLength(0)) {
      return [reverse(new_children), keyed_children];
    } else if (children.atLeastLength(1) && children.head instanceof Fragment && children.head.key === "") {
      let node = children.head;
      let children$1 = children.tail;
      let child_key = key2 + "::" + to_string(index5);
      let $ = set_fragment_key(
        child_key,
        node.children,
        0,
        empty_list,
        empty3()
      );
      let node_children = $[0];
      let node_keyed_children = $[1];
      let _block;
      let _record = node;
      _block = new Fragment(
        _record.kind,
        _record.key,
        _record.mapper,
        node_children,
        node_keyed_children,
        _record.children_count
      );
      let new_node = _block;
      let new_children$1 = prepend(new_node, new_children);
      let index$1 = index5 + 1;
      loop$key = key2;
      loop$children = children$1;
      loop$index = index$1;
      loop$new_children = new_children$1;
      loop$keyed_children = keyed_children;
    } else if (children.atLeastLength(1) && children.head.key !== "") {
      let node = children.head;
      let children$1 = children.tail;
      let child_key = key2 + "::" + node.key;
      let keyed_node = to_keyed(child_key, node);
      let new_children$1 = prepend(keyed_node, new_children);
      let keyed_children$1 = insert3(
        keyed_children,
        child_key,
        keyed_node
      );
      let index$1 = index5 + 1;
      loop$key = key2;
      loop$children = children$1;
      loop$index = index$1;
      loop$new_children = new_children$1;
      loop$keyed_children = keyed_children$1;
    } else {
      let node = children.head;
      let children$1 = children.tail;
      let new_children$1 = prepend(node, new_children);
      let index$1 = index5 + 1;
      loop$key = key2;
      loop$children = children$1;
      loop$index = index$1;
      loop$new_children = new_children$1;
      loop$keyed_children = keyed_children;
    }
  }
}
function to_keyed(key2, node) {
  if (node instanceof Element2) {
    let _record = node;
    return new Element2(
      _record.kind,
      key2,
      _record.mapper,
      _record.namespace,
      _record.tag,
      _record.attributes,
      _record.children,
      _record.keyed_children,
      _record.self_closing,
      _record.void
    );
  } else if (node instanceof Text) {
    let _record = node;
    return new Text(_record.kind, key2, _record.mapper, _record.content);
  } else if (node instanceof UnsafeInnerHtml) {
    let _record = node;
    return new UnsafeInnerHtml(
      _record.kind,
      key2,
      _record.mapper,
      _record.namespace,
      _record.tag,
      _record.attributes,
      _record.inner_html
    );
  } else {
    let children = node.children;
    let $ = set_fragment_key(
      key2,
      children,
      0,
      empty_list,
      empty3()
    );
    let children$1 = $[0];
    let keyed_children = $[1];
    let _record = node;
    return new Fragment(
      _record.kind,
      key2,
      _record.mapper,
      children$1,
      keyed_children,
      _record.children_count
    );
  }
}

// build/dev/javascript/lustre/lustre/vdom/patch.mjs
var Patch = class extends CustomType {
  constructor(index5, removed, changes, children) {
    super();
    this.index = index5;
    this.removed = removed;
    this.changes = changes;
    this.children = children;
  }
};
var ReplaceText = class extends CustomType {
  constructor(kind, content) {
    super();
    this.kind = kind;
    this.content = content;
  }
};
var ReplaceInnerHtml = class extends CustomType {
  constructor(kind, inner_html) {
    super();
    this.kind = kind;
    this.inner_html = inner_html;
  }
};
var Update = class extends CustomType {
  constructor(kind, added, removed) {
    super();
    this.kind = kind;
    this.added = added;
    this.removed = removed;
  }
};
var Move = class extends CustomType {
  constructor(kind, key2, before, count) {
    super();
    this.kind = kind;
    this.key = key2;
    this.before = before;
    this.count = count;
  }
};
var RemoveKey = class extends CustomType {
  constructor(kind, key2, count) {
    super();
    this.kind = kind;
    this.key = key2;
    this.count = count;
  }
};
var Replace = class extends CustomType {
  constructor(kind, from2, count, with$) {
    super();
    this.kind = kind;
    this.from = from2;
    this.count = count;
    this.with = with$;
  }
};
var Insert = class extends CustomType {
  constructor(kind, children, before) {
    super();
    this.kind = kind;
    this.children = children;
    this.before = before;
  }
};
var Remove = class extends CustomType {
  constructor(kind, from2, count) {
    super();
    this.kind = kind;
    this.from = from2;
    this.count = count;
  }
};
function new$4(index5, removed, changes, children) {
  return new Patch(index5, removed, changes, children);
}
var replace_text_kind = 0;
function replace_text(content) {
  return new ReplaceText(replace_text_kind, content);
}
var replace_inner_html_kind = 1;
function replace_inner_html(inner_html) {
  return new ReplaceInnerHtml(replace_inner_html_kind, inner_html);
}
var update_kind = 2;
function update(added, removed) {
  return new Update(update_kind, added, removed);
}
var move_kind = 3;
function move(key2, before, count) {
  return new Move(move_kind, key2, before, count);
}
var remove_key_kind = 4;
function remove_key(key2, count) {
  return new RemoveKey(remove_key_kind, key2, count);
}
var replace_kind = 5;
function replace2(from2, count, with$) {
  return new Replace(replace_kind, from2, count, with$);
}
var insert_kind = 6;
function insert4(children, before) {
  return new Insert(insert_kind, children, before);
}
var remove_kind = 7;
function remove2(from2, count) {
  return new Remove(remove_kind, from2, count);
}

// build/dev/javascript/lustre/lustre/vdom/diff.mjs
var Diff = class extends CustomType {
  constructor(patch, events) {
    super();
    this.patch = patch;
    this.events = events;
  }
};
var AttributeChange = class extends CustomType {
  constructor(added, removed, events) {
    super();
    this.added = added;
    this.removed = removed;
    this.events = events;
  }
};
function is_controlled(events, namespace2, tag, path2) {
  if (tag === "input" && namespace2 === "") {
    return has_dispatched_events(events, path2);
  } else if (tag === "select" && namespace2 === "") {
    return has_dispatched_events(events, path2);
  } else if (tag === "textarea" && namespace2 === "") {
    return has_dispatched_events(events, path2);
  } else {
    return false;
  }
}
function diff_attributes(loop$controlled, loop$path, loop$mapper, loop$events, loop$old, loop$new, loop$added, loop$removed) {
  while (true) {
    let controlled = loop$controlled;
    let path2 = loop$path;
    let mapper = loop$mapper;
    let events = loop$events;
    let old = loop$old;
    let new$10 = loop$new;
    let added = loop$added;
    let removed = loop$removed;
    if (old.hasLength(0) && new$10.hasLength(0)) {
      return new AttributeChange(added, removed, events);
    } else if (old.atLeastLength(1) && old.head instanceof Event2 && new$10.hasLength(0)) {
      let prev = old.head;
      let name = old.head.name;
      let old$1 = old.tail;
      let removed$1 = prepend(prev, removed);
      let events$1 = remove_event(events, path2, name);
      loop$controlled = controlled;
      loop$path = path2;
      loop$mapper = mapper;
      loop$events = events$1;
      loop$old = old$1;
      loop$new = new$10;
      loop$added = added;
      loop$removed = removed$1;
    } else if (old.atLeastLength(1) && new$10.hasLength(0)) {
      let prev = old.head;
      let old$1 = old.tail;
      let removed$1 = prepend(prev, removed);
      loop$controlled = controlled;
      loop$path = path2;
      loop$mapper = mapper;
      loop$events = events;
      loop$old = old$1;
      loop$new = new$10;
      loop$added = added;
      loop$removed = removed$1;
    } else if (old.hasLength(0) && new$10.atLeastLength(1) && new$10.head instanceof Event2) {
      let next = new$10.head;
      let name = new$10.head.name;
      let handler = new$10.head.handler;
      let new$1 = new$10.tail;
      let added$1 = prepend(next, added);
      let events$1 = add_event(events, mapper, path2, name, handler);
      loop$controlled = controlled;
      loop$path = path2;
      loop$mapper = mapper;
      loop$events = events$1;
      loop$old = old;
      loop$new = new$1;
      loop$added = added$1;
      loop$removed = removed;
    } else if (old.hasLength(0) && new$10.atLeastLength(1)) {
      let next = new$10.head;
      let new$1 = new$10.tail;
      let added$1 = prepend(next, added);
      loop$controlled = controlled;
      loop$path = path2;
      loop$mapper = mapper;
      loop$events = events;
      loop$old = old;
      loop$new = new$1;
      loop$added = added$1;
      loop$removed = removed;
    } else {
      let prev = old.head;
      let remaining_old = old.tail;
      let next = new$10.head;
      let remaining_new = new$10.tail;
      let $ = compare3(prev, next);
      if (prev instanceof Attribute && $ instanceof Eq && next instanceof Attribute) {
        let _block;
        let $1 = next.name;
        if ($1 === "value") {
          _block = controlled || prev.value !== next.value;
        } else if ($1 === "checked") {
          _block = controlled || prev.value !== next.value;
        } else if ($1 === "selected") {
          _block = controlled || prev.value !== next.value;
        } else {
          _block = prev.value !== next.value;
        }
        let has_changes = _block;
        let _block$1;
        if (has_changes) {
          _block$1 = prepend(next, added);
        } else {
          _block$1 = added;
        }
        let added$1 = _block$1;
        loop$controlled = controlled;
        loop$path = path2;
        loop$mapper = mapper;
        loop$events = events;
        loop$old = remaining_old;
        loop$new = remaining_new;
        loop$added = added$1;
        loop$removed = removed;
      } else if (prev instanceof Property && $ instanceof Eq && next instanceof Property) {
        let _block;
        let $1 = next.name;
        if ($1 === "scrollLeft") {
          _block = true;
        } else if ($1 === "scrollRight") {
          _block = true;
        } else if ($1 === "value") {
          _block = controlled || !isEqual(prev.value, next.value);
        } else if ($1 === "checked") {
          _block = controlled || !isEqual(prev.value, next.value);
        } else if ($1 === "selected") {
          _block = controlled || !isEqual(prev.value, next.value);
        } else {
          _block = !isEqual(prev.value, next.value);
        }
        let has_changes = _block;
        let _block$1;
        if (has_changes) {
          _block$1 = prepend(next, added);
        } else {
          _block$1 = added;
        }
        let added$1 = _block$1;
        loop$controlled = controlled;
        loop$path = path2;
        loop$mapper = mapper;
        loop$events = events;
        loop$old = remaining_old;
        loop$new = remaining_new;
        loop$added = added$1;
        loop$removed = removed;
      } else if (prev instanceof Event2 && $ instanceof Eq && next instanceof Event2) {
        let name = next.name;
        let handler = next.handler;
        let has_changes = prev.prevent_default !== next.prevent_default || prev.stop_propagation !== next.stop_propagation || prev.immediate !== next.immediate || !limit_equals(
          prev.limit,
          next.limit
        );
        let _block;
        if (has_changes) {
          _block = prepend(next, added);
        } else {
          _block = added;
        }
        let added$1 = _block;
        let events$1 = add_event(events, mapper, path2, name, handler);
        loop$controlled = controlled;
        loop$path = path2;
        loop$mapper = mapper;
        loop$events = events$1;
        loop$old = remaining_old;
        loop$new = remaining_new;
        loop$added = added$1;
        loop$removed = removed;
      } else if (prev instanceof Event2 && $ instanceof Eq) {
        let name = prev.name;
        let added$1 = prepend(next, added);
        let removed$1 = prepend(prev, removed);
        let events$1 = remove_event(events, path2, name);
        loop$controlled = controlled;
        loop$path = path2;
        loop$mapper = mapper;
        loop$events = events$1;
        loop$old = remaining_old;
        loop$new = remaining_new;
        loop$added = added$1;
        loop$removed = removed$1;
      } else if ($ instanceof Eq && next instanceof Event2) {
        let name = next.name;
        let handler = next.handler;
        let added$1 = prepend(next, added);
        let removed$1 = prepend(prev, removed);
        let events$1 = add_event(events, mapper, path2, name, handler);
        loop$controlled = controlled;
        loop$path = path2;
        loop$mapper = mapper;
        loop$events = events$1;
        loop$old = remaining_old;
        loop$new = remaining_new;
        loop$added = added$1;
        loop$removed = removed$1;
      } else if ($ instanceof Eq) {
        let added$1 = prepend(next, added);
        let removed$1 = prepend(prev, removed);
        loop$controlled = controlled;
        loop$path = path2;
        loop$mapper = mapper;
        loop$events = events;
        loop$old = remaining_old;
        loop$new = remaining_new;
        loop$added = added$1;
        loop$removed = removed$1;
      } else if ($ instanceof Gt && next instanceof Event2) {
        let name = next.name;
        let handler = next.handler;
        let added$1 = prepend(next, added);
        let events$1 = add_event(events, mapper, path2, name, handler);
        loop$controlled = controlled;
        loop$path = path2;
        loop$mapper = mapper;
        loop$events = events$1;
        loop$old = old;
        loop$new = remaining_new;
        loop$added = added$1;
        loop$removed = removed;
      } else if ($ instanceof Gt) {
        let added$1 = prepend(next, added);
        loop$controlled = controlled;
        loop$path = path2;
        loop$mapper = mapper;
        loop$events = events;
        loop$old = old;
        loop$new = remaining_new;
        loop$added = added$1;
        loop$removed = removed;
      } else if (prev instanceof Event2 && $ instanceof Lt) {
        let name = prev.name;
        let removed$1 = prepend(prev, removed);
        let events$1 = remove_event(events, path2, name);
        loop$controlled = controlled;
        loop$path = path2;
        loop$mapper = mapper;
        loop$events = events$1;
        loop$old = remaining_old;
        loop$new = new$10;
        loop$added = added;
        loop$removed = removed$1;
      } else {
        let removed$1 = prepend(prev, removed);
        loop$controlled = controlled;
        loop$path = path2;
        loop$mapper = mapper;
        loop$events = events;
        loop$old = remaining_old;
        loop$new = new$10;
        loop$added = added;
        loop$removed = removed$1;
      }
    }
  }
}
function do_diff(loop$old, loop$old_keyed, loop$new, loop$new_keyed, loop$moved, loop$moved_offset, loop$removed, loop$node_index, loop$patch_index, loop$path, loop$changes, loop$children, loop$mapper, loop$events) {
  while (true) {
    let old = loop$old;
    let old_keyed = loop$old_keyed;
    let new$10 = loop$new;
    let new_keyed = loop$new_keyed;
    let moved = loop$moved;
    let moved_offset = loop$moved_offset;
    let removed = loop$removed;
    let node_index = loop$node_index;
    let patch_index = loop$patch_index;
    let path2 = loop$path;
    let changes = loop$changes;
    let children = loop$children;
    let mapper = loop$mapper;
    let events = loop$events;
    if (old.hasLength(0) && new$10.hasLength(0)) {
      return new Diff(
        new Patch(patch_index, removed, changes, children),
        events
      );
    } else if (old.atLeastLength(1) && new$10.hasLength(0)) {
      let prev = old.head;
      let old$1 = old.tail;
      let _block;
      let $ = prev.key === "" || !contains2(moved, prev.key);
      if ($) {
        _block = removed + advance(prev);
      } else {
        _block = removed;
      }
      let removed$1 = _block;
      let events$1 = remove_child(events, path2, node_index, prev);
      loop$old = old$1;
      loop$old_keyed = old_keyed;
      loop$new = new$10;
      loop$new_keyed = new_keyed;
      loop$moved = moved;
      loop$moved_offset = moved_offset;
      loop$removed = removed$1;
      loop$node_index = node_index;
      loop$patch_index = patch_index;
      loop$path = path2;
      loop$changes = changes;
      loop$children = children;
      loop$mapper = mapper;
      loop$events = events$1;
    } else if (old.hasLength(0) && new$10.atLeastLength(1)) {
      let events$1 = add_children(
        events,
        mapper,
        path2,
        node_index,
        new$10
      );
      let insert5 = insert4(new$10, node_index - moved_offset);
      let changes$1 = prepend(insert5, changes);
      return new Diff(
        new Patch(patch_index, removed, changes$1, children),
        events$1
      );
    } else if (old.atLeastLength(1) && new$10.atLeastLength(1) && old.head.key !== new$10.head.key) {
      let prev = old.head;
      let old_remaining = old.tail;
      let next = new$10.head;
      let new_remaining = new$10.tail;
      let next_did_exist = get(old_keyed, next.key);
      let prev_does_exist = get(new_keyed, prev.key);
      let prev_has_moved = contains2(moved, prev.key);
      if (prev_does_exist.isOk() && next_did_exist.isOk() && prev_has_moved) {
        loop$old = old_remaining;
        loop$old_keyed = old_keyed;
        loop$new = new$10;
        loop$new_keyed = new_keyed;
        loop$moved = moved;
        loop$moved_offset = moved_offset - advance(prev);
        loop$removed = removed;
        loop$node_index = node_index;
        loop$patch_index = patch_index;
        loop$path = path2;
        loop$changes = changes;
        loop$children = children;
        loop$mapper = mapper;
        loop$events = events;
      } else if (prev_does_exist.isOk() && next_did_exist.isOk()) {
        let match = next_did_exist[0];
        let count = advance(next);
        let before = node_index - moved_offset;
        let move2 = move(next.key, before, count);
        let changes$1 = prepend(move2, changes);
        let moved$1 = insert2(moved, next.key);
        let moved_offset$1 = moved_offset + count;
        loop$old = prepend(match, old);
        loop$old_keyed = old_keyed;
        loop$new = new$10;
        loop$new_keyed = new_keyed;
        loop$moved = moved$1;
        loop$moved_offset = moved_offset$1;
        loop$removed = removed;
        loop$node_index = node_index;
        loop$patch_index = patch_index;
        loop$path = path2;
        loop$changes = changes$1;
        loop$children = children;
        loop$mapper = mapper;
        loop$events = events;
      } else if (!prev_does_exist.isOk() && next_did_exist.isOk()) {
        let count = advance(prev);
        let moved_offset$1 = moved_offset - count;
        let events$1 = remove_child(events, path2, node_index, prev);
        let remove5 = remove_key(prev.key, count);
        let changes$1 = prepend(remove5, changes);
        loop$old = old_remaining;
        loop$old_keyed = old_keyed;
        loop$new = new$10;
        loop$new_keyed = new_keyed;
        loop$moved = moved;
        loop$moved_offset = moved_offset$1;
        loop$removed = removed;
        loop$node_index = node_index;
        loop$patch_index = patch_index;
        loop$path = path2;
        loop$changes = changes$1;
        loop$children = children;
        loop$mapper = mapper;
        loop$events = events$1;
      } else if (prev_does_exist.isOk() && !next_did_exist.isOk()) {
        let before = node_index - moved_offset;
        let count = advance(next);
        let events$1 = add_child(events, mapper, path2, node_index, next);
        let insert5 = insert4(toList([next]), before);
        let changes$1 = prepend(insert5, changes);
        loop$old = old;
        loop$old_keyed = old_keyed;
        loop$new = new_remaining;
        loop$new_keyed = new_keyed;
        loop$moved = moved;
        loop$moved_offset = moved_offset + count;
        loop$removed = removed;
        loop$node_index = node_index + count;
        loop$patch_index = patch_index;
        loop$path = path2;
        loop$changes = changes$1;
        loop$children = children;
        loop$mapper = mapper;
        loop$events = events$1;
      } else {
        let prev_count = advance(prev);
        let next_count = advance(next);
        let change = replace2(node_index - moved_offset, prev_count, next);
        let _block;
        let _pipe = events;
        let _pipe$1 = remove_child(_pipe, path2, node_index, prev);
        _block = add_child(_pipe$1, mapper, path2, node_index, next);
        let events$1 = _block;
        loop$old = old_remaining;
        loop$old_keyed = old_keyed;
        loop$new = new_remaining;
        loop$new_keyed = new_keyed;
        loop$moved = moved;
        loop$moved_offset = moved_offset - prev_count + next_count;
        loop$removed = removed;
        loop$node_index = node_index + next_count;
        loop$patch_index = patch_index;
        loop$path = path2;
        loop$changes = prepend(change, changes);
        loop$children = children;
        loop$mapper = mapper;
        loop$events = events$1;
      }
    } else if (old.atLeastLength(1) && old.head instanceof Fragment && new$10.atLeastLength(1) && new$10.head instanceof Fragment) {
      let prev = old.head;
      let old$1 = old.tail;
      let next = new$10.head;
      let new$1 = new$10.tail;
      let node_index$1 = node_index + 1;
      let prev_count = prev.children_count;
      let next_count = next.children_count;
      let composed_mapper = compose_mapper(mapper, next.mapper);
      let child = do_diff(
        prev.children,
        prev.keyed_children,
        next.children,
        next.keyed_children,
        empty_set(),
        moved_offset,
        0,
        node_index$1,
        -1,
        path2,
        empty_list,
        children,
        composed_mapper,
        events
      );
      let _block;
      let $ = child.patch.removed > 0;
      if ($) {
        let remove_from = node_index$1 + next_count - moved_offset;
        let patch = remove2(remove_from, child.patch.removed);
        _block = append(child.patch.changes, prepend(patch, changes));
      } else {
        _block = append(child.patch.changes, changes);
      }
      let changes$1 = _block;
      loop$old = old$1;
      loop$old_keyed = old_keyed;
      loop$new = new$1;
      loop$new_keyed = new_keyed;
      loop$moved = moved;
      loop$moved_offset = moved_offset + next_count - prev_count;
      loop$removed = removed;
      loop$node_index = node_index$1 + next_count;
      loop$patch_index = patch_index;
      loop$path = path2;
      loop$changes = changes$1;
      loop$children = child.patch.children;
      loop$mapper = mapper;
      loop$events = child.events;
    } else if (old.atLeastLength(1) && old.head instanceof Element2 && new$10.atLeastLength(1) && new$10.head instanceof Element2 && (old.head.namespace === new$10.head.namespace && old.head.tag === new$10.head.tag)) {
      let prev = old.head;
      let old$1 = old.tail;
      let next = new$10.head;
      let new$1 = new$10.tail;
      let composed_mapper = compose_mapper(mapper, next.mapper);
      let child_path = add2(path2, node_index, next.key);
      let controlled = is_controlled(
        events,
        next.namespace,
        next.tag,
        child_path
      );
      let $ = diff_attributes(
        controlled,
        child_path,
        composed_mapper,
        events,
        prev.attributes,
        next.attributes,
        empty_list,
        empty_list
      );
      let added_attrs = $.added;
      let removed_attrs = $.removed;
      let events$1 = $.events;
      let _block;
      if (added_attrs.hasLength(0) && removed_attrs.hasLength(0)) {
        _block = empty_list;
      } else {
        _block = toList([update(added_attrs, removed_attrs)]);
      }
      let initial_child_changes = _block;
      let child = do_diff(
        prev.children,
        prev.keyed_children,
        next.children,
        next.keyed_children,
        empty_set(),
        0,
        0,
        0,
        node_index,
        child_path,
        initial_child_changes,
        empty_list,
        composed_mapper,
        events$1
      );
      let _block$1;
      let $1 = child.patch;
      if ($1 instanceof Patch && $1.removed === 0 && $1.changes.hasLength(0) && $1.children.hasLength(0)) {
        _block$1 = children;
      } else {
        _block$1 = prepend(child.patch, children);
      }
      let children$1 = _block$1;
      loop$old = old$1;
      loop$old_keyed = old_keyed;
      loop$new = new$1;
      loop$new_keyed = new_keyed;
      loop$moved = moved;
      loop$moved_offset = moved_offset;
      loop$removed = removed;
      loop$node_index = node_index + 1;
      loop$patch_index = patch_index;
      loop$path = path2;
      loop$changes = changes;
      loop$children = children$1;
      loop$mapper = mapper;
      loop$events = child.events;
    } else if (old.atLeastLength(1) && old.head instanceof Text && new$10.atLeastLength(1) && new$10.head instanceof Text && old.head.content === new$10.head.content) {
      let prev = old.head;
      let old$1 = old.tail;
      let next = new$10.head;
      let new$1 = new$10.tail;
      loop$old = old$1;
      loop$old_keyed = old_keyed;
      loop$new = new$1;
      loop$new_keyed = new_keyed;
      loop$moved = moved;
      loop$moved_offset = moved_offset;
      loop$removed = removed;
      loop$node_index = node_index + 1;
      loop$patch_index = patch_index;
      loop$path = path2;
      loop$changes = changes;
      loop$children = children;
      loop$mapper = mapper;
      loop$events = events;
    } else if (old.atLeastLength(1) && old.head instanceof Text && new$10.atLeastLength(1) && new$10.head instanceof Text) {
      let old$1 = old.tail;
      let next = new$10.head;
      let new$1 = new$10.tail;
      let child = new$4(
        node_index,
        0,
        toList([replace_text(next.content)]),
        empty_list
      );
      loop$old = old$1;
      loop$old_keyed = old_keyed;
      loop$new = new$1;
      loop$new_keyed = new_keyed;
      loop$moved = moved;
      loop$moved_offset = moved_offset;
      loop$removed = removed;
      loop$node_index = node_index + 1;
      loop$patch_index = patch_index;
      loop$path = path2;
      loop$changes = changes;
      loop$children = prepend(child, children);
      loop$mapper = mapper;
      loop$events = events;
    } else if (old.atLeastLength(1) && old.head instanceof UnsafeInnerHtml && new$10.atLeastLength(1) && new$10.head instanceof UnsafeInnerHtml) {
      let prev = old.head;
      let old$1 = old.tail;
      let next = new$10.head;
      let new$1 = new$10.tail;
      let composed_mapper = compose_mapper(mapper, next.mapper);
      let child_path = add2(path2, node_index, next.key);
      let $ = diff_attributes(
        false,
        child_path,
        composed_mapper,
        events,
        prev.attributes,
        next.attributes,
        empty_list,
        empty_list
      );
      let added_attrs = $.added;
      let removed_attrs = $.removed;
      let events$1 = $.events;
      let _block;
      if (added_attrs.hasLength(0) && removed_attrs.hasLength(0)) {
        _block = empty_list;
      } else {
        _block = toList([update(added_attrs, removed_attrs)]);
      }
      let child_changes = _block;
      let _block$1;
      let $1 = prev.inner_html === next.inner_html;
      if ($1) {
        _block$1 = child_changes;
      } else {
        _block$1 = prepend(
          replace_inner_html(next.inner_html),
          child_changes
        );
      }
      let child_changes$1 = _block$1;
      let _block$2;
      if (child_changes$1.hasLength(0)) {
        _block$2 = children;
      } else {
        _block$2 = prepend(
          new$4(node_index, 0, child_changes$1, toList([])),
          children
        );
      }
      let children$1 = _block$2;
      loop$old = old$1;
      loop$old_keyed = old_keyed;
      loop$new = new$1;
      loop$new_keyed = new_keyed;
      loop$moved = moved;
      loop$moved_offset = moved_offset;
      loop$removed = removed;
      loop$node_index = node_index + 1;
      loop$patch_index = patch_index;
      loop$path = path2;
      loop$changes = changes;
      loop$children = children$1;
      loop$mapper = mapper;
      loop$events = events$1;
    } else {
      let prev = old.head;
      let old_remaining = old.tail;
      let next = new$10.head;
      let new_remaining = new$10.tail;
      let prev_count = advance(prev);
      let next_count = advance(next);
      let change = replace2(node_index - moved_offset, prev_count, next);
      let _block;
      let _pipe = events;
      let _pipe$1 = remove_child(_pipe, path2, node_index, prev);
      _block = add_child(_pipe$1, mapper, path2, node_index, next);
      let events$1 = _block;
      loop$old = old_remaining;
      loop$old_keyed = old_keyed;
      loop$new = new_remaining;
      loop$new_keyed = new_keyed;
      loop$moved = moved;
      loop$moved_offset = moved_offset - prev_count + next_count;
      loop$removed = removed;
      loop$node_index = node_index + next_count;
      loop$patch_index = patch_index;
      loop$path = path2;
      loop$changes = prepend(change, changes);
      loop$children = children;
      loop$mapper = mapper;
      loop$events = events$1;
    }
  }
}
function diff(events, old, new$10) {
  return do_diff(
    toList([old]),
    empty3(),
    toList([new$10]),
    empty3(),
    empty_set(),
    0,
    0,
    0,
    0,
    root2,
    empty_list,
    empty_list,
    identity3,
    tick(events)
  );
}

// build/dev/javascript/lustre/lustre/vdom/reconciler.ffi.mjs
var Reconciler = class {
  offset = 0;
  #root = null;
  #dispatch = () => {
  };
  #useServerEvents = false;
  constructor(root3, dispatch, { useServerEvents = false } = {}) {
    this.#root = root3;
    this.#dispatch = dispatch;
    this.#useServerEvents = useServerEvents;
  }
  mount(vdom) {
    appendChild(this.#root, this.#createElement(vdom));
  }
  #stack = [];
  push(patch) {
    const offset2 = this.offset;
    if (offset2) {
      iterate(patch.changes, (change) => {
        switch (change.kind) {
          case insert_kind:
          case move_kind:
            change.before = (change.before | 0) + offset2;
            break;
          case remove_kind:
          case replace_kind:
            change.from = (change.from | 0) + offset2;
            break;
        }
      });
      iterate(patch.children, (child) => {
        child.index = (child.index | 0) + offset2;
      });
    }
    this.#stack.push({ node: this.#root, patch });
    this.#reconcile();
  }
  // PATCHING ------------------------------------------------------------------
  #reconcile() {
    const self2 = this;
    while (self2.#stack.length) {
      const { node, patch } = self2.#stack.pop();
      iterate(patch.changes, (change) => {
        switch (change.kind) {
          case insert_kind:
            self2.#insert(node, change.children, change.before);
            break;
          case move_kind:
            self2.#move(node, change.key, change.before, change.count);
            break;
          case remove_key_kind:
            self2.#removeKey(node, change.key, change.count);
            break;
          case remove_kind:
            self2.#remove(node, change.from, change.count);
            break;
          case replace_kind:
            self2.#replace(node, change.from, change.count, change.with);
            break;
          case replace_text_kind:
            self2.#replaceText(node, change.content);
            break;
          case replace_inner_html_kind:
            self2.#replaceInnerHtml(node, change.inner_html);
            break;
          case update_kind:
            self2.#update(node, change.added, change.removed);
            break;
        }
      });
      if (patch.removed) {
        self2.#remove(
          node,
          node.childNodes.length - patch.removed,
          patch.removed
        );
      }
      iterate(patch.children, (child) => {
        self2.#stack.push({ node: childAt(node, child.index), patch: child });
      });
    }
  }
  // CHANGES -------------------------------------------------------------------
  #insert(node, children, before) {
    const fragment3 = createDocumentFragment();
    iterate(children, (child) => {
      const el = this.#createElement(child);
      addKeyedChild(node, el);
      appendChild(fragment3, el);
    });
    insertBefore(node, fragment3, childAt(node, before));
  }
  #move(node, key2, before, count) {
    let el = getKeyedChild(node, key2);
    const beforeEl = childAt(node, before);
    for (let i = 0; i < count && el !== null; ++i) {
      const next = el.nextSibling;
      if (SUPPORTS_MOVE_BEFORE) {
        node.moveBefore(el, beforeEl);
      } else {
        insertBefore(node, el, beforeEl);
      }
      el = next;
    }
  }
  #removeKey(node, key2, count) {
    this.#removeFromChild(node, getKeyedChild(node, key2), count);
  }
  #remove(node, from2, count) {
    this.#removeFromChild(node, childAt(node, from2), count);
  }
  #removeFromChild(parent, child, count) {
    while (count-- > 0 && child !== null) {
      const next = child.nextSibling;
      const key2 = child[meta].key;
      if (key2) {
        parent[meta].keyedChildren.delete(key2);
      }
      for (const [_, { timeout }] of child[meta].debouncers) {
        clearTimeout(timeout);
      }
      parent.removeChild(child);
      child = next;
    }
  }
  #replace(parent, from2, count, child) {
    this.#remove(parent, from2, count);
    const el = this.#createElement(child);
    addKeyedChild(parent, el);
    insertBefore(parent, el, childAt(parent, from2));
  }
  #replaceText(node, content) {
    node.data = content ?? "";
  }
  #replaceInnerHtml(node, inner_html) {
    node.innerHTML = inner_html ?? "";
  }
  #update(node, added, removed) {
    iterate(removed, (attribute3) => {
      const name = attribute3.name;
      if (node[meta].handlers.has(name)) {
        node.removeEventListener(name, handleEvent);
        node[meta].handlers.delete(name);
        if (node[meta].throttles.has(name)) {
          node[meta].throttles.delete(name);
        }
        if (node[meta].debouncers.has(name)) {
          clearTimeout(node[meta].debouncers.get(name).timeout);
          node[meta].debouncers.delete(name);
        }
      } else {
        node.removeAttribute(name);
        ATTRIBUTE_HOOKS[name]?.removed?.(node, name);
      }
    });
    iterate(added, (attribute3) => {
      this.#createAttribute(node, attribute3);
    });
  }
  // CONSTRUCTORS --------------------------------------------------------------
  #createElement(vnode) {
    switch (vnode.kind) {
      case element_kind: {
        const node = createElement(vnode);
        this.#createAttributes(node, vnode);
        this.#insert(node, vnode.children, 0);
        return node;
      }
      case text_kind: {
        const node = createTextNode(vnode.content);
        initialiseMetadata(node, vnode.key);
        return node;
      }
      case fragment_kind: {
        const node = createDocumentFragment();
        const head = createTextNode();
        initialiseMetadata(head, vnode.key);
        appendChild(node, head);
        iterate(vnode.children, (child) => {
          appendChild(node, this.#createElement(child));
        });
        return node;
      }
      case unsafe_inner_html_kind: {
        const node = createElement(vnode);
        this.#createAttributes(node, vnode);
        this.#replaceInnerHtml(node, vnode.inner_html);
        return node;
      }
    }
  }
  #createAttributes(node, { attributes }) {
    iterate(attributes, (attribute3) => this.#createAttribute(node, attribute3));
  }
  #createAttribute(node, attribute3) {
    const nodeMeta = node[meta];
    switch (attribute3.kind) {
      case attribute_kind: {
        const name = attribute3.name;
        const value3 = attribute3.value ?? "";
        if (value3 !== node.getAttribute(name)) {
          node.setAttribute(name, value3);
        }
        ATTRIBUTE_HOOKS[name]?.added?.(node, value3);
        break;
      }
      case property_kind:
        node[attribute3.name] = attribute3.value;
        break;
      case event_kind: {
        if (!nodeMeta.handlers.has(attribute3.name)) {
          node.addEventListener(attribute3.name, handleEvent, {
            passive: !attribute3.prevent_default
          });
        }
        const prevent = attribute3.prevent_default;
        const stop = attribute3.stop_propagation;
        const immediate2 = attribute3.immediate;
        const include = Array.isArray(attribute3.include) ? attribute3.include : [];
        if (attribute3.limit?.kind === throttle_kind) {
          const throttle = nodeMeta.throttles.get(attribute3.name) ?? {
            last: 0,
            delay: attribute3.limit.delay
          };
          nodeMeta.throttles.set(attribute3.name, throttle);
        }
        if (attribute3.limit?.kind === debounce_kind) {
          const debounce = nodeMeta.debouncers.get(attribute3.name) ?? {
            timeout: null,
            delay: attribute3.limit.delay
          };
          nodeMeta.debouncers.set(attribute3.name, debounce);
        }
        nodeMeta.handlers.set(attribute3.name, (event4) => {
          if (prevent) event4.preventDefault();
          if (stop) event4.stopPropagation();
          const type = event4.type;
          let path2 = "";
          let pathNode = event4.currentTarget;
          while (pathNode !== this.#root) {
            const key2 = pathNode[meta].key;
            const parent = pathNode.parentNode;
            if (key2) {
              path2 = `${separator_key}${key2}${path2}`;
            } else {
              const siblings = parent.childNodes;
              let index5 = [].indexOf.call(siblings, pathNode);
              if (parent === this.#root) {
                index5 -= this.offset;
              }
              path2 = `${separator_index}${index5}${path2}`;
            }
            pathNode = parent;
          }
          path2 = path2.slice(1);
          const data2 = this.#useServerEvents ? createServerEvent(event4, include) : event4;
          if (nodeMeta.throttles.has(type)) {
            const throttle = nodeMeta.throttles.get(type);
            const now4 = Date.now();
            const last2 = throttle.last || 0;
            if (now4 > last2 + throttle.delay) {
              throttle.last = now4;
              this.#dispatch(data2, path2, type, immediate2);
            } else {
              event4.preventDefault();
            }
          } else if (nodeMeta.debouncers.has(type)) {
            const debounce = nodeMeta.debouncers.get(type);
            clearTimeout(debounce.timeout);
            debounce.timeout = setTimeout(() => {
              this.#dispatch(data2, path2, type, immediate2);
            }, debounce.delay);
          } else {
            this.#dispatch(data2, path2, type, immediate2);
          }
        });
        break;
      }
    }
  }
};
var iterate = (list4, callback) => {
  if (Array.isArray(list4)) {
    for (let i = 0; i < list4.length; i++) {
      callback(list4[i]);
    }
  } else if (list4) {
    for (list4; list4.tail; list4 = list4.tail) {
      callback(list4.head);
    }
  }
};
var appendChild = (node, child) => node.appendChild(child);
var insertBefore = (parent, node, referenceNode) => parent.insertBefore(node, referenceNode ?? null);
var createElement = ({ key: key2, tag, namespace: namespace2 }) => {
  const node = document2.createElementNS(namespace2 || NAMESPACE_HTML, tag);
  initialiseMetadata(node, key2);
  return node;
};
var createTextNode = (text4) => document2.createTextNode(text4 ?? "");
var createDocumentFragment = () => document2.createDocumentFragment();
var childAt = (node, at) => node.childNodes[at | 0];
var meta = Symbol("lustre");
var initialiseMetadata = (node, key2 = "") => {
  switch (node.nodeType) {
    case ELEMENT_NODE:
    case DOCUMENT_FRAGMENT_NODE:
      node[meta] = {
        key: key2,
        keyedChildren: /* @__PURE__ */ new Map(),
        handlers: /* @__PURE__ */ new Map(),
        throttles: /* @__PURE__ */ new Map(),
        debouncers: /* @__PURE__ */ new Map()
      };
      break;
    case TEXT_NODE:
      node[meta] = { key: key2, debouncers: /* @__PURE__ */ new Map() };
      break;
  }
};
var addKeyedChild = (node, child) => {
  if (child.nodeType === DOCUMENT_FRAGMENT_NODE) {
    for (child = child.firstChild; child; child = child.nextSibling) {
      addKeyedChild(node, child);
    }
    return;
  }
  const key2 = child[meta].key;
  if (key2) {
    node[meta].keyedChildren.set(key2, new WeakRef(child));
  }
};
var getKeyedChild = (node, key2) => node[meta].keyedChildren.get(key2).deref();
var handleEvent = (event4) => {
  const target2 = event4.currentTarget;
  const handler = target2[meta].handlers.get(event4.type);
  if (event4.type === "submit") {
    event4.detail ??= {};
    event4.detail.formData = [...new FormData(event4.target).entries()];
  }
  handler(event4);
};
var createServerEvent = (event4, include = []) => {
  const data2 = {};
  if (event4.type === "input" || event4.type === "change") {
    include.push("target.value");
  }
  if (event4.type === "submit") {
    include.push("detail.formData");
  }
  for (const property2 of include) {
    const path2 = property2.split(".");
    for (let i = 0, input2 = event4, output = data2; i < path2.length; i++) {
      if (i === path2.length - 1) {
        output[path2[i]] = input2[path2[i]];
        break;
      }
      output = output[path2[i]] ??= {};
      input2 = input2[path2[i]];
    }
  }
  return data2;
};
var syncedBooleanAttribute = (name) => {
  return {
    added(node) {
      node[name] = true;
    },
    removed(node) {
      node[name] = false;
    }
  };
};
var syncedAttribute = (name) => {
  return {
    added(node, value3) {
      node[name] = value3;
    }
  };
};
var ATTRIBUTE_HOOKS = {
  checked: syncedBooleanAttribute("checked"),
  selected: syncedBooleanAttribute("selected"),
  value: syncedAttribute("value"),
  autofocus: {
    added(node) {
      queueMicrotask(() => node.focus?.());
    }
  },
  autoplay: {
    added(node) {
      try {
        node.play?.();
      } catch (e) {
        console.error(e);
      }
    }
  }
};

// build/dev/javascript/lustre/lustre/vdom/virtualise.ffi.mjs
var virtualise = (root3) => {
  const vdom = virtualise_node(root3);
  if (vdom === null || vdom.children instanceof Empty) {
    const empty5 = empty_text_node();
    initialiseMetadata(empty5);
    root3.appendChild(empty5);
    return none2();
  } else if (vdom.children instanceof NonEmpty && vdom.children.tail instanceof Empty) {
    return vdom.children.head;
  } else {
    const head = empty_text_node();
    initialiseMetadata(head);
    root3.insertBefore(head, root3.firstChild);
    return fragment2(vdom.children);
  }
};
var empty_text_node = () => {
  return document2.createTextNode("");
};
var virtualise_node = (node) => {
  switch (node.nodeType) {
    case ELEMENT_NODE: {
      const key2 = node.getAttribute("data-lustre-key");
      initialiseMetadata(node, key2);
      if (key2) {
        node.removeAttribute("data-lustre-key");
      }
      const tag = node.localName;
      const namespace2 = node.namespaceURI;
      const isHtmlElement = !namespace2 || namespace2 === NAMESPACE_HTML;
      if (isHtmlElement && input_elements.includes(tag)) {
        virtualise_input_events(tag, node);
      }
      const attributes = virtualise_attributes(node);
      const children = virtualise_child_nodes(node);
      const vnode = isHtmlElement ? element2(tag, attributes, children) : namespaced(namespace2, tag, attributes, children);
      return key2 ? to_keyed(key2, vnode) : vnode;
    }
    case TEXT_NODE:
      initialiseMetadata(node);
      return text2(node.data);
    case DOCUMENT_FRAGMENT_NODE:
      initialiseMetadata(node);
      return node.childNodes.length > 0 ? fragment2(virtualise_child_nodes(node)) : null;
    default:
      return null;
  }
};
var input_elements = ["input", "select", "textarea"];
var virtualise_input_events = (tag, node) => {
  const value3 = node.value;
  const checked = node.checked;
  if (tag === "input" && node.type === "checkbox" && !checked) return;
  if (tag === "input" && node.type === "radio" && !checked) return;
  if (node.type !== "checkbox" && node.type !== "radio" && !value3) return;
  queueMicrotask(() => {
    node.value = value3;
    node.checked = checked;
    node.dispatchEvent(new Event("input", { bubbles: true }));
    node.dispatchEvent(new Event("change", { bubbles: true }));
    if (document2.activeElement !== node) {
      node.dispatchEvent(new Event("blur", { bubbles: true }));
    }
  });
};
var virtualise_child_nodes = (node) => {
  let children = empty_list;
  let child = node.lastChild;
  while (child) {
    const vnode = virtualise_node(child);
    const next = child.previousSibling;
    if (vnode) {
      children = new NonEmpty(vnode, children);
    } else {
      node.removeChild(child);
    }
    child = next;
  }
  return children;
};
var virtualise_attributes = (node) => {
  let index5 = node.attributes.length;
  let attributes = empty_list;
  while (index5-- > 0) {
    attributes = new NonEmpty(
      virtualise_attribute(node.attributes[index5]),
      attributes
    );
  }
  return attributes;
};
var virtualise_attribute = (attr) => {
  const name = attr.localName;
  const value3 = attr.value;
  return attribute2(name, value3);
};

// build/dev/javascript/lustre/lustre/runtime/client/runtime.ffi.mjs
var is_browser = () => !!document2;
var is_reference_equal = (a2, b) => a2 === b;
var Runtime = class {
  constructor(root3, [model, effects], view4, update4) {
    this.root = root3;
    this.#model = model;
    this.#view = view4;
    this.#update = update4;
    this.#reconciler = new Reconciler(this.root, (event4, path2, name) => {
      const [events, msg] = handle(this.#events, path2, name, event4);
      this.#events = events;
      if (msg.isOk()) {
        this.dispatch(msg[0], false);
      }
    });
    this.#vdom = virtualise(this.root);
    this.#events = new$5();
    this.#shouldFlush = true;
    this.#tick(effects);
  }
  // PUBLIC API ----------------------------------------------------------------
  root = null;
  set offset(offset2) {
    this.#reconciler.offset = offset2;
  }
  dispatch(msg, immediate2 = false) {
    this.#shouldFlush ||= immediate2;
    if (this.#shouldQueue) {
      this.#queue.push(msg);
    } else {
      const [model, effects] = this.#update(this.#model, msg);
      this.#model = model;
      this.#tick(effects);
    }
  }
  emit(event4, data2) {
    const target2 = this.root.host ?? this.root;
    target2.dispatchEvent(
      new CustomEvent(event4, {
        detail: data2,
        bubbles: true,
        composed: true
      })
    );
  }
  // PRIVATE API ---------------------------------------------------------------
  #model;
  #view;
  #update;
  #vdom;
  #events;
  #reconciler;
  #shouldQueue = false;
  #queue = [];
  #beforePaint = empty_list;
  #afterPaint = empty_list;
  #renderTimer = null;
  #shouldFlush = false;
  #actions = {
    dispatch: (msg, immediate2) => this.dispatch(msg, immediate2),
    emit: (event4, data2) => this.emit(event4, data2),
    select: () => {
    },
    root: () => this.root
  };
  // A `#tick` is where we process effects and trigger any synchronous updates.
  // Once a tick has been processed a render will be scheduled if none is already.
  // p0
  #tick(effects) {
    this.#shouldQueue = true;
    while (true) {
      for (let list4 = effects.synchronous; list4.tail; list4 = list4.tail) {
        list4.head(this.#actions);
      }
      this.#beforePaint = listAppend(this.#beforePaint, effects.before_paint);
      this.#afterPaint = listAppend(this.#afterPaint, effects.after_paint);
      if (!this.#queue.length) break;
      [this.#model, effects] = this.#update(this.#model, this.#queue.shift());
    }
    this.#shouldQueue = false;
    if (this.#shouldFlush) {
      cancelAnimationFrame(this.#renderTimer);
      this.#render();
    } else if (!this.#renderTimer) {
      this.#renderTimer = requestAnimationFrame(() => {
        this.#render();
      });
    }
  }
  #render() {
    this.#shouldFlush = false;
    this.#renderTimer = null;
    const next = this.#view(this.#model);
    const { patch, events } = diff(this.#events, this.#vdom, next);
    this.#events = events;
    this.#vdom = next;
    this.#reconciler.push(patch);
    if (this.#beforePaint instanceof NonEmpty) {
      const effects = makeEffect(this.#beforePaint);
      this.#beforePaint = empty_list;
      queueMicrotask(() => {
        this.#shouldFlush = true;
        this.#tick(effects);
      });
    }
    if (this.#afterPaint instanceof NonEmpty) {
      const effects = makeEffect(this.#afterPaint);
      this.#afterPaint = empty_list;
      requestAnimationFrame(() => {
        this.#shouldFlush = true;
        this.#tick(effects);
      });
    }
  }
};
function makeEffect(synchronous) {
  return {
    synchronous,
    after_paint: empty_list,
    before_paint: empty_list
  };
}
function listAppend(a2, b) {
  if (a2 instanceof Empty) {
    return b;
  } else if (b instanceof Empty) {
    return a2;
  } else {
    return append(a2, b);
  }
}

// build/dev/javascript/lustre/lustre/vdom/events.mjs
var Events = class extends CustomType {
  constructor(handlers, dispatched_paths, next_dispatched_paths) {
    super();
    this.handlers = handlers;
    this.dispatched_paths = dispatched_paths;
    this.next_dispatched_paths = next_dispatched_paths;
  }
};
function new$5() {
  return new Events(
    empty3(),
    empty_list,
    empty_list
  );
}
function tick(events) {
  return new Events(
    events.handlers,
    events.next_dispatched_paths,
    empty_list
  );
}
function do_remove_event(handlers, path2, name) {
  return remove(handlers, event2(path2, name));
}
function remove_event(events, path2, name) {
  let handlers = do_remove_event(events.handlers, path2, name);
  let _record = events;
  return new Events(
    handlers,
    _record.dispatched_paths,
    _record.next_dispatched_paths
  );
}
function remove_attributes(handlers, path2, attributes) {
  return fold(
    attributes,
    handlers,
    (events, attribute3) => {
      if (attribute3 instanceof Event2) {
        let name = attribute3.name;
        return do_remove_event(events, path2, name);
      } else {
        return events;
      }
    }
  );
}
function handle(events, path2, name, event4) {
  let next_dispatched_paths = prepend(path2, events.next_dispatched_paths);
  let _block;
  let _record = events;
  _block = new Events(
    _record.handlers,
    _record.dispatched_paths,
    next_dispatched_paths
  );
  let events$1 = _block;
  let $ = get(
    events$1.handlers,
    path2 + separator_event + name
  );
  if ($.isOk()) {
    let handler = $[0];
    return [events$1, run(event4, handler)];
  } else {
    return [events$1, new Error(toList([]))];
  }
}
function has_dispatched_events(events, path2) {
  return matches(path2, events.dispatched_paths);
}
function do_add_event(handlers, mapper, path2, name, handler) {
  return insert3(
    handlers,
    event2(path2, name),
    map4(handler, identity3(mapper))
  );
}
function add_event(events, mapper, path2, name, handler) {
  let handlers = do_add_event(events.handlers, mapper, path2, name, handler);
  let _record = events;
  return new Events(
    handlers,
    _record.dispatched_paths,
    _record.next_dispatched_paths
  );
}
function add_attributes(handlers, mapper, path2, attributes) {
  return fold(
    attributes,
    handlers,
    (events, attribute3) => {
      if (attribute3 instanceof Event2) {
        let name = attribute3.name;
        let handler = attribute3.handler;
        return do_add_event(events, mapper, path2, name, handler);
      } else {
        return events;
      }
    }
  );
}
function compose_mapper(mapper, child_mapper) {
  let $ = is_reference_equal(mapper, identity3);
  let $1 = is_reference_equal(child_mapper, identity3);
  if ($1) {
    return mapper;
  } else if ($ && !$1) {
    return child_mapper;
  } else {
    return (msg) => {
      return mapper(child_mapper(msg));
    };
  }
}
function do_remove_children(loop$handlers, loop$path, loop$child_index, loop$children) {
  while (true) {
    let handlers = loop$handlers;
    let path2 = loop$path;
    let child_index = loop$child_index;
    let children = loop$children;
    if (children.hasLength(0)) {
      return handlers;
    } else {
      let child = children.head;
      let rest = children.tail;
      let _pipe = handlers;
      let _pipe$1 = do_remove_child(_pipe, path2, child_index, child);
      loop$handlers = _pipe$1;
      loop$path = path2;
      loop$child_index = child_index + advance(child);
      loop$children = rest;
    }
  }
}
function do_remove_child(handlers, parent, child_index, child) {
  if (child instanceof Element2) {
    let attributes = child.attributes;
    let children = child.children;
    let path2 = add2(parent, child_index, child.key);
    let _pipe = handlers;
    let _pipe$1 = remove_attributes(_pipe, path2, attributes);
    return do_remove_children(_pipe$1, path2, 0, children);
  } else if (child instanceof Fragment) {
    let children = child.children;
    return do_remove_children(handlers, parent, child_index + 1, children);
  } else if (child instanceof UnsafeInnerHtml) {
    let attributes = child.attributes;
    let path2 = add2(parent, child_index, child.key);
    return remove_attributes(handlers, path2, attributes);
  } else {
    return handlers;
  }
}
function remove_child(events, parent, child_index, child) {
  let handlers = do_remove_child(events.handlers, parent, child_index, child);
  let _record = events;
  return new Events(
    handlers,
    _record.dispatched_paths,
    _record.next_dispatched_paths
  );
}
function do_add_children(loop$handlers, loop$mapper, loop$path, loop$child_index, loop$children) {
  while (true) {
    let handlers = loop$handlers;
    let mapper = loop$mapper;
    let path2 = loop$path;
    let child_index = loop$child_index;
    let children = loop$children;
    if (children.hasLength(0)) {
      return handlers;
    } else {
      let child = children.head;
      let rest = children.tail;
      let _pipe = handlers;
      let _pipe$1 = do_add_child(_pipe, mapper, path2, child_index, child);
      loop$handlers = _pipe$1;
      loop$mapper = mapper;
      loop$path = path2;
      loop$child_index = child_index + advance(child);
      loop$children = rest;
    }
  }
}
function do_add_child(handlers, mapper, parent, child_index, child) {
  if (child instanceof Element2) {
    let attributes = child.attributes;
    let children = child.children;
    let path2 = add2(parent, child_index, child.key);
    let composed_mapper = compose_mapper(mapper, child.mapper);
    let _pipe = handlers;
    let _pipe$1 = add_attributes(_pipe, composed_mapper, path2, attributes);
    return do_add_children(_pipe$1, composed_mapper, path2, 0, children);
  } else if (child instanceof Fragment) {
    let children = child.children;
    let composed_mapper = compose_mapper(mapper, child.mapper);
    let child_index$1 = child_index + 1;
    return do_add_children(
      handlers,
      composed_mapper,
      parent,
      child_index$1,
      children
    );
  } else if (child instanceof UnsafeInnerHtml) {
    let attributes = child.attributes;
    let path2 = add2(parent, child_index, child.key);
    let composed_mapper = compose_mapper(mapper, child.mapper);
    return add_attributes(handlers, composed_mapper, path2, attributes);
  } else {
    return handlers;
  }
}
function add_child(events, mapper, parent, index5, child) {
  let handlers = do_add_child(events.handlers, mapper, parent, index5, child);
  let _record = events;
  return new Events(
    handlers,
    _record.dispatched_paths,
    _record.next_dispatched_paths
  );
}
function add_children(events, mapper, path2, child_index, children) {
  let handlers = do_add_children(
    events.handlers,
    mapper,
    path2,
    child_index,
    children
  );
  let _record = events;
  return new Events(
    handlers,
    _record.dispatched_paths,
    _record.next_dispatched_paths
  );
}

// build/dev/javascript/lustre/lustre/element.mjs
function element2(tag, attributes, children) {
  return element(
    "",
    identity3,
    "",
    tag,
    attributes,
    children,
    empty3(),
    false,
    false
  );
}
function namespaced(namespace2, tag, attributes, children) {
  return element(
    "",
    identity3,
    namespace2,
    tag,
    attributes,
    children,
    empty3(),
    false,
    false
  );
}
function text2(content) {
  return text("", identity3, content);
}
function none2() {
  return text("", identity3, "");
}
function count_fragment_children(loop$children, loop$count) {
  while (true) {
    let children = loop$children;
    let count = loop$count;
    if (children.hasLength(0)) {
      return count;
    } else if (children.atLeastLength(1) && children.head instanceof Fragment) {
      let children_count = children.head.children_count;
      let rest = children.tail;
      loop$children = rest;
      loop$count = count + children_count;
    } else {
      let rest = children.tail;
      loop$children = rest;
      loop$count = count + 1;
    }
  }
}
function fragment2(children) {
  return fragment(
    "",
    identity3,
    children,
    empty3(),
    count_fragment_children(children, 0)
  );
}
function unsafe_raw_html(namespace2, tag, attributes, inner_html) {
  return unsafe_inner_html(
    "",
    identity3,
    namespace2,
    tag,
    attributes,
    inner_html
  );
}
function map5(element4, f) {
  let mapper = identity3(compose_mapper(element4.mapper, identity3(f)));
  if (element4 instanceof Fragment) {
    let children = element4.children;
    let keyed_children = element4.keyed_children;
    let _record = element4;
    return new Fragment(
      _record.kind,
      _record.key,
      mapper,
      identity3(children),
      identity3(keyed_children),
      _record.children_count
    );
  } else if (element4 instanceof Element2) {
    let attributes = element4.attributes;
    let children = element4.children;
    let keyed_children = element4.keyed_children;
    let _record = element4;
    return new Element2(
      _record.kind,
      _record.key,
      mapper,
      _record.namespace,
      _record.tag,
      identity3(attributes),
      identity3(children),
      identity3(keyed_children),
      _record.self_closing,
      _record.void
    );
  } else if (element4 instanceof UnsafeInnerHtml) {
    let attributes = element4.attributes;
    let _record = element4;
    return new UnsafeInnerHtml(
      _record.kind,
      _record.key,
      mapper,
      _record.namespace,
      _record.tag,
      identity3(attributes),
      _record.inner_html
    );
  } else {
    return identity3(element4);
  }
}

// build/dev/javascript/lustre/lustre/element/html.mjs
function text3(content) {
  return text2(content);
}
function style2(attrs, css) {
  return unsafe_raw_html("", "style", attrs, css);
}
function h3(attrs, children) {
  return element2("h3", attrs, children);
}
function div(attrs, children) {
  return element2("div", attrs, children);
}
function hr(attrs) {
  return element2("hr", attrs, empty_list);
}
function p(attrs, children) {
  return element2("p", attrs, children);
}
function a(attrs, children) {
  return element2("a", attrs, children);
}
function span(attrs, children) {
  return element2("span", attrs, children);
}
function button(attrs, children) {
  return element2("button", attrs, children);
}
function input(attrs) {
  return element2("input", attrs, empty_list);
}
function textarea(attrs, content) {
  return element2("textarea", attrs, toList([text2(content)]));
}

// build/dev/javascript/lustre/lustre/runtime/server/runtime.mjs
var EffectDispatchedMessage = class extends CustomType {
  constructor(message) {
    super();
    this.message = message;
  }
};
var EffectEmitEvent = class extends CustomType {
  constructor(name, data2) {
    super();
    this.name = name;
    this.data = data2;
  }
};
var SystemRequestedShutdown = class extends CustomType {
};

// build/dev/javascript/lustre/lustre/component.mjs
var Config2 = class extends CustomType {
  constructor(open_shadow_root, adopt_styles, attributes, properties, is_form_associated, on_form_autofill, on_form_reset, on_form_restore) {
    super();
    this.open_shadow_root = open_shadow_root;
    this.adopt_styles = adopt_styles;
    this.attributes = attributes;
    this.properties = properties;
    this.is_form_associated = is_form_associated;
    this.on_form_autofill = on_form_autofill;
    this.on_form_reset = on_form_reset;
    this.on_form_restore = on_form_restore;
  }
};
function new$6(options) {
  let init5 = new Config2(
    false,
    true,
    empty_dict(),
    empty_dict(),
    false,
    option_none,
    option_none,
    option_none
  );
  return fold(
    options,
    init5,
    (config, option) => {
      return option.apply(config);
    }
  );
}

// build/dev/javascript/lustre/lustre/runtime/client/spa.ffi.mjs
var Spa = class _Spa {
  static start({ init: init5, update: update4, view: view4 }, selector, flags) {
    if (!is_browser()) return new Error(new NotABrowser());
    const root3 = selector instanceof HTMLElement ? selector : document2.querySelector(selector);
    if (!root3) return new Error(new ElementNotFound(selector));
    return new Ok(new _Spa(root3, init5(flags), update4, view4));
  }
  #runtime;
  constructor(root3, [init5, effects], update4, view4) {
    this.#runtime = new Runtime(root3, [init5, effects], view4, update4);
  }
  send(message) {
    switch (message.constructor) {
      case EffectDispatchedMessage: {
        this.dispatch(message.message, false);
        break;
      }
      case EffectEmitEvent: {
        this.emit(message.name, message.data);
        break;
      }
      case SystemRequestedShutdown:
        break;
    }
  }
  dispatch(msg, immediate2) {
    this.#runtime.dispatch(msg, immediate2);
  }
  emit(event4, data2) {
    this.#runtime.emit(event4, data2);
  }
};
var start = Spa.start;

// build/dev/javascript/lustre/lustre.mjs
var App = class extends CustomType {
  constructor(init5, update4, view4, config) {
    super();
    this.init = init5;
    this.update = update4;
    this.view = view4;
    this.config = config;
  }
};
var ElementNotFound = class extends CustomType {
  constructor(selector) {
    super();
    this.selector = selector;
  }
};
var NotABrowser = class extends CustomType {
};
function application(init5, update4, view4) {
  return new App(init5, update4, view4, new$6(empty_list));
}
function start3(app, selector, start_args) {
  return guard(
    !is_browser(),
    new Error(new NotABrowser()),
    () => {
      return start(app, selector, start_args);
    }
  );
}

// build/dev/javascript/lustre/lustre/event.mjs
function is_immediate_event(name) {
  if (name === "input") {
    return true;
  } else if (name === "change") {
    return true;
  } else if (name === "focus") {
    return true;
  } else if (name === "focusin") {
    return true;
  } else if (name === "focusout") {
    return true;
  } else if (name === "blur") {
    return true;
  } else if (name === "select") {
    return true;
  } else {
    return false;
  }
}
function on(name, handler) {
  return event(
    name,
    handler,
    empty_list,
    false,
    false,
    is_immediate_event(name),
    new NoLimit(0)
  );
}
function stop_propagation(event4) {
  if (event4 instanceof Event2) {
    let _record = event4;
    return new Event2(
      _record.kind,
      _record.name,
      _record.handler,
      _record.include,
      _record.prevent_default,
      true,
      _record.immediate,
      _record.limit
    );
  } else {
    return event4;
  }
}
function on_click(msg) {
  return on("click", success(msg));
}
function on_mouse_enter(msg) {
  return on("mouseenter", success(msg));
}
function on_mouse_leave(msg) {
  return on("mouseleave", success(msg));
}
function on_input(msg) {
  return on(
    "input",
    subfield(
      toList(["target", "value"]),
      string3,
      (value3) => {
        return success(msg(value3));
      }
    )
  );
}
function on_focus(msg) {
  return on("focus", success(msg));
}
function on_blur(msg) {
  return on("blur", success(msg));
}

// build/dev/javascript/lustre/lustre/server_component.mjs
function element3(attributes, children) {
  return element2("lustre-server-component", attributes, children);
}
function route(path2) {
  return attribute2("route", path2);
}

// build/dev/javascript/gleam_http/gleam/http.mjs
var Get = class extends CustomType {
};
var Post = class extends CustomType {
};
var Head = class extends CustomType {
};
var Put = class extends CustomType {
};
var Delete = class extends CustomType {
};
var Trace = class extends CustomType {
};
var Connect = class extends CustomType {
};
var Options = class extends CustomType {
};
var Patch2 = class extends CustomType {
};
var Http = class extends CustomType {
};
var Https = class extends CustomType {
};
function method_to_string(method) {
  if (method instanceof Connect) {
    return "connect";
  } else if (method instanceof Delete) {
    return "delete";
  } else if (method instanceof Get) {
    return "get";
  } else if (method instanceof Head) {
    return "head";
  } else if (method instanceof Options) {
    return "options";
  } else if (method instanceof Patch2) {
    return "patch";
  } else if (method instanceof Post) {
    return "post";
  } else if (method instanceof Put) {
    return "put";
  } else if (method instanceof Trace) {
    return "trace";
  } else {
    let s = method[0];
    return s;
  }
}
function scheme_to_string(scheme) {
  if (scheme instanceof Http) {
    return "http";
  } else {
    return "https";
  }
}
function scheme_from_string(scheme) {
  let $ = lowercase(scheme);
  if ($ === "http") {
    return new Ok(new Http());
  } else if ($ === "https") {
    return new Ok(new Https());
  } else {
    return new Error(void 0);
  }
}

// build/dev/javascript/gleam_http/gleam/http/request.mjs
var Request = class extends CustomType {
  constructor(method, headers, body2, scheme, host, port, path2, query) {
    super();
    this.method = method;
    this.headers = headers;
    this.body = body2;
    this.scheme = scheme;
    this.host = host;
    this.port = port;
    this.path = path2;
    this.query = query;
  }
};
function to_uri(request) {
  return new Uri(
    new Some(scheme_to_string(request.scheme)),
    new None(),
    new Some(request.host),
    request.port,
    request.path,
    request.query,
    new None()
  );
}
function from_uri(uri) {
  return then$(
    (() => {
      let _pipe = uri.scheme;
      let _pipe$1 = unwrap(_pipe, "");
      return scheme_from_string(_pipe$1);
    })(),
    (scheme) => {
      return then$(
        (() => {
          let _pipe = uri.host;
          return to_result(_pipe, void 0);
        })(),
        (host) => {
          let req = new Request(
            new Get(),
            toList([]),
            "",
            scheme,
            host,
            uri.port,
            uri.path,
            uri.query
          );
          return new Ok(req);
        }
      );
    }
  );
}
function set_header(request, key2, value3) {
  let headers = key_set(request.headers, lowercase(key2), value3);
  let _record = request;
  return new Request(
    _record.method,
    headers,
    _record.body,
    _record.scheme,
    _record.host,
    _record.port,
    _record.path,
    _record.query
  );
}
function set_body(req, body2) {
  let method = req.method;
  let headers = req.headers;
  let scheme = req.scheme;
  let host = req.host;
  let port = req.port;
  let path2 = req.path;
  let query = req.query;
  return new Request(method, headers, body2, scheme, host, port, path2, query);
}
function set_method(req, method) {
  let _record = req;
  return new Request(
    method,
    _record.headers,
    _record.body,
    _record.scheme,
    _record.host,
    _record.port,
    _record.path,
    _record.query
  );
}
function to(url) {
  let _pipe = url;
  let _pipe$1 = parse2(_pipe);
  return then$(_pipe$1, from_uri);
}

// build/dev/javascript/gleam_http/gleam/http/response.mjs
var Response = class extends CustomType {
  constructor(status, headers, body2) {
    super();
    this.status = status;
    this.headers = headers;
    this.body = body2;
  }
};

// build/dev/javascript/gleam_javascript/gleam_javascript_ffi.mjs
var PromiseLayer = class _PromiseLayer {
  constructor(promise) {
    this.promise = promise;
  }
  static wrap(value3) {
    return value3 instanceof Promise ? new _PromiseLayer(value3) : value3;
  }
  static unwrap(value3) {
    return value3 instanceof _PromiseLayer ? value3.promise : value3;
  }
};
function resolve(value3) {
  return Promise.resolve(PromiseLayer.wrap(value3));
}
function then_await(promise, fn) {
  return promise.then((value3) => fn(PromiseLayer.unwrap(value3)));
}
function map_promise(promise, fn) {
  return promise.then(
    (value3) => PromiseLayer.wrap(fn(PromiseLayer.unwrap(value3)))
  );
}
function rescue(promise, fn) {
  return promise.catch((error2) => fn(error2));
}

// build/dev/javascript/gleam_javascript/gleam/javascript/promise.mjs
function tap(promise, callback) {
  let _pipe = promise;
  return map_promise(
    _pipe,
    (a2) => {
      callback(a2);
      return a2;
    }
  );
}
function try_await(promise, callback) {
  let _pipe = promise;
  return then_await(
    _pipe,
    (result) => {
      if (result.isOk()) {
        let a2 = result[0];
        return callback(a2);
      } else {
        let e = result[0];
        return resolve(new Error(e));
      }
    }
  );
}

// build/dev/javascript/gleam_fetch/gleam_fetch_ffi.mjs
async function raw_send(request) {
  try {
    return new Ok(await fetch(request));
  } catch (error2) {
    return new Error(new NetworkError(error2.toString()));
  }
}
function from_fetch_response(response) {
  return new Response(
    response.status,
    List.fromArray([...response.headers]),
    response
  );
}
function request_common(request) {
  let url = to_string3(to_uri(request));
  let method = method_to_string(request.method).toUpperCase();
  let options = {
    headers: make_headers(request.headers),
    method
  };
  return [url, options];
}
function to_fetch_request(request) {
  let [url, options] = request_common(request);
  if (options.method !== "GET" && options.method !== "HEAD") options.body = request.body;
  return new globalThis.Request(url, options);
}
function make_headers(headersList) {
  let headers = new globalThis.Headers();
  for (let [k, v] of headersList) headers.append(k.toLowerCase(), v);
  return headers;
}
async function read_text_body(response) {
  let body2;
  try {
    body2 = await response.body.text();
  } catch (error2) {
    return new Error(new UnableToReadBody());
  }
  return new Ok(response.withFields({ body: body2 }));
}

// build/dev/javascript/gleam_fetch/gleam/fetch.mjs
var NetworkError = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var UnableToReadBody = class extends CustomType {
};
function send2(request) {
  let _pipe = request;
  let _pipe$1 = to_fetch_request(_pipe);
  let _pipe$2 = raw_send(_pipe$1);
  return try_await(
    _pipe$2,
    (resp) => {
      return resolve(new Ok(from_fetch_response(resp)));
    }
  );
}

// build/dev/javascript/lustre_http/window_ffi.mjs
function location() {
  return window.location.href || "";
}

// build/dev/javascript/lustre_http/lustre_http.mjs
var BadUrl = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var InternalServerError = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var JsonError = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var NetworkError2 = class extends CustomType {
};
var NotFound = class extends CustomType {
};
var OtherError = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Unauthorized = class extends CustomType {
};
var ExpectTextResponse = class extends CustomType {
  constructor(run2) {
    super();
    this.run = run2;
  }
};
function form_request(url) {
  return try_recover(
    to(url),
    (_use0) => {
      return try$(
        (() => {
          let _pipe = location();
          return parse2(_pipe);
        })(),
        (window_location) => {
          let _block;
          let _record = window_location;
          _block = new Uri(
            _record.scheme,
            _record.userinfo,
            _record.host,
            _record.port,
            _record.path,
            new None(),
            new None()
          );
          let window_location$1 = _block;
          let _block$1;
          if (url.startsWith("/")) {
            let _record$1 = window_location$1;
            _block$1 = new Uri(
              _record$1.scheme,
              _record$1.userinfo,
              _record$1.host,
              _record$1.port,
              url,
              _record$1.query,
              _record$1.fragment
            );
          } else {
            let _record$1 = window_location$1;
            _block$1 = new Uri(
              _record$1.scheme,
              _record$1.userinfo,
              _record$1.host,
              _record$1.port,
              window_location$1.path + "/" + url,
              _record$1.query,
              _record$1.fragment
            );
          }
          let full_request_uri = _block$1;
          return from_uri(full_request_uri);
        }
      );
    }
  );
}
function do_send(req, expect, dispatch) {
  let _pipe = send2(req);
  let _pipe$1 = try_await(_pipe, read_text_body);
  let _pipe$2 = map_promise(
    _pipe$1,
    (response) => {
      if (response.isOk()) {
        let res = response[0];
        return expect.run(new Ok(res));
      } else {
        return expect.run(new Error(new NetworkError2()));
      }
    }
  );
  let _pipe$3 = rescue(
    _pipe$2,
    (_) => {
      return expect.run(new Error(new NetworkError2()));
    }
  );
  tap(_pipe$3, dispatch);
  return void 0;
}
function get2(url, expect) {
  return from(
    (dispatch) => {
      let $ = form_request(url);
      if ($.isOk()) {
        let req = $[0];
        return do_send(req, expect, dispatch);
      } else {
        return dispatch(expect.run(new Error(new BadUrl(url))));
      }
    }
  );
}
function post(url, body2, expect) {
  return from(
    (dispatch) => {
      let $ = form_request(url);
      if ($.isOk()) {
        let req = $[0];
        let _pipe = req;
        let _pipe$1 = set_method(_pipe, new Post());
        let _pipe$2 = set_header(
          _pipe$1,
          "Content-Type",
          "application/json"
        );
        let _pipe$3 = set_body(_pipe$2, to_string2(body2));
        return do_send(_pipe$3, expect, dispatch);
      } else {
        return dispatch(expect.run(new Error(new BadUrl(url))));
      }
    }
  );
}
function response_to_result(response) {
  if (response instanceof Response && (200 <= response.status && response.status <= 299)) {
    let status = response.status;
    let body2 = response.body;
    return new Ok(body2);
  } else if (response instanceof Response && response.status === 401) {
    return new Error(new Unauthorized());
  } else if (response instanceof Response && response.status === 404) {
    return new Error(new NotFound());
  } else if (response instanceof Response && response.status === 500) {
    let body2 = response.body;
    return new Error(new InternalServerError(body2));
  } else {
    let code2 = response.status;
    let body2 = response.body;
    return new Error(new OtherError(code2, body2));
  }
}
function expect_json(decoder, to_msg) {
  return new ExpectTextResponse(
    (response) => {
      let _pipe = response;
      let _pipe$1 = then$(_pipe, response_to_result);
      let _pipe$2 = then$(
        _pipe$1,
        (body2) => {
          let $ = parse(body2, decoder);
          if ($.isOk()) {
            let json2 = $[0];
            return new Ok(json2);
          } else {
            let json_error = $[0];
            return new Error(new JsonError(json_error));
          }
        }
      );
      return to_msg(_pipe$2);
    }
  );
}

// build/dev/javascript/modem/modem.ffi.mjs
var defaults = {
  handle_external_links: false,
  handle_internal_links: true
};
var initial_location = globalThis?.window?.location?.href;
var do_initial_uri = () => {
  if (!initial_location) {
    return new Error(void 0);
  } else {
    return new Ok(uri_from_url(new URL(initial_location)));
  }
};
var do_init = (dispatch, options = defaults) => {
  document.addEventListener("click", (event4) => {
    const a2 = find_anchor(event4.target);
    if (!a2) return;
    try {
      const url = new URL(a2.href);
      const uri = uri_from_url(url);
      const is_external = url.host !== window.location.host;
      if (!options.handle_external_links && is_external) return;
      if (!options.handle_internal_links && !is_external) return;
      event4.preventDefault();
      if (!is_external) {
        window.history.pushState({}, "", a2.href);
        window.requestAnimationFrame(() => {
          if (url.hash) {
            document.getElementById(url.hash.slice(1))?.scrollIntoView();
          }
        });
      }
      return dispatch(uri);
    } catch {
      return;
    }
  });
  window.addEventListener("popstate", (e) => {
    e.preventDefault();
    const url = new URL(window.location.href);
    const uri = uri_from_url(url);
    window.requestAnimationFrame(() => {
      if (url.hash) {
        document.getElementById(url.hash.slice(1))?.scrollIntoView();
      }
    });
    dispatch(uri);
  });
  window.addEventListener("modem-push", ({ detail }) => {
    dispatch(detail);
  });
  window.addEventListener("modem-replace", ({ detail }) => {
    dispatch(detail);
  });
};
var find_anchor = (el) => {
  if (!el || el.tagName === "BODY") {
    return null;
  } else if (el.tagName === "A") {
    return el;
  } else {
    return find_anchor(el.parentElement);
  }
};
var uri_from_url = (url) => {
  return new Uri(
    /* scheme   */
    url.protocol ? new Some(url.protocol.slice(0, -1)) : new None(),
    /* userinfo */
    new None(),
    /* host     */
    url.hostname ? new Some(url.hostname) : new None(),
    /* port     */
    url.port ? new Some(Number(url.port)) : new None(),
    /* path     */
    url.pathname,
    /* query    */
    url.search ? new Some(url.search.slice(1)) : new None(),
    /* fragment */
    url.hash ? new Some(url.hash.slice(1)) : new None()
  );
};

// build/dev/javascript/modem/modem.mjs
function init(handler) {
  return from(
    (dispatch) => {
      return guard(
        !is_browser(),
        void 0,
        () => {
          return do_init(
            (uri) => {
              let _pipe = uri;
              let _pipe$1 = handler(_pipe);
              return dispatch(_pipe$1);
            }
          );
        }
      );
    }
  );
}

// build/dev/javascript/o11a_common/o11a/audit_metadata.mjs
var AuditMetaData = class extends CustomType {
  constructor(audit_name, audit_formatted_name, in_scope_files) {
    super();
    this.audit_name = audit_name;
    this.audit_formatted_name = audit_formatted_name;
    this.in_scope_files = in_scope_files;
  }
};
function audit_metadata_decoder() {
  return field(
    "audit_name",
    string3,
    (audit_name) => {
      return field(
        "audit_formatted_name",
        string3,
        (audit_formatted_name) => {
          return field(
            "in_scope_files",
            list2(string3),
            (in_scope_files) => {
              return success(
                new AuditMetaData(
                  audit_name,
                  audit_formatted_name,
                  in_scope_files
                )
              );
            }
          );
        }
      );
    }
  );
}

// build/dev/javascript/gtempo/tempo.mjs
var DateTime = class extends CustomType {
  constructor(date, time, offset2) {
    super();
    this.date = date;
    this.time = time;
    this.offset = offset2;
  }
};
var Offset = class extends CustomType {
  constructor(minutes2) {
    super();
    this.minutes = minutes2;
  }
};
var Date3 = class extends CustomType {
  constructor(unix_days) {
    super();
    this.unix_days = unix_days;
  }
};
var TimeOfDay = class extends CustomType {
  constructor(microseconds2) {
    super();
    this.microseconds = microseconds2;
  }
};
function datetime(date, time, offset2) {
  return new DateTime(date, time, offset2);
}
function date_from_unix_seconds(unix_ts) {
  return new Date3(divideInt(unix_ts, 86400));
}
function date_to_unix_seconds(date) {
  return date.unix_days * 86400;
}
function time_from_microseconds(microseconds2) {
  return new TimeOfDay(microseconds2);
}
var utc = /* @__PURE__ */ new Offset(0);

// build/dev/javascript/gtempo/tempo/date.mjs
function from_unix_seconds(unix_ts) {
  return date_from_unix_seconds(unix_ts);
}
function to_unix_seconds(date) {
  return date_to_unix_seconds(date);
}
function from_unix_milli(unix_ts) {
  return from_unix_seconds(divideInt(unix_ts, 1e3));
}
function to_unix_milli(date) {
  return to_unix_seconds(date) * 1e3;
}

// build/dev/javascript/gtempo/tempo/time.mjs
function from_unix_milli2(unix_ts) {
  let _pipe = (unix_ts - to_unix_milli(from_unix_milli(unix_ts))) * 1e3;
  return time_from_microseconds(_pipe);
}

// build/dev/javascript/gtempo/tempo/datetime.mjs
function new$8(date, time, offset2) {
  return datetime(date, time, offset2);
}
function from_unix_milli3(unix_ts) {
  return new$8(
    from_unix_milli(unix_ts),
    from_unix_milli2(unix_ts),
    utc
  );
}

// build/dev/javascript/o11a_common/o11a/note.mjs
var NoteSubmission = class extends CustomType {
  constructor(parent_id, significance, user_id, message, expanded_message, modifier) {
    super();
    this.parent_id = parent_id;
    this.significance = significance;
    this.user_id = user_id;
    this.message = message;
    this.expanded_message = expanded_message;
    this.modifier = modifier;
  }
};
var Comment = class extends CustomType {
};
var Question = class extends CustomType {
};
var Answer = class extends CustomType {
};
var ToDo = class extends CustomType {
};
var ToDoCompletion = class extends CustomType {
};
var FindingLead = class extends CustomType {
};
var FindingConfirmation = class extends CustomType {
};
var FindingRejection = class extends CustomType {
};
var DevelperQuestion = class extends CustomType {
};
var Informational = class extends CustomType {
};
var InformationalRejection = class extends CustomType {
};
var InformationalConfirmation = class extends CustomType {
};
var None2 = class extends CustomType {
};
var Edit = class extends CustomType {
};
function note_significance_to_int(note_significance) {
  if (note_significance instanceof Comment) {
    return 1;
  } else if (note_significance instanceof Question) {
    return 2;
  } else if (note_significance instanceof Answer) {
    return 3;
  } else if (note_significance instanceof ToDo) {
    return 4;
  } else if (note_significance instanceof ToDoCompletion) {
    return 5;
  } else if (note_significance instanceof FindingLead) {
    return 6;
  } else if (note_significance instanceof FindingConfirmation) {
    return 7;
  } else if (note_significance instanceof FindingRejection) {
    return 8;
  } else if (note_significance instanceof DevelperQuestion) {
    return 9;
  } else if (note_significance instanceof Informational) {
    return 10;
  } else if (note_significance instanceof InformationalRejection) {
    return 11;
  } else {
    return 12;
  }
}
function note_modifier_to_int(note_modifier) {
  if (note_modifier instanceof None2) {
    return 0;
  } else if (note_modifier instanceof Edit) {
    return 1;
  } else {
    return 2;
  }
}
function encode_note_submission(note) {
  return object2(
    toList([
      ["p", string4(note.parent_id)],
      [
        "s",
        int3(
          (() => {
            let _pipe = note.significance;
            return note_significance_to_int(_pipe);
          })()
        )
      ],
      ["u", string4(note.user_id)],
      ["m", string4(note.message)],
      ["x", nullable(note.expanded_message, string4)],
      [
        "d",
        int3(
          (() => {
            let _pipe = note.modifier;
            return note_modifier_to_int(_pipe);
          })()
        )
      ]
    ])
  );
}

// build/dev/javascript/o11a_common/o11a/computed_note.mjs
var ComputedNote = class extends CustomType {
  constructor(note_id, parent_id, significance, user_name, message, expanded_message, time, edited) {
    super();
    this.note_id = note_id;
    this.parent_id = parent_id;
    this.significance = significance;
    this.user_name = user_name;
    this.message = message;
    this.expanded_message = expanded_message;
    this.time = time;
    this.edited = edited;
  }
};
var Comment2 = class extends CustomType {
};
var UnansweredQuestion = class extends CustomType {
};
var AnsweredQuestion = class extends CustomType {
};
var Answer2 = class extends CustomType {
};
var IncompleteToDo = class extends CustomType {
};
var CompleteToDo = class extends CustomType {
};
var ToDoCompletion2 = class extends CustomType {
};
var UnconfirmedFinding = class extends CustomType {
};
var ConfirmedFinding = class extends CustomType {
};
var RejectedFinding = class extends CustomType {
};
var FindingConfirmation2 = class extends CustomType {
};
var FindingRejection2 = class extends CustomType {
};
var UnansweredDeveloperQuestion = class extends CustomType {
};
var AnsweredDeveloperQuestion = class extends CustomType {
};
var Informational2 = class extends CustomType {
};
var RejectedInformational = class extends CustomType {
};
var InformationalRejection2 = class extends CustomType {
};
var InformationalConfirmation2 = class extends CustomType {
};
function significance_from_int(note_significance) {
  if (note_significance === 0) {
    return new Comment2();
  } else if (note_significance === 1) {
    return new UnansweredQuestion();
  } else if (note_significance === 2) {
    return new AnsweredQuestion();
  } else if (note_significance === 3) {
    return new Answer2();
  } else if (note_significance === 4) {
    return new IncompleteToDo();
  } else if (note_significance === 5) {
    return new CompleteToDo();
  } else if (note_significance === 6) {
    return new ToDoCompletion2();
  } else if (note_significance === 7) {
    return new UnconfirmedFinding();
  } else if (note_significance === 8) {
    return new ConfirmedFinding();
  } else if (note_significance === 9) {
    return new RejectedFinding();
  } else if (note_significance === 10) {
    return new FindingConfirmation2();
  } else if (note_significance === 11) {
    return new FindingRejection2();
  } else if (note_significance === 12) {
    return new UnansweredDeveloperQuestion();
  } else if (note_significance === 13) {
    return new AnsweredDeveloperQuestion();
  } else if (note_significance === 14) {
    return new Informational2();
  } else if (note_significance === 15) {
    return new RejectedInformational();
  } else if (note_significance === 16) {
    return new InformationalRejection2();
  } else if (note_significance === 17) {
    return new InformationalConfirmation2();
  } else {
    throw makeError(
      "panic",
      "o11a/computed_note",
      128,
      "significance_from_int",
      "Invalid note significance found",
      {}
    );
  }
}
function computed_note_decoder() {
  return field(
    "n",
    string3,
    (note_id) => {
      return field(
        "p",
        string3,
        (parent_id) => {
          return field(
            "s",
            int2,
            (significance) => {
              return field(
                "u",
                string3,
                (user_name) => {
                  return field(
                    "m",
                    string3,
                    (message) => {
                      return field(
                        "x",
                        optional(string3),
                        (expanded_message) => {
                          return field(
                            "t",
                            int2,
                            (time) => {
                              return field(
                                "e",
                                bool,
                                (edited) => {
                                  return success(
                                    new ComputedNote(
                                      note_id,
                                      parent_id,
                                      significance_from_int(significance),
                                      user_name,
                                      message,
                                      expanded_message,
                                      from_unix_milli3(time),
                                      edited
                                    )
                                  );
                                }
                              );
                            }
                          );
                        }
                      );
                    }
                  );
                }
              );
            }
          );
        }
      );
    }
  );
}
function significance_to_string(significance) {
  if (significance instanceof Comment2) {
    return new None();
  } else if (significance instanceof UnansweredQuestion) {
    return new Some("Unanswered Question");
  } else if (significance instanceof AnsweredQuestion) {
    return new Some("Answered");
  } else if (significance instanceof Answer2) {
    return new Some("Answer");
  } else if (significance instanceof IncompleteToDo) {
    return new Some("Incomplete ToDo");
  } else if (significance instanceof CompleteToDo) {
    return new Some("Complete");
  } else if (significance instanceof ToDoCompletion2) {
    return new Some("Completion");
  } else if (significance instanceof UnconfirmedFinding) {
    return new Some("Unconfirmed Finding");
  } else if (significance instanceof ConfirmedFinding) {
    return new Some("Confirmed Finding");
  } else if (significance instanceof RejectedFinding) {
    return new Some("Rejected Finding");
  } else if (significance instanceof FindingConfirmation2) {
    return new Some("Confirmation");
  } else if (significance instanceof FindingRejection2) {
    return new Some("Rejection");
  } else if (significance instanceof UnansweredDeveloperQuestion) {
    return new Some("Unanswered Dev Question");
  } else if (significance instanceof AnsweredDeveloperQuestion) {
    return new Some("Answered Dev Question");
  } else if (significance instanceof Informational2) {
    return new Some("Info");
  } else if (significance instanceof RejectedInformational) {
    return new Some("Incorrect Info");
  } else if (significance instanceof InformationalRejection2) {
    return new Some("Rejection");
  } else {
    return new Some("Confirmation");
  }
}
function is_significance_threadable(note_significance) {
  if (note_significance instanceof Comment2) {
    return false;
  } else if (note_significance instanceof UnansweredQuestion) {
    return true;
  } else if (note_significance instanceof AnsweredQuestion) {
    return true;
  } else if (note_significance instanceof Answer2) {
    return false;
  } else if (note_significance instanceof IncompleteToDo) {
    return true;
  } else if (note_significance instanceof CompleteToDo) {
    return true;
  } else if (note_significance instanceof ToDoCompletion2) {
    return false;
  } else if (note_significance instanceof UnconfirmedFinding) {
    return true;
  } else if (note_significance instanceof ConfirmedFinding) {
    return true;
  } else if (note_significance instanceof RejectedFinding) {
    return true;
  } else if (note_significance instanceof FindingConfirmation2) {
    return false;
  } else if (note_significance instanceof FindingRejection2) {
    return false;
  } else if (note_significance instanceof UnansweredDeveloperQuestion) {
    return true;
  } else if (note_significance instanceof AnsweredDeveloperQuestion) {
    return true;
  } else if (note_significance instanceof Informational2) {
    return true;
  } else if (note_significance instanceof RejectedInformational) {
    return true;
  } else if (note_significance instanceof InformationalRejection2) {
    return false;
  } else {
    return false;
  }
}

// build/dev/javascript/o11a_common/o11a/events.mjs
var server_updated_discussion = "sud";

// build/dev/javascript/o11a_common/o11a/preprocessor.mjs
var PreProcessedLine = class extends CustomType {
  constructor(significance, line_number, line_number_text, line_tag, line_id, leading_spaces, elements, columns) {
    super();
    this.significance = significance;
    this.line_number = line_number;
    this.line_number_text = line_number_text;
    this.line_tag = line_tag;
    this.line_id = line_id;
    this.leading_spaces = leading_spaces;
    this.elements = elements;
    this.columns = columns;
  }
};
var SingleDeclarationLine = class extends CustomType {
  constructor(topic_id, topic_title) {
    super();
    this.topic_id = topic_id;
    this.topic_title = topic_title;
  }
};
var NonEmptyLine = class extends CustomType {
};
var EmptyLine = class extends CustomType {
};
var PreProcessedDeclaration = class extends CustomType {
  constructor(node_id, node_declaration, tokens) {
    super();
    this.node_id = node_id;
    this.node_declaration = node_declaration;
    this.tokens = tokens;
  }
};
var PreProcessedReference = class extends CustomType {
  constructor(referenced_node_id, referenced_node_declaration, tokens) {
    super();
    this.referenced_node_id = referenced_node_id;
    this.referenced_node_declaration = referenced_node_declaration;
    this.tokens = tokens;
  }
};
var PreProcessedNode = class extends CustomType {
  constructor(element4) {
    super();
    this.element = element4;
  }
};
var PreProcessedGapNode = class extends CustomType {
  constructor(element4, leading_spaces) {
    super();
    this.element = element4;
    this.leading_spaces = leading_spaces;
  }
};
var NodeDeclaration = class extends CustomType {
  constructor(title2, topic_id, kind, references) {
    super();
    this.title = title2;
    this.topic_id = topic_id;
    this.kind = kind;
    this.references = references;
  }
};
var ContractDeclaration = class extends CustomType {
};
var ConstructorDeclaration = class extends CustomType {
};
var FunctionDeclaration = class extends CustomType {
};
var FallbackDeclaration = class extends CustomType {
};
var ReceiveDeclaration = class extends CustomType {
};
var ModifierDeclaration = class extends CustomType {
};
var VariableDeclaration = class extends CustomType {
};
var ConstantDeclaration = class extends CustomType {
};
var EnumDeclaration = class extends CustomType {
};
var EnumValueDeclaration = class extends CustomType {
};
var StructDeclaration = class extends CustomType {
};
var ErrorDeclaration = class extends CustomType {
};
var EventDeclaration = class extends CustomType {
};
var UnknownDeclaration = class extends CustomType {
};
var NodeReference = class extends CustomType {
  constructor(title2, topic_id) {
    super();
    this.title = title2;
    this.topic_id = topic_id;
  }
};
function pre_processed_line_significance_decoder() {
  return field(
    "type",
    string3,
    (variant) => {
      if (variant === "single_declaration_line") {
        return field(
          "topic_id",
          string3,
          (topic_id) => {
            return field(
              "topic_title",
              string3,
              (topic_title) => {
                return success(
                  new SingleDeclarationLine(topic_id, topic_title)
                );
              }
            );
          }
        );
      } else if (variant === "non_empty_line") {
        return success(new NonEmptyLine());
      } else if (variant === "empty_line") {
        return success(new EmptyLine());
      } else {
        return failure(new EmptyLine(), "PreProcessedLineSignificance");
      }
    }
  );
}
function node_declaration_kind_to_string(kind) {
  if (kind instanceof ContractDeclaration) {
    return "contract";
  } else if (kind instanceof ConstructorDeclaration) {
    return "constructor";
  } else if (kind instanceof FunctionDeclaration) {
    return "function";
  } else if (kind instanceof FallbackDeclaration) {
    return "fallback";
  } else if (kind instanceof ReceiveDeclaration) {
    return "receive";
  } else if (kind instanceof ModifierDeclaration) {
    return "modifier";
  } else if (kind instanceof VariableDeclaration) {
    return "variable";
  } else if (kind instanceof ConstantDeclaration) {
    return "constant";
  } else if (kind instanceof EnumDeclaration) {
    return "enum";
  } else if (kind instanceof EnumValueDeclaration) {
    return "enum_value";
  } else if (kind instanceof StructDeclaration) {
    return "struct";
  } else if (kind instanceof ErrorDeclaration) {
    return "error";
  } else if (kind instanceof EventDeclaration) {
    return "event";
  } else {
    return "unknown";
  }
}
function node_declaration_kind_from_string(kind) {
  if (kind === "contract") {
    return new ContractDeclaration();
  } else if (kind === "constructor") {
    return new ConstructorDeclaration();
  } else if (kind === "function") {
    return new FunctionDeclaration();
  } else if (kind === "fallback") {
    return new FallbackDeclaration();
  } else if (kind === "receive") {
    return new ReceiveDeclaration();
  } else if (kind === "modifier") {
    return new ModifierDeclaration();
  } else if (kind === "variable") {
    return new VariableDeclaration();
  } else if (kind === "constant") {
    return new ConstantDeclaration();
  } else if (kind === "enum") {
    return new EnumDeclaration();
  } else if (kind === "enum_value") {
    return new EnumValueDeclaration();
  } else if (kind === "struct") {
    return new StructDeclaration();
  } else if (kind === "error") {
    return new ErrorDeclaration();
  } else if (kind === "event") {
    return new EventDeclaration();
  } else if (kind === "unknown") {
    return new UnknownDeclaration();
  } else {
    return new UnknownDeclaration();
  }
}
function node_reference_decoder() {
  return field(
    "title",
    string3,
    (title2) => {
      return field(
        "topic_id",
        string3,
        (topic_id) => {
          return success(new NodeReference(title2, topic_id));
        }
      );
    }
  );
}
function node_declaration_decoder() {
  return field(
    "title",
    string3,
    (title2) => {
      return field(
        "topic_id",
        string3,
        (topic_id) => {
          return field(
            "kind",
            string3,
            (kind) => {
              return field(
                "references",
                list2(node_reference_decoder()),
                (references) => {
                  return success(
                    new NodeDeclaration(
                      title2,
                      topic_id,
                      node_declaration_kind_from_string(kind),
                      references
                    )
                  );
                }
              );
            }
          );
        }
      );
    }
  );
}
function pre_processed_node_decoder() {
  return field(
    "type",
    string3,
    (variant) => {
      if (variant === "pre_processed_declaration") {
        return field(
          "node_id",
          int2,
          (node_id) => {
            return field(
              "node_declaration",
              node_declaration_decoder(),
              (node_declaration) => {
                return field(
                  "tokens",
                  string3,
                  (tokens) => {
                    return success(
                      new PreProcessedDeclaration(
                        node_id,
                        node_declaration,
                        tokens
                      )
                    );
                  }
                );
              }
            );
          }
        );
      } else if (variant === "pre_processed_reference") {
        return field(
          "referenced_node_id",
          int2,
          (referenced_node_id) => {
            return field(
              "referenced_node_declaration",
              node_declaration_decoder(),
              (referenced_node_declaration) => {
                return field(
                  "tokens",
                  string3,
                  (tokens) => {
                    return success(
                      new PreProcessedReference(
                        referenced_node_id,
                        referenced_node_declaration,
                        tokens
                      )
                    );
                  }
                );
              }
            );
          }
        );
      } else if (variant === "pre_processed_node") {
        return field(
          "element",
          string3,
          (element4) => {
            return success(new PreProcessedNode(element4));
          }
        );
      } else if (variant === "pre_processed_gap_node") {
        return field(
          "element",
          string3,
          (element4) => {
            return field(
              "leading_spaces",
              int2,
              (leading_spaces) => {
                return success(
                  new PreProcessedGapNode(element4, leading_spaces)
                );
              }
            );
          }
        );
      } else {
        return failure(new PreProcessedNode(""), "PreProcessedNode");
      }
    }
  );
}
function pre_processed_line_decoder() {
  return field(
    "s",
    pre_processed_line_significance_decoder(),
    (significance) => {
      return field(
        "n",
        int2,
        (line_number) => {
          return field(
            "i",
            string3,
            (line_id) => {
              return field(
                "l",
                int2,
                (leading_spaces) => {
                  return field(
                    "e",
                    list2(pre_processed_node_decoder()),
                    (elements) => {
                      return field(
                        "c",
                        int2,
                        (columns) => {
                          let _block;
                          let _pipe = line_number;
                          _block = to_string(_pipe);
                          let line_number_text = _block;
                          return success(
                            new PreProcessedLine(
                              significance,
                              line_number,
                              line_number_text,
                              "L" + line_number_text,
                              line_id,
                              leading_spaces,
                              elements,
                              columns
                            )
                          );
                        }
                      );
                    }
                  );
                }
              );
            }
          );
        }
      );
    }
  );
}

// build/dev/javascript/plinth/element_ffi.mjs
function focus(element4) {
  element4.focus();
}
function blur(element4) {
  element4.blur();
}
function datasetGet(el, key2) {
  if (key2 in el.dataset) {
    return new Ok(el.dataset[key2]);
  }
  return new Error(void 0);
}

// build/dev/javascript/plinth/event_ffi.mjs
function preventDefault(event4) {
  return event4.preventDefault();
}
function ctrlKey(event4) {
  return event4.ctrlKey;
}
function key(event4) {
  return event4.key;
}
function shiftKey(event4) {
  return event4.shiftKey;
}

// build/dev/javascript/plinth/document_ffi.mjs
function querySelector(query) {
  let found = document.querySelector(query);
  if (!found) {
    return new Error();
  }
  return new Ok(found);
}

// build/dev/javascript/plinth/window_ffi.mjs
function self() {
  return globalThis;
}
function alert(message) {
  window.alert(message);
}
function prompt(message, defaultValue) {
  let text4 = window.prompt(message, defaultValue);
  if (text4 !== null) {
    return new Ok(text4);
  } else {
    return new Error();
  }
}
function addEventListener3(type, listener) {
  return window.addEventListener(type, listener);
}
function document3(window2) {
  return window2.document;
}
async function requestWakeLock() {
  try {
    return new Ok(await window.navigator.wakeLock.request("screen"));
  } catch (error2) {
    return new Error(error2.toString());
  }
}
function location2() {
  return window.location.href;
}
function locationOf(w) {
  try {
    return new Ok(w.location.href);
  } catch (error2) {
    return new Error(error2.toString());
  }
}
function setLocation(w, url) {
  w.location.href = url;
}
function origin() {
  return window.location.origin;
}
function pathname() {
  return window.location.pathname;
}
function reload() {
  return window.location.reload();
}
function reloadOf(w) {
  return w.location.reload();
}
function focus2(w) {
  return w.focus();
}
function getHash2() {
  const hash = window.location.hash;
  if (hash == "") {
    return new Error();
  }
  return new Ok(decodeURIComponent(hash.slice(1)));
}
function getSearch() {
  const search = window.location.search;
  if (search == "") {
    return new Error();
  }
  return new Ok(decodeURIComponent(search.slice(1)));
}
function innerHeight(w) {
  return w.innerHeight;
}
function innerWidth(w) {
  return w.innerWidth;
}
function outerHeight(w) {
  return w.outerHeight;
}
function outerWidth(w) {
  return w.outerWidth;
}
function screenX(w) {
  return w.screenX;
}
function screenY(w) {
  return w.screenY;
}
function screenTop(w) {
  return w.screenTop;
}
function screenLeft(w) {
  return w.screenLeft;
}
function scrollX(w) {
  return w.scrollX;
}
function scrollY(w) {
  return w.scrollY;
}
function open(url, target2, features) {
  try {
    return new Ok(window.open(url, target2, features));
  } catch (error2) {
    return new Error(error2.toString());
  }
}
function close(w) {
  w.close();
}
function closed(w) {
  return w.closed;
}
function queueMicrotask2(callback) {
  return window.queueMicrotask(callback);
}
function requestAnimationFrame2(callback) {
  return window.requestAnimationFrame(callback);
}
function cancelAnimationFrame2(callback) {
  return window.cancelAnimationFrame(callback);
}
function eval_(string) {
  try {
    return new Ok(eval(string));
  } catch (error2) {
    return new Error(error2.toString());
  }
}
async function import_(string6) {
  try {
    return new Ok(await import(string6));
  } catch (error2) {
    return new Error(error2.toString());
  }
}

// build/dev/javascript/snag/snag.mjs
var Snag = class extends CustomType {
  constructor(issue, cause) {
    super();
    this.issue = issue;
    this.cause = cause;
  }
};
function new$9(issue) {
  return new Snag(issue, toList([]));
}
function error(issue) {
  return new Error(new$9(issue));
}
function line_print(snag) {
  let _pipe = prepend(append2("error: ", snag.issue), snag.cause);
  return join(_pipe, " <- ");
}

// build/dev/javascript/o11a_client/o11a/client/attributes.mjs
function encode_column_count_data(column_count) {
  return data("cc", to_string(column_count));
}
function read_column_count_data(data2) {
  let _pipe = datasetGet(data2, "cc");
  let _pipe$1 = try$(_pipe, parse_int);
  return replace_error(
    _pipe$1,
    new$9("Failed to read column count data")
  );
}

// build/dev/javascript/o11a_common/o11a/classes.mjs
var discussion_entry_hover = "deh";
var discussion_entry = "de";
var line_container = "line-container";

// build/dev/javascript/o11a_client/o11a/client/selectors.mjs
function non_empty_line(line_number) {
  let _pipe = querySelector(
    "#L" + to_string(line_number) + "." + line_container
  );
  return replace_error(
    _pipe,
    new$9("Failed to find non-empty line")
  );
}
function discussion_entry2(line_number, column_number) {
  return querySelector(
    echo(
      ".dl" + to_string(line_number) + ".dc" + to_string(
        column_number
      ) + " ." + discussion_entry,
      "src/o11a/client/selectors.gleam",
      17
    )
  );
}
function discussion_input(line_number, column_number) {
  return querySelector(
    ".dl" + to_string(line_number) + ".dc" + to_string(
      column_number
    ) + " input"
  );
}
function echo(value3, file, line2) {
  const grey = "\x1B[90m";
  const reset_color = "\x1B[39m";
  const file_line = `${file}:${line2}`;
  const string_value = echo$inspect(value3);
  if (globalThis.process?.stderr?.write) {
    const string6 = `${grey}${file_line}${reset_color}
${string_value}
`;
    process.stderr.write(string6);
  } else if (globalThis.Deno) {
    const string6 = `${grey}${file_line}${reset_color}
${string_value}
`;
    globalThis.Deno.stderr.writeSync(new TextEncoder().encode(string6));
  } else {
    const string6 = `${file_line}
${string_value}`;
    globalThis.console.log(string6);
  }
  return value3;
}
function echo$inspectString(str) {
  let new_str = '"';
  for (let i = 0; i < str.length; i++) {
    let char = str[i];
    if (char == "\n") new_str += "\\n";
    else if (char == "\r") new_str += "\\r";
    else if (char == "	") new_str += "\\t";
    else if (char == "\f") new_str += "\\f";
    else if (char == "\\") new_str += "\\\\";
    else if (char == '"') new_str += '\\"';
    else if (char < " " || char > "~" && char < "\xA0") {
      new_str += "\\u{" + char.charCodeAt(0).toString(16).toUpperCase().padStart(4, "0") + "}";
    } else {
      new_str += char;
    }
  }
  new_str += '"';
  return new_str;
}
function echo$inspectDict(map7) {
  let body2 = "dict.from_list([";
  let first2 = true;
  let key_value_pairs = [];
  map7.forEach((value3, key2) => {
    key_value_pairs.push([key2, value3]);
  });
  key_value_pairs.sort();
  key_value_pairs.forEach(([key2, value3]) => {
    if (!first2) body2 = body2 + ", ";
    body2 = body2 + "#(" + echo$inspect(key2) + ", " + echo$inspect(value3) + ")";
    first2 = false;
  });
  return body2 + "])";
}
function echo$inspectCustomType(record) {
  const props = globalThis.Object.keys(record).map((label) => {
    const value3 = echo$inspect(record[label]);
    return isNaN(parseInt(label)) ? `${label}: ${value3}` : value3;
  }).join(", ");
  return props ? `${record.constructor.name}(${props})` : record.constructor.name;
}
function echo$inspectObject(v) {
  const name = Object.getPrototypeOf(v)?.constructor?.name || "Object";
  const props = [];
  for (const k of Object.keys(v)) {
    props.push(`${echo$inspect(k)}: ${echo$inspect(v[k])}`);
  }
  const body2 = props.length ? " " + props.join(", ") + " " : "";
  const head = name === "Object" ? "" : name + " ";
  return `//js(${head}{${body2}})`;
}
function echo$inspect(v) {
  const t = typeof v;
  if (v === true) return "True";
  if (v === false) return "False";
  if (v === null) return "//js(null)";
  if (v === void 0) return "Nil";
  if (t === "string") return echo$inspectString(v);
  if (t === "bigint" || t === "number") return v.toString();
  if (globalThis.Array.isArray(v))
    return `#(${v.map(echo$inspect).join(", ")})`;
  if (v instanceof List)
    return `[${v.toArray().map(echo$inspect).join(", ")}]`;
  if (v instanceof UtfCodepoint)
    return `//utfcodepoint(${String.fromCodePoint(v.value)})`;
  if (v instanceof BitArray) return echo$inspectBitArray(v);
  if (v instanceof CustomType) return echo$inspectCustomType(v);
  if (echo$isDict(v)) return echo$inspectDict(v);
  if (v instanceof Set)
    return `//js(Set(${[...v].map(echo$inspect).join(", ")}))`;
  if (v instanceof RegExp) return `//js(${v})`;
  if (v instanceof Date) return `//js(Date("${v.toISOString()}"))`;
  if (v instanceof Function) {
    const args = [];
    for (const i of Array(v.length).keys())
      args.push(String.fromCharCode(i + 97));
    return `//fn(${args.join(", ")}) { ... }`;
  }
  return echo$inspectObject(v);
}
function echo$inspectBitArray(bitArray) {
  let endOfAlignedBytes = bitArray.bitOffset + 8 * Math.trunc(bitArray.bitSize / 8);
  let alignedBytes = bitArraySlice(
    bitArray,
    bitArray.bitOffset,
    endOfAlignedBytes
  );
  let remainingUnalignedBits = bitArray.bitSize % 8;
  if (remainingUnalignedBits > 0) {
    let remainingBits = bitArraySliceToInt(
      bitArray,
      endOfAlignedBytes,
      bitArray.bitSize,
      false,
      false
    );
    let alignedBytesArray = Array.from(alignedBytes.rawBuffer);
    let suffix = `${remainingBits}:size(${remainingUnalignedBits})`;
    if (alignedBytesArray.length === 0) {
      return `<<${suffix}>>`;
    } else {
      return `<<${Array.from(alignedBytes.rawBuffer).join(", ")}, ${suffix}>>`;
    }
  } else {
    return `<<${Array.from(alignedBytes.rawBuffer).join(", ")}>>`;
  }
}
function echo$isDict(value3) {
  try {
    return value3 instanceof Dict;
  } catch {
    return false;
  }
}

// build/dev/javascript/o11a_client/storage.mjs
var is_user_typing_storage = false;
function set_is_user_typing(value3) {
  is_user_typing_storage = value3;
}
function is_user_typing() {
  return is_user_typing_storage;
}

// build/dev/javascript/o11a_client/o11a/client/page_navigation.mjs
var Model = class extends CustomType {
  constructor(current_line_number, current_column_number, current_line_column_count, line_count) {
    super();
    this.current_line_number = current_line_number;
    this.current_column_number = current_column_number;
    this.current_line_column_count = current_line_column_count;
    this.line_count = line_count;
  }
};
function init2() {
  return new Model(16, 1, 16, 16);
}
function prevent_default(event4) {
  let $ = is_user_typing();
  if ($) {
    let $1 = ctrlKey(event4);
    let $2 = key(event4);
    if ($1 && $2 === "e") {
      return preventDefault(event4);
    } else if ($2 === "Escape") {
      return preventDefault(event4);
    } else {
      return void 0;
    }
  } else {
    let $1 = key(event4);
    if ($1 === "ArrowUp") {
      return preventDefault(event4);
    } else if ($1 === "ArrowDown") {
      return preventDefault(event4);
    } else if ($1 === "ArrowLeft") {
      return preventDefault(event4);
    } else if ($1 === "ArrowRight") {
      return preventDefault(event4);
    } else if ($1 === "PageUp") {
      return preventDefault(event4);
    } else if ($1 === "PageDown") {
      return preventDefault(event4);
    } else if ($1 === "Enter") {
      return preventDefault(event4);
    } else if ($1 === "e") {
      return preventDefault(event4);
    } else if ($1 === "Escape") {
      return preventDefault(event4);
    } else {
      return void 0;
    }
  }
}
function handle_expanded_input_focus(event4, model, else_do) {
  let $ = ctrlKey(event4);
  let $1 = key(event4);
  if ($ && $1 === "e") {
    return new Ok([model, none()]);
  } else {
    return else_do();
  }
}
function find_next_discussion_line(loop$model, loop$current_line, loop$step) {
  while (true) {
    let model = loop$model;
    let current_line = loop$current_line;
    let step = loop$step;
    if (step > 0 && current_line === model.line_count) {
      return error(
        "Line is " + to_string(model.line_count) + ", cannot go further down"
      );
    } else if (step < 0 && current_line === 1) {
      return error("Line is 1, cannot go further up");
    } else if (step === 0) {
      return error("Step is zero");
    } else {
      let next_line = max(
        1,
        min(model.line_count, current_line + step)
      );
      let $ = non_empty_line(next_line);
      if ($.isOk()) {
        let line2 = $[0];
        return map3(
          read_column_count_data(line2),
          (column_count) => {
            return [next_line, column_count];
          }
        );
      } else {
        loop$model = model;
        loop$current_line = next_line;
        loop$step = (() => {
          if (step > 0 && next_line === model.line_count) {
            return -1;
          } else if (step > 0) {
            return 1;
          } else if (step < 0 && next_line === 1) {
            return 1;
          } else if (step < 0) {
            return -1;
          } else {
            return 0;
          }
        })();
      }
    }
  }
}
function focus_line_discussion(line_number, column_number) {
  return from(
    (_) => {
      echo2(
        "focus line discussion",
        "src/o11a/client/page_navigation.gleam",
        260
      );
      let _block;
      let _pipe = discussion_entry2(line_number, column_number);
      let _pipe$1 = replace_error(
        _pipe,
        new$9("Failed to find line discussion to focus")
      );
      let _pipe$2 = map3(_pipe$1, focus);
      _block = echo2(_pipe$2, "src/o11a/client/page_navigation.gleam", 267);
      let $ = _block;
      return void 0;
    }
  );
}
function handle_input_escape(event4, model, else_do) {
  let $ = key(event4);
  if ($ === "Escape") {
    return new Ok(
      [
        model,
        focus_line_discussion(
          model.current_line_number,
          model.current_column_number
        )
      ]
    );
  } else {
    return else_do();
  }
}
function move_focus_line(model, step) {
  return map3(
    find_next_discussion_line(model, model.current_line_number, step),
    (_use0) => {
      let new_line = _use0[0];
      let column_count = _use0[1];
      return [
        (() => {
          let _record = model;
          return new Model(
            _record.current_line_number,
            _record.current_column_number,
            column_count,
            _record.line_count
          );
        })(),
        focus_line_discussion(
          new_line,
          min(column_count, model.current_column_number)
        )
      ];
    }
  );
}
function move_focus_column(model, step) {
  echo2(
    "moving focus column by " + to_string(step),
    "src/o11a/client/page_navigation.gleam",
    156
  );
  let _block;
  let _pipe = max(1, model.current_column_number + step);
  _block = min(_pipe, model.current_line_column_count);
  let new_column = _block;
  echo2(
    "new column " + to_string(new_column),
    "src/o11a/client/page_navigation.gleam",
    161
  );
  let _pipe$1 = [
    model,
    focus_line_discussion(model.current_line_number, new_column)
  ];
  return new Ok(_pipe$1);
}
function handle_keyboard_navigation(event4, model, else_do) {
  let $ = shiftKey(event4);
  let $1 = key(event4);
  if (!$ && $1 === "ArrowUp") {
    return move_focus_line(model, -1);
  } else if (!$ && $1 === "ArrowDown") {
    return move_focus_line(model, 1);
  } else if ($ && $1 === "ArrowUp") {
    return move_focus_line(model, -5);
  } else if ($ && $1 === "ArrowDown") {
    return move_focus_line(model, 5);
  } else if ($1 === "PageUp") {
    return move_focus_line(model, -20);
  } else if ($1 === "PageDown") {
    return move_focus_line(model, 20);
  } else if ($1 === "ArrowLeft") {
    return move_focus_column(model, -1);
  } else if ($1 === "ArrowRight") {
    return move_focus_column(model, 1);
  } else {
    return else_do();
  }
}
function blur_line_discussion(line_number, column_number) {
  return from(
    (_) => {
      echo2(
        "blurring line discussion",
        "src/o11a/client/page_navigation.gleam",
        277
      );
      let _block;
      let _pipe = discussion_entry2(line_number, column_number);
      let _pipe$1 = replace_error(
        _pipe,
        new$9("Failed to find line discussion to focus")
      );
      _block = map3(_pipe$1, blur);
      let $ = _block;
      return void 0;
    }
  );
}
function handle_discussion_escape(event4, model, else_do) {
  let $ = key(event4);
  if ($ === "Escape") {
    return new Ok(
      [
        model,
        blur_line_discussion(
          model.current_line_number,
          model.current_column_number
        )
      ]
    );
  } else {
    return else_do();
  }
}
function focus_line_discussion_input(line_number, column_number) {
  return from(
    (_) => {
      let _block;
      let _pipe = discussion_input(line_number, column_number);
      let _pipe$1 = replace_error(
        _pipe,
        new$9("Failed to find line discussion input to focus")
      );
      _block = map3(_pipe$1, focus);
      let $ = _block;
      return void 0;
    }
  );
}
function handle_input_focus(event4, model, else_do) {
  let $ = ctrlKey(event4);
  let $1 = key(event4);
  if (!$ && $1 === "e") {
    return new Ok(
      [
        model,
        focus_line_discussion_input(
          model.current_line_number,
          model.current_column_number
        )
      ]
    );
  } else {
    return else_do();
  }
}
function do_page_navigation(event4, model) {
  let _block;
  let $ = is_user_typing();
  if ($) {
    _block = handle_expanded_input_focus(
      event4,
      model,
      () => {
        return handle_input_escape(
          event4,
          model,
          () => {
            return new Ok([model, none()]);
          }
        );
      }
    );
  } else {
    _block = handle_keyboard_navigation(
      event4,
      model,
      () => {
        return handle_input_focus(
          event4,
          model,
          () => {
            return handle_expanded_input_focus(
              event4,
              model,
              () => {
                return handle_discussion_escape(
                  event4,
                  model,
                  () => {
                    return new Ok([model, none()]);
                  }
                );
              }
            );
          }
        );
      }
    );
  }
  let res = _block;
  if (res.isOk()) {
    let model_effect = res[0];
    return model_effect;
  } else {
    let e = res[0];
    console_log(line_print(e));
    return [model, none()];
  }
}
function echo2(value3, file, line2) {
  const grey = "\x1B[90m";
  const reset_color = "\x1B[39m";
  const file_line = `${file}:${line2}`;
  const string_value = echo$inspect2(value3);
  if (globalThis.process?.stderr?.write) {
    const string6 = `${grey}${file_line}${reset_color}
${string_value}
`;
    process.stderr.write(string6);
  } else if (globalThis.Deno) {
    const string6 = `${grey}${file_line}${reset_color}
${string_value}
`;
    globalThis.Deno.stderr.writeSync(new TextEncoder().encode(string6));
  } else {
    const string6 = `${file_line}
${string_value}`;
    globalThis.console.log(string6);
  }
  return value3;
}
function echo$inspectString2(str) {
  let new_str = '"';
  for (let i = 0; i < str.length; i++) {
    let char = str[i];
    if (char == "\n") new_str += "\\n";
    else if (char == "\r") new_str += "\\r";
    else if (char == "	") new_str += "\\t";
    else if (char == "\f") new_str += "\\f";
    else if (char == "\\") new_str += "\\\\";
    else if (char == '"') new_str += '\\"';
    else if (char < " " || char > "~" && char < "\xA0") {
      new_str += "\\u{" + char.charCodeAt(0).toString(16).toUpperCase().padStart(4, "0") + "}";
    } else {
      new_str += char;
    }
  }
  new_str += '"';
  return new_str;
}
function echo$inspectDict2(map7) {
  let body2 = "dict.from_list([";
  let first2 = true;
  let key_value_pairs = [];
  map7.forEach((value3, key2) => {
    key_value_pairs.push([key2, value3]);
  });
  key_value_pairs.sort();
  key_value_pairs.forEach(([key2, value3]) => {
    if (!first2) body2 = body2 + ", ";
    body2 = body2 + "#(" + echo$inspect2(key2) + ", " + echo$inspect2(value3) + ")";
    first2 = false;
  });
  return body2 + "])";
}
function echo$inspectCustomType2(record) {
  const props = globalThis.Object.keys(record).map((label) => {
    const value3 = echo$inspect2(record[label]);
    return isNaN(parseInt(label)) ? `${label}: ${value3}` : value3;
  }).join(", ");
  return props ? `${record.constructor.name}(${props})` : record.constructor.name;
}
function echo$inspectObject2(v) {
  const name = Object.getPrototypeOf(v)?.constructor?.name || "Object";
  const props = [];
  for (const k of Object.keys(v)) {
    props.push(`${echo$inspect2(k)}: ${echo$inspect2(v[k])}`);
  }
  const body2 = props.length ? " " + props.join(", ") + " " : "";
  const head = name === "Object" ? "" : name + " ";
  return `//js(${head}{${body2}})`;
}
function echo$inspect2(v) {
  const t = typeof v;
  if (v === true) return "True";
  if (v === false) return "False";
  if (v === null) return "//js(null)";
  if (v === void 0) return "Nil";
  if (t === "string") return echo$inspectString2(v);
  if (t === "bigint" || t === "number") return v.toString();
  if (globalThis.Array.isArray(v))
    return `#(${v.map(echo$inspect2).join(", ")})`;
  if (v instanceof List)
    return `[${v.toArray().map(echo$inspect2).join(", ")}]`;
  if (v instanceof UtfCodepoint)
    return `//utfcodepoint(${String.fromCodePoint(v.value)})`;
  if (v instanceof BitArray) return echo$inspectBitArray2(v);
  if (v instanceof CustomType) return echo$inspectCustomType2(v);
  if (echo$isDict2(v)) return echo$inspectDict2(v);
  if (v instanceof Set)
    return `//js(Set(${[...v].map(echo$inspect2).join(", ")}))`;
  if (v instanceof RegExp) return `//js(${v})`;
  if (v instanceof Date) return `//js(Date("${v.toISOString()}"))`;
  if (v instanceof Function) {
    const args = [];
    for (const i of Array(v.length).keys())
      args.push(String.fromCharCode(i + 97));
    return `//fn(${args.join(", ")}) { ... }`;
  }
  return echo$inspectObject2(v);
}
function echo$inspectBitArray2(bitArray) {
  let endOfAlignedBytes = bitArray.bitOffset + 8 * Math.trunc(bitArray.bitSize / 8);
  let alignedBytes = bitArraySlice(
    bitArray,
    bitArray.bitOffset,
    endOfAlignedBytes
  );
  let remainingUnalignedBits = bitArray.bitSize % 8;
  if (remainingUnalignedBits > 0) {
    let remainingBits = bitArraySliceToInt(
      bitArray,
      endOfAlignedBytes,
      bitArray.bitSize,
      false,
      false
    );
    let alignedBytesArray = Array.from(alignedBytes.rawBuffer);
    let suffix = `${remainingBits}:size(${remainingUnalignedBits})`;
    if (alignedBytesArray.length === 0) {
      return `<<${suffix}>>`;
    } else {
      return `<<${Array.from(alignedBytes.rawBuffer).join(", ")}, ${suffix}>>`;
    }
  } else {
    return `<<${Array.from(alignedBytes.rawBuffer).join(", ")}>>`;
  }
}
function echo$isDict2(value3) {
  try {
    return value3 instanceof Dict;
  } catch {
    return false;
  }
}

// build/dev/javascript/o11a_common/lib/enumerate.mjs
function translate_number_to_letter(loop$number) {
  while (true) {
    let number = loop$number;
    if (number === 1) {
      return "a";
    } else if (number === 2) {
      return "b";
    } else if (number === 3) {
      return "c";
    } else if (number === 4) {
      return "d";
    } else if (number === 5) {
      return "e";
    } else if (number === 6) {
      return "f";
    } else if (number === 7) {
      return "g";
    } else if (number === 8) {
      return "h";
    } else if (number === 9) {
      return "i";
    } else if (number === 10) {
      return "j";
    } else if (number === 11) {
      return "k";
    } else if (number === 12) {
      return "l";
    } else if (number === 13) {
      return "m";
    } else if (number === 14) {
      return "n";
    } else if (number === 15) {
      return "o";
    } else if (number === 16) {
      return "p";
    } else if (number === 17) {
      return "q";
    } else if (number === 18) {
      return "r";
    } else if (number === 19) {
      return "s";
    } else if (number === 20) {
      return "t";
    } else if (number === 21) {
      return "u";
    } else if (number === 22) {
      return "v";
    } else if (number === 23) {
      return "w";
    } else if (number === 24) {
      return "x";
    } else if (number === 25) {
      return "y";
    } else if (number === 26) {
      return "z";
    } else {
      let quotient = divideInt(number - 1, 26);
      let remainder = remainderInt(number - 1, 26);
      if (quotient === 0) {
        loop$number = remainder + 1;
      } else {
        return translate_number_to_letter(quotient) + translate_number_to_letter(
          remainder + 1
        );
      }
    }
  }
}

// build/dev/javascript/o11a_common/o11a/attributes.mjs
function encode_grid_location_data(line_number, column_number) {
  return class$("dl" + line_number + " dc" + column_number);
}
function encode_topic_id_data(topic_id) {
  return data("i", topic_id);
}
function encode_topic_title_data(topic_title) {
  return data("t", topic_title);
}
function encode_is_reference_data(is_reference) {
  return data(
    "r",
    (() => {
      if (is_reference) {
        return "1";
      } else {
        return "0";
      }
    })()
  );
}

// build/dev/javascript/given/given.mjs
function that(requirement, consequence, alternative) {
  if (requirement) {
    return consequence();
  } else {
    return alternative();
  }
}

// build/dev/javascript/lustre/lustre/element/svg.mjs
var namespace = "http://www.w3.org/2000/svg";
function line(attrs) {
  return namespaced(namespace, "line", attrs, empty_list);
}
function polyline(attrs) {
  return namespaced(namespace, "polyline", attrs, empty_list);
}
function svg(attrs, children) {
  return namespaced(namespace, "svg", attrs, children);
}
function path(attrs) {
  return namespaced(namespace, "path", attrs, empty_list);
}

// build/dev/javascript/o11a_common/lib/lucide.mjs
function messages_square(attributes) {
  return svg(
    prepend(
      attribute2("stroke-linejoin", "round"),
      prepend(
        attribute2("stroke-linecap", "round"),
        prepend(
          attribute2("stroke-width", "2"),
          prepend(
            attribute2("stroke", "currentColor"),
            prepend(
              attribute2("fill", "none"),
              prepend(
                attribute2("viewBox", "0 0 24 24"),
                prepend(
                  attribute2("height", "24"),
                  prepend(attribute2("width", "24"), attributes)
                )
              )
            )
          )
        )
      )
    ),
    toList([
      path(
        toList([
          attribute2(
            "d",
            "M14 9a2 2 0 0 1-2 2H6l-4 4V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2z"
          )
        ])
      ),
      path(
        toList([
          attribute2("d", "M18 9h2a2 2 0 0 1 2 2v11l-4-4h-6a2 2 0 0 1-2-2v-1")
        ])
      )
    ])
  );
}
function pencil_ruler(attributes) {
  return svg(
    prepend(
      attribute2("stroke-linejoin", "round"),
      prepend(
        attribute2("stroke-linecap", "round"),
        prepend(
          attribute2("stroke-width", "2"),
          prepend(
            attribute2("stroke", "currentColor"),
            prepend(
              attribute2("fill", "none"),
              prepend(
                attribute2("viewBox", "0 0 24 24"),
                prepend(
                  attribute2("height", "24"),
                  prepend(attribute2("width", "24"), attributes)
                )
              )
            )
          )
        )
      )
    ),
    toList([
      path(
        toList([
          attribute2(
            "d",
            "M13 7 8.7 2.7a2.41 2.41 0 0 0-3.4 0L2.7 5.3a2.41 2.41 0 0 0 0 3.4L7 13"
          )
        ])
      ),
      path(toList([attribute2("d", "m8 6 2-2")])),
      path(toList([attribute2("d", "m18 16 2-2")])),
      path(
        toList([
          attribute2(
            "d",
            "m17 11 4.3 4.3c.94.94.94 2.46 0 3.4l-2.6 2.6c-.94.94-2.46.94-3.4 0L11 17"
          )
        ])
      ),
      path(
        toList([
          attribute2(
            "d",
            "M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"
          )
        ])
      ),
      path(toList([attribute2("d", "m15 5 4 4")]))
    ])
  );
}
function list_collapse(attributes) {
  return svg(
    prepend(
      attribute2("stroke-linejoin", "round"),
      prepend(
        attribute2("stroke-linecap", "round"),
        prepend(
          attribute2("stroke-width", "2"),
          prepend(
            attribute2("stroke", "currentColor"),
            prepend(
              attribute2("fill", "none"),
              prepend(
                attribute2("viewBox", "0 0 24 24"),
                prepend(
                  attribute2("height", "24"),
                  prepend(attribute2("width", "24"), attributes)
                )
              )
            )
          )
        )
      )
    ),
    toList([
      path(toList([attribute2("d", "m3 10 2.5-2.5L3 5")])),
      path(toList([attribute2("d", "m3 19 2.5-2.5L3 14")])),
      path(toList([attribute2("d", "M10 6h11")])),
      path(toList([attribute2("d", "M10 12h11")])),
      path(toList([attribute2("d", "M10 18h11")]))
    ])
  );
}
function maximize_2(attributes) {
  return svg(
    prepend(
      attribute2("stroke-linejoin", "round"),
      prepend(
        attribute2("stroke-linecap", "round"),
        prepend(
          attribute2("stroke-width", "2"),
          prepend(
            attribute2("stroke", "currentColor"),
            prepend(
              attribute2("fill", "none"),
              prepend(
                attribute2("viewBox", "0 0 24 24"),
                prepend(
                  attribute2("height", "24"),
                  prepend(attribute2("width", "24"), attributes)
                )
              )
            )
          )
        )
      )
    ),
    toList([
      polyline(toList([attribute2("points", "15 3 21 3 21 9")])),
      polyline(toList([attribute2("points", "9 21 3 21 3 15")])),
      line(
        toList([
          attribute2("y2", "10"),
          attribute2("y1", "3"),
          attribute2("x2", "14"),
          attribute2("x1", "21")
        ])
      ),
      line(
        toList([
          attribute2("y2", "14"),
          attribute2("y1", "21"),
          attribute2("x2", "10"),
          attribute2("x1", "3")
        ])
      )
    ])
  );
}
function x(attributes) {
  return svg(
    prepend(
      attribute2("stroke-linejoin", "round"),
      prepend(
        attribute2("stroke-linecap", "round"),
        prepend(
          attribute2("stroke-width", "2"),
          prepend(
            attribute2("stroke", "currentColor"),
            prepend(
              attribute2("fill", "none"),
              prepend(
                attribute2("viewBox", "0 0 24 24"),
                prepend(
                  attribute2("height", "24"),
                  prepend(attribute2("width", "24"), attributes)
                )
              )
            )
          )
        )
      )
    ),
    toList([
      path(toList([attribute2("d", "M18 6 6 18")])),
      path(toList([attribute2("d", "m6 6 12 12")]))
    ])
  );
}
function pencil(attributes) {
  return svg(
    prepend(
      attribute2("stroke-linejoin", "round"),
      prepend(
        attribute2("stroke-linecap", "round"),
        prepend(
          attribute2("stroke-width", "2"),
          prepend(
            attribute2("stroke", "currentColor"),
            prepend(
              attribute2("fill", "none"),
              prepend(
                attribute2("viewBox", "0 0 24 24"),
                prepend(
                  attribute2("height", "24"),
                  prepend(attribute2("width", "24"), attributes)
                )
              )
            )
          )
        )
      )
    ),
    toList([
      path(
        toList([
          attribute2(
            "d",
            "M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"
          )
        ])
      ),
      path(toList([attribute2("d", "m15 5 4 4")]))
    ])
  );
}

// build/dev/javascript/o11a_client/lib/eventx.mjs
function on_ctrl_enter(msg) {
  return on(
    "keydown",
    field(
      "ctrlKey",
      bool,
      (ctrl_key) => {
        return field(
          "key",
          string3,
          (key2) => {
            if (ctrl_key && key2 === "Enter") {
              return success(msg);
            } else {
              return failure(msg, "ctrl_enter");
            }
          }
        );
      }
    )
  );
}

// build/dev/javascript/o11a_client/o11a/ui/discussion.mjs
var Model2 = class extends CustomType {
  constructor(is_reference, show_reference_discussion, user_name, line_number, column_number, topic_id, topic_title, current_note_draft, current_thread_id, active_thread, show_expanded_message_box, current_expanded_message_draft, expanded_messages, editing_note) {
    super();
    this.is_reference = is_reference;
    this.show_reference_discussion = show_reference_discussion;
    this.user_name = user_name;
    this.line_number = line_number;
    this.column_number = column_number;
    this.topic_id = topic_id;
    this.topic_title = topic_title;
    this.current_note_draft = current_note_draft;
    this.current_thread_id = current_thread_id;
    this.active_thread = active_thread;
    this.show_expanded_message_box = show_expanded_message_box;
    this.current_expanded_message_draft = current_expanded_message_draft;
    this.expanded_messages = expanded_messages;
    this.editing_note = editing_note;
  }
};
var ActiveThread = class extends CustomType {
  constructor(current_thread_id, parent_note, prior_thread_id, prior_thread) {
    super();
    this.current_thread_id = current_thread_id;
    this.parent_note = parent_note;
    this.prior_thread_id = prior_thread_id;
    this.prior_thread = prior_thread;
  }
};
var UserWroteNote = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var UserSubmittedNote = class extends CustomType {
};
var UserSwitchedToThread = class extends CustomType {
  constructor(new_thread_id, parent_note) {
    super();
    this.new_thread_id = new_thread_id;
    this.parent_note = parent_note;
  }
};
var UserClosedThread = class extends CustomType {
};
var UserToggledExpandedMessageBox = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var UserWroteExpandedMessage = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var UserToggledExpandedMessage = class extends CustomType {
  constructor(for_note_id) {
    super();
    this.for_note_id = for_note_id;
  }
};
var UserFocusedInput = class extends CustomType {
};
var UserFocusedExpandedInput = class extends CustomType {
};
var UserUnfocusedInput = class extends CustomType {
};
var UserMaximizeThread = class extends CustomType {
};
var UserEditedNote = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var UserCancelledEdit = class extends CustomType {
};
var UserToggledReferenceDiscussion = class extends CustomType {
};
var SubmitNote = class extends CustomType {
  constructor(note, topic_id) {
    super();
    this.note = note;
    this.topic_id = topic_id;
  }
};
var FocusDiscussionInput = class extends CustomType {
  constructor(line_number, column_number) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
  }
};
var FocusExpandedDiscussionInput = class extends CustomType {
  constructor(line_number, column_number) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
  }
};
var UnfocusDiscussionInput = class extends CustomType {
  constructor(line_number, column_number) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
  }
};
var MaximizeDiscussion = class extends CustomType {
  constructor(line_number, column_number) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
  }
};
var None3 = class extends CustomType {
};
function init3(line_number, column_number, topic_id, topic_title, is_reference) {
  return new Model2(
    is_reference,
    false,
    "guest",
    line_number,
    column_number,
    topic_id,
    topic_title,
    "",
    topic_id,
    new None(),
    false,
    new None(),
    new$(),
    new None()
  );
}
function reference_header_view(model, current_thread_notes) {
  return fragment2(
    toList([
      div(
        toList([
          class$(
            "flex items-start justify-between width-full mb-[.5rem]"
          )
        ]),
        toList([
          span(
            toList([class$("pt-[.1rem] underline")]),
            toList([
              a(
                toList([href("/" + model.topic_id)]),
                toList([text3(model.topic_title)])
              )
            ])
          ),
          button(
            toList([
              on_click(new UserToggledReferenceDiscussion()),
              class$("icon-button p-[.3rem]")
            ]),
            toList([messages_square(toList([]))])
          )
        ])
      ),
      div(
        toList([
          class$(
            "flex flex-col overflow-auto max-h-[30rem] gap-[.5rem]"
          )
        ]),
        filter_map(
          current_thread_notes,
          (note) => {
            let $ = isEqual(
              note.significance,
              new Informational2()
            );
            if ($) {
              return new Ok(
                p(
                  toList([]),
                  toList([
                    text3(
                      note.message + (() => {
                        let $1 = is_some(note.expanded_message);
                        if ($1) {
                          return "^";
                        } else {
                          return "";
                        }
                      })()
                    )
                  ])
                )
              );
            } else {
              return new Error(void 0);
            }
          }
        )
      )
    ])
  );
}
function thread_header_view(model) {
  let $ = model.active_thread;
  if ($ instanceof Some) {
    let active_thread = $[0];
    return div(
      toList([]),
      toList([
        div(
          toList([class$("flex justify-end width-full")]),
          toList([
            button(
              toList([
                on_click(new UserClosedThread()),
                class$(
                  "icon-button flex gap-[.5rem] pl-[.5rem] pr-[.3rem] pt-[.3rem] pb-[.1rem] mb-[.25rem]"
                )
              ]),
              toList([text3("Close Thread"), x(toList([]))])
            )
          ])
        ),
        text3("Current Thread: "),
        text3(active_thread.parent_note.message),
        (() => {
          let $1 = active_thread.parent_note.expanded_message;
          if ($1 instanceof Some) {
            let expanded_message = $1[0];
            return div(
              toList([class$("mt-[.5rem]")]),
              toList([
                p(toList([]), toList([text3(expanded_message)]))
              ])
            );
          } else {
            return fragment2(toList([]));
          }
        })(),
        hr(toList([class$("mt-[.5rem]")]))
      ])
    );
  } else {
    return div(
      toList([
        class$(
          "flex items-start justify-between width-full mb-[.5rem]"
        )
      ]),
      toList([
        span(
          toList([class$("pt-[.1rem] underline")]),
          toList([
            (() => {
              let $1 = model.is_reference;
              if ($1) {
                return a(
                  toList([href("/" + model.topic_id)]),
                  toList([text3(model.topic_title)])
                );
              } else {
                return text3(model.topic_title);
              }
            })()
          ])
        ),
        div(
          toList([]),
          toList([
            (() => {
              let $1 = model.is_reference;
              if ($1) {
                return button(
                  toList([
                    on_click(new UserToggledReferenceDiscussion()),
                    class$("icon-button p-[.3rem] mr-[.5rem]")
                  ]),
                  toList([x(toList([]))])
                );
              } else {
                return fragment2(toList([]));
              }
            })(),
            button(
              toList([
                on_click(new UserMaximizeThread()),
                class$("icon-button p-[.3rem] ")
              ]),
              toList([maximize_2(toList([]))])
            )
          ])
        )
      ])
    );
  }
}
function significance_badge_view(sig) {
  let badge_style = "input-border rounded-md text-[0.65rem] pb-[0.15rem] pt-1 px-[0.5rem]";
  let $ = significance_to_string(sig);
  if ($ instanceof Some) {
    let significance = $[0];
    return span(
      toList([class$(badge_style)]),
      toList([text3(significance)])
    );
  } else {
    return fragment2(toList([]));
  }
}
function comments_view(model, current_thread_notes) {
  return div(
    toList([
      class$(
        "flex flex-col-reverse overflow-auto max-h-[30rem] gap-[.5rem] mb-[.5rem]"
      )
    ]),
    map2(
      current_thread_notes,
      (note) => {
        return div(
          toList([class$("line-discussion-item")]),
          toList([
            div(
              toList([class$("flex justify-between mb-[.2rem]")]),
              toList([
                div(
                  toList([class$("flex gap-[.5rem] items-start")]),
                  toList([
                    p(toList([]), toList([text3(note.user_name)])),
                    significance_badge_view(note.significance)
                  ])
                ),
                div(
                  toList([class$("flex gap-[.5rem]")]),
                  toList([
                    button(
                      toList([
                        id("edit-message-button"),
                        class$("icon-button p-[.3rem]"),
                        on_click(new UserEditedNote(new Ok(note)))
                      ]),
                      toList([pencil(toList([]))])
                    ),
                    (() => {
                      let $ = note.expanded_message;
                      if ($ instanceof Some) {
                        return button(
                          toList([
                            id("expand-message-button"),
                            class$("icon-button p-[.3rem]"),
                            on_click(
                              new UserToggledExpandedMessage(note.note_id)
                            )
                          ]),
                          toList([list_collapse(toList([]))])
                        );
                      } else {
                        return fragment2(toList([]));
                      }
                    })(),
                    (() => {
                      let $ = is_significance_threadable(
                        note.significance
                      );
                      if ($) {
                        return button(
                          toList([
                            id("switch-thread-button"),
                            class$("icon-button p-[.3rem]"),
                            on_click(
                              new UserSwitchedToThread(note.note_id, note)
                            )
                          ]),
                          toList([messages_square(toList([]))])
                        );
                      } else {
                        return fragment2(toList([]));
                      }
                    })()
                  ])
                )
              ])
            ),
            p(toList([]), toList([text3(note.message)])),
            (() => {
              let $ = contains2(model.expanded_messages, note.note_id);
              if ($) {
                return div(
                  toList([class$("mt-[.5rem]")]),
                  toList([
                    p(
                      toList([]),
                      toList([
                        text3(
                          (() => {
                            let _pipe = note.expanded_message;
                            return unwrap(_pipe, "");
                          })()
                        )
                      ])
                    )
                  ])
                );
              } else {
                return fragment2(toList([]));
              }
            })(),
            hr(toList([class$("mt-[.5rem]")]))
          ])
        );
      }
    )
  );
}
function expand_message_input_view(model) {
  return textarea(
    toList([
      id("expanded-message-box"),
      class$("grow text-[.95rem] resize-none p-[.3rem]"),
      placeholder("Write an expanded message body"),
      on_input((var0) => {
        return new UserWroteExpandedMessage(var0);
      }),
      on_focus(new UserFocusedExpandedInput()),
      on_blur(new UserUnfocusedInput()),
      on_ctrl_enter(new UserSubmittedNote())
    ]),
    (() => {
      let _pipe = model.current_expanded_message_draft;
      return unwrap(_pipe, "");
    })()
  );
}
function expanded_message_view(model) {
  let expanded_message_style = "absolute overlay p-[.5rem] flex w-[100%] h-60 mt-2";
  return div(
    toList([
      id("expanded-message"),
      (() => {
        let $ = model.show_expanded_message_box;
        if ($) {
          return class$(expanded_message_style + " show-exp");
        } else {
          return class$(expanded_message_style);
        }
      })()
    ]),
    toList([expand_message_input_view(model)])
  );
}
function classify_message(message, is_thread_open) {
  if (!is_thread_open) {
    if (message.startsWith("todo: ")) {
      let rest = message.slice(6);
      return [new ToDo(), rest];
    } else if (message.startsWith("q: ")) {
      let rest = message.slice(3);
      return [new Question(), rest];
    } else if (message.startsWith("question: ")) {
      let rest = message.slice(10);
      return [new Question(), rest];
    } else if (message.startsWith("finding: ")) {
      let rest = message.slice(9);
      return [new FindingLead(), rest];
    } else if (message.startsWith("dev: ")) {
      let rest = message.slice(5);
      return [new DevelperQuestion(), rest];
    } else if (message.startsWith("info: ")) {
      let rest = message.slice(6);
      return [new Informational(), rest];
    } else {
      return [new Comment(), message];
    }
  } else {
    if (message === "done") {
      return [new ToDoCompletion(), "done"];
    } else if (message.startsWith("done: ")) {
      let rest = message.slice(6);
      return [new ToDoCompletion(), rest];
    } else if (message.startsWith("a: ")) {
      let rest = message.slice(3);
      return [new Answer(), rest];
    } else if (message.startsWith("answer: ")) {
      let rest = message.slice(8);
      return [new Answer(), rest];
    } else if (message.startsWith("reject: ")) {
      let rest = message.slice(8);
      return [new FindingRejection(), rest];
    } else if (message.startsWith("confirm: ")) {
      let rest = message.slice(9);
      return [new FindingConfirmation(), rest];
    } else if (message.startsWith("incorrect: ")) {
      let rest = message.slice(11);
      return [new InformationalRejection(), rest];
    } else if (message.startsWith("correct: ")) {
      let rest = message.slice(9);
      return [new InformationalConfirmation(), rest];
    } else {
      return [new Comment(), message];
    }
  }
}
function get_message_classification_prefix(significance) {
  if (significance instanceof Answer2) {
    return "a: ";
  } else if (significance instanceof AnsweredDeveloperQuestion) {
    return "dev: ";
  } else if (significance instanceof AnsweredQuestion) {
    return "q: ";
  } else if (significance instanceof Comment2) {
    return "";
  } else if (significance instanceof CompleteToDo) {
    return "todo: ";
  } else if (significance instanceof ConfirmedFinding) {
    return "finding: ";
  } else if (significance instanceof FindingConfirmation2) {
    return "confirm: ";
  } else if (significance instanceof FindingRejection2) {
    return "reject: ";
  } else if (significance instanceof IncompleteToDo) {
    return "todo: ";
  } else if (significance instanceof Informational2) {
    return "info: ";
  } else if (significance instanceof InformationalConfirmation2) {
    return "correct: ";
  } else if (significance instanceof InformationalRejection2) {
    return "incorrect: ";
  } else if (significance instanceof RejectedFinding) {
    return "finding: ";
  } else if (significance instanceof RejectedInformational) {
    return "info: ";
  } else if (significance instanceof ToDoCompletion2) {
    return "done: ";
  } else if (significance instanceof UnansweredDeveloperQuestion) {
    return "dev: ";
  } else if (significance instanceof UnansweredQuestion) {
    return "q: ";
  } else {
    return "finding: ";
  }
}
function update2(model, msg) {
  if (msg instanceof UserWroteNote) {
    let draft = msg[0];
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.is_reference,
          _record.show_reference_discussion,
          _record.user_name,
          _record.line_number,
          _record.column_number,
          _record.topic_id,
          _record.topic_title,
          draft,
          _record.current_thread_id,
          _record.active_thread,
          _record.show_expanded_message_box,
          _record.current_expanded_message_draft,
          _record.expanded_messages,
          _record.editing_note
        );
      })(),
      new None3()
    ];
  } else if (msg instanceof UserSubmittedNote) {
    let $ = classify_message(
      (() => {
        let _pipe = model.current_note_draft;
        return trim(_pipe);
      })(),
      is_some(model.active_thread)
    );
    let significance = $[0];
    let message = $[1];
    return that(
      model.current_note_draft === "",
      () => {
        return [model, new None3()];
      },
      () => {
        let _block;
        let $2 = model.editing_note;
        if ($2 instanceof Some) {
          let note2 = $2[0];
          _block = [new Edit(), note2.note_id];
        } else {
          _block = [new None2(), model.current_thread_id];
        }
        let $1 = _block;
        let modifier = $1[0];
        let parent_id = $1[1];
        let _block$1;
        let $3 = (() => {
          let _pipe = model.current_expanded_message_draft;
          return map(_pipe, trim);
        })();
        if ($3 instanceof Some && $3[0] === "") {
          _block$1 = new None();
        } else {
          let msg$1 = $3;
          _block$1 = msg$1;
        }
        let expanded_message = _block$1;
        let note = new NoteSubmission(
          parent_id,
          significance,
          "user" + (() => {
            let _pipe = random(100);
            return to_string(_pipe);
          })(),
          message,
          expanded_message,
          modifier
        );
        return [
          (() => {
            let _record = model;
            return new Model2(
              _record.is_reference,
              _record.show_reference_discussion,
              _record.user_name,
              _record.line_number,
              _record.column_number,
              _record.topic_id,
              _record.topic_title,
              "",
              _record.current_thread_id,
              _record.active_thread,
              false,
              new None(),
              _record.expanded_messages,
              new None()
            );
          })(),
          new SubmitNote(note, model.topic_id)
        ];
      }
    );
  } else if (msg instanceof UserSwitchedToThread) {
    let new_thread_id = msg.new_thread_id;
    let parent_note = msg.parent_note;
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.is_reference,
          _record.show_reference_discussion,
          _record.user_name,
          _record.line_number,
          _record.column_number,
          _record.topic_id,
          _record.topic_title,
          _record.current_note_draft,
          new_thread_id,
          new Some(
            new ActiveThread(
              new_thread_id,
              parent_note,
              model.current_thread_id,
              model.active_thread
            )
          ),
          _record.show_expanded_message_box,
          _record.current_expanded_message_draft,
          _record.expanded_messages,
          _record.editing_note
        );
      })(),
      new None3()
    ];
  } else if (msg instanceof UserClosedThread) {
    let _block;
    let _pipe = model.active_thread;
    let _pipe$1 = map(
      _pipe,
      (thread) => {
        return thread.prior_thread;
      }
    );
    _block = flatten(_pipe$1);
    let new_active_thread = _block;
    let _block$1;
    let _pipe$2 = map(
      new_active_thread,
      (thread) => {
        return thread.current_thread_id;
      }
    );
    _block$1 = unwrap(_pipe$2, model.topic_id);
    let new_current_thread_id = _block$1;
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.is_reference,
          _record.show_reference_discussion,
          _record.user_name,
          _record.line_number,
          _record.column_number,
          _record.topic_id,
          _record.topic_title,
          _record.current_note_draft,
          new_current_thread_id,
          new_active_thread,
          _record.show_expanded_message_box,
          _record.current_expanded_message_draft,
          _record.expanded_messages,
          _record.editing_note
        );
      })(),
      new None3()
    ];
  } else if (msg instanceof UserToggledExpandedMessageBox) {
    let show_expanded_message_box = msg[0];
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.is_reference,
          _record.show_reference_discussion,
          _record.user_name,
          _record.line_number,
          _record.column_number,
          _record.topic_id,
          _record.topic_title,
          _record.current_note_draft,
          _record.current_thread_id,
          _record.active_thread,
          show_expanded_message_box,
          _record.current_expanded_message_draft,
          _record.expanded_messages,
          _record.editing_note
        );
      })(),
      new None3()
    ];
  } else if (msg instanceof UserWroteExpandedMessage) {
    let expanded_message = msg[0];
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.is_reference,
          _record.show_reference_discussion,
          _record.user_name,
          _record.line_number,
          _record.column_number,
          _record.topic_id,
          _record.topic_title,
          _record.current_note_draft,
          _record.current_thread_id,
          _record.active_thread,
          _record.show_expanded_message_box,
          new Some(expanded_message),
          _record.expanded_messages,
          _record.editing_note
        );
      })(),
      new None3()
    ];
  } else if (msg instanceof UserToggledExpandedMessage) {
    let for_note_id = msg.for_note_id;
    let $ = contains2(model.expanded_messages, for_note_id);
    if ($) {
      return [
        (() => {
          let _record = model;
          return new Model2(
            _record.is_reference,
            _record.show_reference_discussion,
            _record.user_name,
            _record.line_number,
            _record.column_number,
            _record.topic_id,
            _record.topic_title,
            _record.current_note_draft,
            _record.current_thread_id,
            _record.active_thread,
            _record.show_expanded_message_box,
            _record.current_expanded_message_draft,
            delete$2(model.expanded_messages, for_note_id),
            _record.editing_note
          );
        })(),
        new None3()
      ];
    } else {
      return [
        (() => {
          let _record = model;
          return new Model2(
            _record.is_reference,
            _record.show_reference_discussion,
            _record.user_name,
            _record.line_number,
            _record.column_number,
            _record.topic_id,
            _record.topic_title,
            _record.current_note_draft,
            _record.current_thread_id,
            _record.active_thread,
            _record.show_expanded_message_box,
            _record.current_expanded_message_draft,
            insert2(model.expanded_messages, for_note_id),
            _record.editing_note
          );
        })(),
        new None3()
      ];
    }
  } else if (msg instanceof UserFocusedInput) {
    return [
      model,
      new FocusDiscussionInput(model.line_number, model.column_number)
    ];
  } else if (msg instanceof UserFocusedExpandedInput) {
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.is_reference,
          _record.show_reference_discussion,
          _record.user_name,
          _record.line_number,
          _record.column_number,
          _record.topic_id,
          _record.topic_title,
          _record.current_note_draft,
          _record.current_thread_id,
          _record.active_thread,
          true,
          _record.current_expanded_message_draft,
          _record.expanded_messages,
          _record.editing_note
        );
      })(),
      new FocusExpandedDiscussionInput(model.line_number, model.column_number)
    ];
  } else if (msg instanceof UserUnfocusedInput) {
    return [
      model,
      new UnfocusDiscussionInput(model.line_number, model.column_number)
    ];
  } else if (msg instanceof UserMaximizeThread) {
    return [
      model,
      new MaximizeDiscussion(model.line_number, model.column_number)
    ];
  } else if (msg instanceof UserEditedNote) {
    let note = msg[0];
    if (note.isOk()) {
      let note$1 = note[0];
      return [
        (() => {
          let _record = model;
          return new Model2(
            _record.is_reference,
            _record.show_reference_discussion,
            _record.user_name,
            _record.line_number,
            _record.column_number,
            _record.topic_id,
            _record.topic_title,
            get_message_classification_prefix(note$1.significance) + note$1.message,
            _record.current_thread_id,
            _record.active_thread,
            (() => {
              let $ = note$1.expanded_message;
              if ($ instanceof Some) {
                return true;
              } else {
                return false;
              }
            })(),
            note$1.expanded_message,
            _record.expanded_messages,
            new Some(note$1)
          );
        })(),
        new None3()
      ];
    } else {
      return [model, new None3()];
    }
  } else if (msg instanceof UserCancelledEdit) {
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.is_reference,
          _record.show_reference_discussion,
          _record.user_name,
          _record.line_number,
          _record.column_number,
          _record.topic_id,
          _record.topic_title,
          "",
          _record.current_thread_id,
          _record.active_thread,
          false,
          new None(),
          _record.expanded_messages,
          new None()
        );
      })(),
      new None3()
    ];
  } else {
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.is_reference,
          !model.show_reference_discussion,
          _record.user_name,
          _record.line_number,
          _record.column_number,
          _record.topic_id,
          _record.topic_title,
          _record.current_note_draft,
          _record.current_thread_id,
          _record.active_thread,
          _record.show_expanded_message_box,
          _record.current_expanded_message_draft,
          _record.expanded_messages,
          _record.editing_note
        );
      })(),
      new None3()
    ];
  }
}
function on_input_keydown(enter_msg, up_msg) {
  return on(
    "keydown",
    field(
      "ctrlKey",
      bool,
      (ctrl_key) => {
        return field(
          "key",
          string3,
          (key2) => {
            if (ctrl_key && key2 === "Enter") {
              return success(enter_msg);
            } else if (key2 === "ArrowUp") {
              return success(up_msg);
            } else {
              return failure(enter_msg, "input_keydown");
            }
          }
        );
      }
    )
  );
}
function new_message_input_view(model, current_thread_notes) {
  return div(
    toList([class$("flex justify-between items-center gap-[.35rem]")]),
    toList([
      button(
        toList([
          id("toggle-expanded-message-button"),
          class$("icon-button p-[.3rem]"),
          on_click(
            new UserToggledExpandedMessageBox(!model.show_expanded_message_box)
          )
        ]),
        toList([pencil_ruler(toList([]))])
      ),
      (() => {
        let $ = model.editing_note;
        if ($ instanceof Some) {
          return button(
            toList([
              id("cancel-message-edit-button"),
              class$("icon-button p-[.3rem]"),
              on_click(new UserCancelledEdit())
            ]),
            toList([x(toList([]))])
          );
        } else {
          return fragment2(toList([]));
        }
      })(),
      input(
        toList([
          id("new-comment-input"),
          class$(
            "inline-block w-full grow text-[0.9rem] pl-2 pb-[.2rem] p-[0.3rem] border-[none] border-t border-solid;"
          ),
          placeholder("Add a new comment"),
          on_input((var0) => {
            return new UserWroteNote(var0);
          }),
          on_focus(new UserFocusedInput()),
          on_blur(new UserUnfocusedInput()),
          on_input_keydown(
            new UserSubmittedNote(),
            new UserEditedNote(first(current_thread_notes))
          ),
          value(model.current_note_draft)
        ])
      )
    ])
  );
}
function overlay_view(model, notes) {
  let _block;
  let _pipe = map_get(notes, model.current_thread_id);
  _block = unwrap2(_pipe, toList([]));
  let current_thread_notes = _block;
  return div(
    toList([
      class$(
        "absolute z-[3] w-[30rem] not-italic text-wrap select-text text left-[-.3rem]"
      ),
      (() => {
        let $ = model.line_number < 30;
        if ($) {
          return class$("top-[1.75rem]");
        } else {
          return class$("bottom-[1.75rem]");
        }
      })()
    ]),
    toList([
      (() => {
        let $ = model.is_reference && !model.show_reference_discussion;
        if ($) {
          return div(
            toList([class$("overlay p-[.5rem]")]),
            toList([reference_header_view(model, current_thread_notes)])
          );
        } else {
          return fragment2(
            toList([
              div(
                toList([class$("overlay p-[.5rem]")]),
                toList([
                  thread_header_view(model),
                  (() => {
                    let $1 = is_some(model.active_thread) || length(
                      current_thread_notes
                    ) > 0;
                    if ($1) {
                      return comments_view(model, current_thread_notes);
                    } else {
                      return fragment2(toList([]));
                    }
                  })(),
                  new_message_input_view(model, current_thread_notes)
                ])
              ),
              expanded_message_view(model)
            ])
          );
        }
      })()
    ])
  );
}
function panel_view(model, notes) {
  let _block;
  let _pipe = map_get(notes, model.current_thread_id);
  _block = unwrap2(_pipe, toList([]));
  let current_thread_notes = _block;
  return div(
    toList([style("padding", ".5rem")]),
    toList([
      (() => {
        let $ = model.is_reference;
        if ($) {
          return reference_header_view(model, current_thread_notes);
        } else {
          return fragment2(toList([]));
        }
      })(),
      thread_header_view(model),
      (() => {
        let $ = is_some(model.active_thread) || length(
          current_thread_notes
        ) > 0;
        if ($) {
          return comments_view(model, current_thread_notes);
        } else {
          return fragment2(toList([]));
        }
      })(),
      new_message_input_view(model, current_thread_notes),
      (() => {
        let $ = model.show_expanded_message_box;
        if ($) {
          return expand_message_input_view(model);
        } else {
          return fragment2(toList([]));
        }
      })()
    ])
  );
}

// build/dev/javascript/o11a_client/o11a/ui/audit_page.mjs
var DiscussionReference = class extends CustomType {
  constructor(line_number, column_number, model) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
    this.model = model;
  }
};
var UserSelectedDiscussionEntry = class extends CustomType {
  constructor(kind, line_number, column_number, node_id, topic_id, topic_title, is_reference) {
    super();
    this.kind = kind;
    this.line_number = line_number;
    this.column_number = column_number;
    this.node_id = node_id;
    this.topic_id = topic_id;
    this.topic_title = topic_title;
    this.is_reference = is_reference;
  }
};
var UserUnselectedDiscussionEntry = class extends CustomType {
  constructor(kind) {
    super();
    this.kind = kind;
  }
};
var UserClickedDiscussionEntry = class extends CustomType {
  constructor(line_number, column_number) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
  }
};
var UserUpdatedDiscussion = class extends CustomType {
  constructor(line_number, column_number, update4) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
    this.update = update4;
  }
};
var UserClickedInsideDiscussion = class extends CustomType {
  constructor(line_number, column_number) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
  }
};
var EntryHover = class extends CustomType {
};
var EntryFocus = class extends CustomType {
};
function map_discussion_msg(msg, selected_discussion) {
  return new UserUpdatedDiscussion(
    selected_discussion.line_number,
    selected_discussion.column_number,
    update2(selected_discussion.model, msg)
  );
}
function discussion_view(attrs, discussion, element_line_number, element_column_number, selected_discussion) {
  if (selected_discussion instanceof Some) {
    let selected_discussion$1 = selected_discussion[0];
    let $ = element_line_number === selected_discussion$1.line_number && element_column_number === selected_discussion$1.column_number;
    if ($) {
      return div(
        attrs,
        toList([
          (() => {
            let _pipe = overlay_view(
              selected_discussion$1.model,
              discussion
            );
            return map5(
              _pipe,
              (_capture) => {
                return map_discussion_msg(_capture, selected_discussion$1);
              }
            );
          })()
        ])
      );
    } else {
      return fragment2(toList([]));
    }
  } else {
    return fragment2(toList([]));
  }
}
function inline_comment_preview_view(parent_notes, topic_id, topic_title, element_line_number, element_column_number, selected_discussion, discussion) {
  let note_result = find(
    parent_notes,
    (note) => {
      return !isEqual(note.significance, new Informational2());
    }
  );
  if (note_result.isOk()) {
    let note = note_result[0];
    return span(
      toList([
        class$("relative"),
        encode_grid_location_data(
          (() => {
            let _pipe = element_line_number;
            return to_string(_pipe);
          })(),
          (() => {
            let _pipe = element_column_number;
            return to_string(_pipe);
          })()
        )
      ]),
      toList([
        span(
          toList([
            class$(
              "inline-comment font-code code-extras font-code fade-in"
            ),
            class$("comment-preview"),
            class$(discussion_entry),
            attribute2("tabindex", "0"),
            on_focus(
              new UserSelectedDiscussionEntry(
                new EntryFocus(),
                element_line_number,
                element_column_number,
                new None(),
                topic_id,
                topic_title,
                false
              )
            ),
            on_blur(new UserUnselectedDiscussionEntry(new EntryFocus())),
            on_mouse_enter(
              new UserSelectedDiscussionEntry(
                new EntryHover(),
                element_line_number,
                element_column_number,
                new None(),
                topic_id,
                topic_title,
                false
              )
            ),
            on_mouse_leave(
              new UserUnselectedDiscussionEntry(new EntryHover())
            ),
            (() => {
              let _pipe = on_click(
                new UserClickedDiscussionEntry(
                  element_line_number,
                  element_column_number
                )
              );
              return stop_propagation(_pipe);
            })()
          ]),
          toList([
            text3(
              (() => {
                let $ = string_length(note.message) > 40;
                if ($) {
                  return (() => {
                    let _pipe = note.message;
                    return slice(_pipe, 0, 37);
                  })() + "...";
                } else {
                  let _pipe = note.message;
                  return slice(_pipe, 0, 40);
                }
              })()
            )
          ])
        ),
        discussion_view(
          toList([
            (() => {
              let _pipe = on_click(
                new UserClickedInsideDiscussion(
                  element_line_number,
                  element_column_number
                )
              );
              return stop_propagation(_pipe);
            })()
          ]),
          discussion,
          element_line_number,
          element_column_number,
          selected_discussion
        )
      ])
    );
  } else {
    return span(
      toList([
        class$("relative"),
        encode_grid_location_data(
          (() => {
            let _pipe = element_line_number;
            return to_string(_pipe);
          })(),
          (() => {
            let _pipe = element_column_number;
            return to_string(_pipe);
          })()
        )
      ]),
      toList([
        span(
          toList([
            class$("inline-comment font-code code-extras"),
            class$("new-thread-preview"),
            class$(discussion_entry),
            attribute2("tabindex", "0"),
            on_focus(
              new UserSelectedDiscussionEntry(
                new EntryFocus(),
                element_line_number,
                element_column_number,
                new None(),
                topic_id,
                topic_title,
                false
              )
            ),
            on_blur(new UserUnselectedDiscussionEntry(new EntryFocus())),
            on_mouse_enter(
              new UserSelectedDiscussionEntry(
                new EntryHover(),
                element_line_number,
                element_column_number,
                new None(),
                topic_id,
                topic_title,
                false
              )
            ),
            on_mouse_leave(
              new UserUnselectedDiscussionEntry(new EntryHover())
            ),
            (() => {
              let _pipe = on_click(
                new UserClickedDiscussionEntry(
                  element_line_number,
                  element_column_number
                )
              );
              return stop_propagation(_pipe);
            })()
          ]),
          toList([text3("Start new thread")])
        ),
        discussion_view(
          toList([
            (() => {
              let _pipe = on_click(
                new UserClickedInsideDiscussion(
                  element_line_number,
                  element_column_number
                )
              );
              return stop_propagation(_pipe);
            })()
          ]),
          discussion,
          element_line_number,
          element_column_number,
          selected_discussion
        )
      ])
    );
  }
}
function declaration_node_view(node_id, node_declaration, tokens, discussion, element_line_number, element_column_number, selected_discussion) {
  return span(
    toList([
      class$("relative"),
      encode_grid_location_data(
        (() => {
          let _pipe = element_line_number;
          return to_string(_pipe);
        })(),
        (() => {
          let _pipe = element_column_number;
          return to_string(_pipe);
        })()
      )
    ]),
    toList([
      span(
        toList([
          id(node_declaration.topic_id),
          class$(
            node_declaration_kind_to_string(node_declaration.kind)
          ),
          class$("declaration-preview N" + to_string(node_id)),
          class$(discussion_entry),
          class$(discussion_entry_hover),
          attribute2("tabindex", "0"),
          encode_topic_id_data(node_declaration.topic_id),
          encode_topic_title_data(node_declaration.title),
          encode_is_reference_data(false),
          on_focus(
            new UserSelectedDiscussionEntry(
              new EntryFocus(),
              element_line_number,
              element_column_number,
              new Some(node_id),
              node_declaration.topic_id,
              node_declaration.title,
              false
            )
          ),
          on_blur(new UserUnselectedDiscussionEntry(new EntryFocus())),
          on_mouse_enter(
            new UserSelectedDiscussionEntry(
              new EntryHover(),
              element_line_number,
              element_column_number,
              new Some(node_id),
              node_declaration.topic_id,
              node_declaration.title,
              false
            )
          ),
          on_mouse_leave(
            new UserUnselectedDiscussionEntry(new EntryHover())
          ),
          (() => {
            let _pipe = on_click(
              new UserClickedDiscussionEntry(
                element_line_number,
                element_column_number
              )
            );
            return stop_propagation(_pipe);
          })()
        ]),
        toList([text3(tokens)])
      ),
      discussion_view(
        toList([
          (() => {
            let _pipe = on_click(
              new UserClickedInsideDiscussion(
                element_line_number,
                element_column_number
              )
            );
            return stop_propagation(_pipe);
          })()
        ]),
        discussion,
        element_line_number,
        element_column_number,
        selected_discussion
      )
    ])
  );
}
function reference_node_view(referenced_node_id, referenced_node_declaration, tokens, discussion, element_line_number, element_column_number, selected_discussion) {
  return span(
    toList([
      class$("relative"),
      encode_grid_location_data(
        (() => {
          let _pipe = element_line_number;
          return to_string(_pipe);
        })(),
        (() => {
          let _pipe = element_column_number;
          return to_string(_pipe);
        })()
      )
    ]),
    toList([
      span(
        toList([
          class$(
            node_declaration_kind_to_string(
              referenced_node_declaration.kind
            )
          ),
          class$(
            "reference-preview N" + to_string(referenced_node_id)
          ),
          class$(discussion_entry),
          class$(discussion_entry_hover),
          attribute2("tabindex", "0"),
          encode_topic_id_data(referenced_node_declaration.topic_id),
          encode_topic_title_data(referenced_node_declaration.title),
          encode_is_reference_data(true),
          on_focus(
            new UserSelectedDiscussionEntry(
              new EntryFocus(),
              element_line_number,
              element_column_number,
              new Some(referenced_node_id),
              referenced_node_declaration.topic_id,
              referenced_node_declaration.title,
              true
            )
          ),
          on_blur(new UserUnselectedDiscussionEntry(new EntryFocus())),
          on_mouse_enter(
            new UserSelectedDiscussionEntry(
              new EntryHover(),
              element_line_number,
              element_column_number,
              new Some(referenced_node_id),
              referenced_node_declaration.topic_id,
              referenced_node_declaration.title,
              true
            )
          ),
          on_mouse_leave(
            new UserUnselectedDiscussionEntry(new EntryHover())
          ),
          (() => {
            let _pipe = on_click(
              new UserClickedDiscussionEntry(
                element_line_number,
                element_column_number
              )
            );
            return stop_propagation(_pipe);
          })()
        ]),
        toList([text3(tokens)])
      ),
      discussion_view(
        toList([
          (() => {
            let _pipe = on_click(
              new UserClickedInsideDiscussion(
                element_line_number,
                element_column_number
              )
            );
            return stop_propagation(_pipe);
          })()
        ]),
        discussion,
        element_line_number,
        element_column_number,
        selected_discussion
      )
    ])
  );
}
function preprocessed_nodes_view(loc, discussion, selected_discussion) {
  let _pipe = map_fold(
    loc.elements,
    0,
    (index5, element4) => {
      if (element4 instanceof PreProcessedDeclaration) {
        let node_id = element4.node_id;
        let node_declaration = element4.node_declaration;
        let tokens = element4.tokens;
        let new_column_index = index5 + 1;
        return [
          new_column_index,
          declaration_node_view(
            node_id,
            node_declaration,
            tokens,
            discussion,
            loc.line_number,
            new_column_index,
            selected_discussion
          )
        ];
      } else if (element4 instanceof PreProcessedReference) {
        let referenced_node_id = element4.referenced_node_id;
        let referenced_node_declaration = element4.referenced_node_declaration;
        let tokens = element4.tokens;
        let new_column_index = index5 + 1;
        return [
          new_column_index,
          reference_node_view(
            referenced_node_id,
            referenced_node_declaration,
            tokens,
            discussion,
            loc.line_number,
            new_column_index,
            selected_discussion
          )
        ];
      } else if (element4 instanceof PreProcessedNode) {
        let element$1 = element4.element;
        return [
          index5,
          unsafe_raw_html(
            "preprocessed-node",
            "span",
            toList([]),
            element$1
          )
        ];
      } else {
        let element$1 = element4.element;
        return [
          index5,
          unsafe_raw_html(
            "preprocessed-node",
            "span",
            toList([]),
            element$1
          )
        ];
      }
    }
  );
  return second(_pipe);
}
function split_info_comment(comment, contains_expanded_message, leading_spaces) {
  let comment_length = string_length(comment);
  let columns_remaining = 80 - leading_spaces;
  let $ = comment_length <= columns_remaining;
  if ($) {
    return toList([
      comment + (() => {
        if (contains_expanded_message) {
          return "^";
        } else {
          return "";
        }
      })()
    ]);
  } else {
    let _block;
    let _pipe = slice(comment, 0, columns_remaining);
    _block = reverse3(_pipe);
    let backwards = _block;
    let _block$1;
    let _pipe$1 = backwards;
    let _pipe$2 = split_once(_pipe$1, " ");
    let _pipe$3 = unwrap2(_pipe$2, ["", backwards]);
    let _pipe$4 = second(_pipe$3);
    _block$1 = string_length(_pipe$4);
    let in_limit_comment_length = _block$1;
    let rest = slice(
      comment,
      in_limit_comment_length + 1,
      comment_length
    );
    return prepend(
      slice(comment, 0, in_limit_comment_length),
      split_info_comment(rest, contains_expanded_message, leading_spaces)
    );
  }
}
function split_info_note(note, leading_spaces) {
  let _pipe = note.message;
  let _pipe$1 = split_info_comment(
    _pipe,
    !isEqual(note.expanded_message, new None()),
    leading_spaces
  );
  return index_map(
    _pipe$1,
    (comment, index5) => {
      return [note.note_id + to_string(index5), comment];
    }
  );
}
function get_notes(discussion, leading_spaces, topic_id) {
  let _block;
  let _pipe = map_get(discussion, topic_id);
  let _pipe$1 = unwrap2(_pipe, toList([]));
  _block = filter_map(
    _pipe$1,
    (note) => {
      let $ = note.parent_id === topic_id;
      if ($) {
        return new Ok(note);
      } else {
        return new Error(void 0);
      }
    }
  );
  let parent_notes = _block;
  let _block$1;
  let _pipe$2 = parent_notes;
  let _pipe$3 = filter(
    _pipe$2,
    (computed_note) => {
      return isEqual(
        computed_note.significance,
        new Informational2()
      );
    }
  );
  let _pipe$4 = map2(
    _pipe$3,
    (_capture) => {
      return split_info_note(_capture, leading_spaces);
    }
  );
  _block$1 = flatten2(_pipe$4);
  let info_notes = _block$1;
  return [parent_notes, info_notes];
}
function line_container_view(discussion, loc, line_topic_id, line_topic_title, selected_discussion) {
  let $ = get_notes(discussion, loc.leading_spaces, line_topic_id);
  let parent_notes = $[0];
  let info_notes = $[1];
  let column_count = loc.columns + 1;
  return div(
    toList([
      id(loc.line_tag),
      class$(line_container),
      encode_column_count_data(column_count)
    ]),
    toList([
      fragment2(
        index_map(
          info_notes,
          (_use0, index5) => {
            let note_message = _use0[1];
            let child = p(
              toList([class$("loc flex")]),
              toList([
                span(
                  toList([class$("line-number code-extras relative")]),
                  toList([
                    text3(loc.line_number_text),
                    span(
                      toList([
                        class$(
                          "absolute code-extras pl-[.1rem] pt-[.15rem] text-[.9rem]"
                        )
                      ]),
                      toList([
                        text3(
                          translate_number_to_letter(index5 + 1)
                        )
                      ])
                    )
                  ])
                ),
                span(
                  toList([class$("comment italic")]),
                  toList([
                    text3(
                      (() => {
                        let _pipe = repeat(" ", loc.leading_spaces);
                        return join(_pipe, "");
                      })() + note_message
                    )
                  ])
                )
              ])
            );
            return child;
          }
        )
      ),
      p(
        toList([class$("loc flex")]),
        toList([
          span(
            toList([class$("line-number code-extras relative")]),
            toList([text3(loc.line_number_text)])
          ),
          fragment2(
            preprocessed_nodes_view(loc, discussion, selected_discussion)
          ),
          inline_comment_preview_view(
            parent_notes,
            line_topic_id,
            line_topic_title,
            loc.line_number,
            column_count,
            selected_discussion,
            discussion
          )
        ])
      )
    ])
  );
}
function loc_view(discussion, loc, selected_discussion) {
  let $ = loc.significance;
  if ($ instanceof EmptyLine) {
    return p(
      toList([class$("loc"), id(loc.line_tag)]),
      prepend(
        span(
          toList([class$("line-number code-extras relative")]),
          toList([text3(loc.line_number_text)])
        ),
        preprocessed_nodes_view(loc, discussion, selected_discussion)
      )
    );
  } else if ($ instanceof SingleDeclarationLine) {
    let topic_id = $.topic_id;
    let topic_title = $.topic_title;
    return line_container_view(
      discussion,
      loc,
      topic_id,
      topic_title,
      selected_discussion
    );
  } else {
    return line_container_view(
      discussion,
      loc,
      loc.line_id,
      loc.line_tag,
      selected_discussion
    );
  }
}
function view(preprocessed_source, discussion, selected_discussion) {
  return div(
    toList([
      id("audit-page"),
      class$("code-snippet"),
      data(
        "lc",
        (() => {
          let _pipe = preprocessed_source;
          let _pipe$1 = length(_pipe);
          return to_string(_pipe$1);
        })()
      )
    ]),
    map2(
      preprocessed_source,
      (_capture) => {
        return loc_view(discussion, _capture, selected_discussion);
      }
    )
  );
}

// build/dev/javascript/filepath/filepath_ffi.mjs
function is_windows() {
  return globalThis?.process?.platform === "win32" || globalThis?.Deno?.build?.os === "windows";
}

// build/dev/javascript/filepath/filepath.mjs
function split_unix(path2) {
  let _block;
  let $ = split2(path2, "/");
  if ($.hasLength(1) && $.head === "") {
    _block = toList([]);
  } else if ($.atLeastLength(1) && $.head === "") {
    let rest = $.tail;
    _block = prepend("/", rest);
  } else {
    let rest = $;
    _block = rest;
  }
  let _pipe = _block;
  return filter(_pipe, (x2) => {
    return x2 !== "";
  });
}
function pop_windows_drive_specifier(path2) {
  let start4 = slice(path2, 0, 3);
  let codepoints = to_utf_codepoints(start4);
  let $ = map2(codepoints, utf_codepoint_to_int);
  if ($.hasLength(3) && (($.tail.tail.head === 47 || $.tail.tail.head === 92) && $.tail.head === 58 && ($.head >= 65 && $.head <= 90 || $.head >= 97 && $.head <= 122))) {
    let drive = $.head;
    let colon = $.tail.head;
    let slash = $.tail.tail.head;
    let drive_letter = slice(path2, 0, 1);
    let drive$1 = lowercase(drive_letter) + ":/";
    let path$1 = drop_start(path2, 3);
    return [new Some(drive$1), path$1];
  } else {
    return [new None(), path2];
  }
}
function split_windows(path2) {
  let $ = pop_windows_drive_specifier(path2);
  let drive = $[0];
  let path$1 = $[1];
  let _block;
  let _pipe = split2(path$1, "/");
  _block = flat_map(
    _pipe,
    (_capture) => {
      return split2(_capture, "\\");
    }
  );
  let segments = _block;
  let _block$1;
  if (drive instanceof Some) {
    let drive$1 = drive[0];
    _block$1 = prepend(drive$1, segments);
  } else {
    _block$1 = segments;
  }
  let segments$1 = _block$1;
  if (segments$1.hasLength(1) && segments$1.head === "") {
    return toList([]);
  } else if (segments$1.atLeastLength(1) && segments$1.head === "") {
    let rest = segments$1.tail;
    return prepend("/", rest);
  } else {
    let rest = segments$1;
    return rest;
  }
}
function split4(path2) {
  let $ = is_windows();
  if ($) {
    return split_windows(path2);
  } else {
    return split_unix(path2);
  }
}
function base_name(path2) {
  return guard(
    path2 === "/",
    "",
    () => {
      let _pipe = path2;
      let _pipe$1 = split4(_pipe);
      let _pipe$2 = last(_pipe$1);
      return unwrap2(_pipe$2, "");
    }
  );
}

// build/dev/javascript/o11a_client/o11a/ui/audit_tree.mjs
function sub_file_tree_view(dir_name, current_file_path, all_audit_files) {
  let _block;
  let _pipe = map_get(all_audit_files, dir_name);
  _block = unwrap2(_pipe, [toList([]), toList([])]);
  let $ = _block;
  let subdirs = $[0];
  let direct_files = $[1];
  return div(
    toList([id(dir_name)]),
    toList([
      p(
        toList([class$("tree-item")]),
        toList([
          text3(
            (() => {
              let _pipe$1 = dir_name;
              return base_name(_pipe$1);
            })()
          )
        ])
      ),
      div(
        toList([
          id(dir_name + "-dirs"),
          class$("nested-tree-items")
        ]),
        map2(
          subdirs,
          (_capture) => {
            return sub_file_tree_view(
              _capture,
              current_file_path,
              all_audit_files
            );
          }
        )
      ),
      div(
        toList([
          id(dir_name + "-files"),
          class$("nested-tree-items")
        ]),
        map2(
          direct_files,
          (file) => {
            return a(
              toList([
                class$(
                  "tree-item tree-link" + (() => {
                    let $1 = file === current_file_path;
                    if ($1) {
                      return " underline";
                    } else {
                      return "";
                    }
                  })()
                ),
                href("/" + file),
                rel("prefetch")
              ]),
              toList([
                text3(
                  (() => {
                    let _pipe$1 = file;
                    return base_name(_pipe$1);
                  })()
                )
              ])
            );
          }
        )
      )
    ])
  );
}
function audit_file_tree_view(grouped_files, audit_name, current_file_path) {
  let _block;
  let _pipe = map_get(grouped_files, audit_name);
  _block = unwrap2(_pipe, [toList([]), toList([])]);
  let $ = _block;
  let subdirs = $[0];
  let direct_files = $[1];
  return div(
    toList([id("audit-files")]),
    toList([
      div(
        toList([id(audit_name + "-files")]),
        map2(
          direct_files,
          (file) => {
            return a(
              toList([
                class$(
                  "tree-item tree-link" + (() => {
                    let $1 = file === current_file_path;
                    if ($1) {
                      return " underline";
                    } else {
                      return "";
                    }
                  })()
                ),
                href("/" + file),
                rel("prefetch")
              ]),
              toList([
                text3(
                  (() => {
                    let _pipe$1 = file;
                    return base_name(_pipe$1);
                  })()
                )
              ])
            );
          }
        )
      ),
      div(
        toList([id(audit_name + "-dirs")]),
        map2(
          subdirs,
          (_capture) => {
            return sub_file_tree_view(
              _capture,
              current_file_path,
              grouped_files
            );
          }
        )
      )
    ])
  );
}
function view2(file_contents, side_panel, grouped_files, audit_name, current_file_path) {
  return div(
    toList([id("tree-grid")]),
    toList([
      div(
        toList([id("file-tree")]),
        toList([
          h3(
            toList([id("audit-tree-header")]),
            toList([text3(audit_name + " files")])
          ),
          audit_file_tree_view(grouped_files, audit_name, current_file_path)
        ])
      ),
      div(toList([id("tree-resizer")]), toList([])),
      div(
        toList([id("file-contents")]),
        toList([file_contents])
      ),
      (() => {
        let $ = is_some(side_panel);
        if ($) {
          return div(toList([id("panel-resizer")]), toList([]));
        } else {
          return fragment2(toList([]));
        }
      })(),
      (() => {
        if (side_panel instanceof Some) {
          let side_panel$1 = side_panel[0];
          return div(
            toList([id("side-panel")]),
            toList([side_panel$1])
          );
        } else {
          return fragment2(toList([]));
        }
      })()
    ])
  );
}
function get_all_parents(path2) {
  let _pipe = path2;
  let _pipe$1 = split2(_pipe, "/");
  let _pipe$2 = take(_pipe$1, length(split2(path2, "/")) - 1);
  let _pipe$3 = index_fold(
    _pipe$2,
    toList([]),
    (acc, segment, i) => {
      if (i === 0) {
        return prepend(segment, acc);
      } else {
        let _block;
        let _pipe$32 = first(acc);
        _block = unwrap2(_pipe$32, "");
        let prev = _block;
        return prepend(prev + "/" + segment, acc);
      }
    }
  );
  return reverse(_pipe$3);
}
function dashboard_path(audit_name) {
  return audit_name + "/dashboard";
}
function group_files_by_parent(in_scope_files, current_file_path, audit_name) {
  let dashboard_path$1 = dashboard_path(audit_name);
  let _block;
  let $ = current_file_path === dashboard_path$1;
  if ($) {
    _block = prepend(current_file_path, in_scope_files);
  } else {
    let $12 = contains(in_scope_files, current_file_path);
    if ($12) {
      _block = prepend(dashboard_path$1, in_scope_files);
    } else {
      _block = prepend(
        current_file_path,
        prepend(dashboard_path$1, in_scope_files)
      );
    }
  }
  let in_scope_files$1 = _block;
  let _block$1;
  let $1 = contains(in_scope_files$1, dashboard_path$1);
  if ($1) {
    _block$1 = in_scope_files$1;
  } else {
    _block$1 = prepend(dashboard_path$1, in_scope_files$1);
  }
  let in_scope_files$2 = _block$1;
  let _block$2;
  let _pipe = in_scope_files$2;
  let _pipe$1 = flat_map(_pipe, get_all_parents);
  _block$2 = unique(_pipe$1);
  let parents = _block$2;
  let _pipe$2 = parents;
  let _pipe$3 = map2(
    _pipe$2,
    (parent) => {
      let parent_prefix = parent + "/";
      let _block$3;
      let _pipe$32 = in_scope_files$2;
      _block$3 = filter(
        _pipe$32,
        (path2) => {
          return starts_with(path2, parent_prefix);
        }
      );
      let items = _block$3;
      let _block$4;
      let _pipe$4 = items;
      _block$4 = partition(
        _pipe$4,
        (path2) => {
          let relative = replace(path2, parent_prefix, "");
          return contains_string(relative, "/");
        }
      );
      let $2 = _block$4;
      let dirs = $2[0];
      let direct_files = $2[1];
      let _block$5;
      let _pipe$5 = dirs;
      let _pipe$6 = map2(
        _pipe$5,
        (dir) => {
          let relative = replace(dir, parent_prefix, "");
          let _block$6;
          let _pipe$62 = split2(relative, "/");
          let _pipe$7 = first(_pipe$62);
          _block$6 = unwrap2(_pipe$7, "");
          let first_dir = _block$6;
          return parent_prefix + first_dir;
        }
      );
      _block$5 = unique(_pipe$6);
      let subdirs = _block$5;
      return [parent, [subdirs, direct_files]];
    }
  );
  return from_list(_pipe$3);
}

// build/dev/javascript/o11a_client/o11a_client.mjs
var Model3 = class extends CustomType {
  constructor(route2, file_tree, audit_metadata, source_files, discussions, discussion_models, keyboard_model, selected_discussion, selected_node_id, focused_discussion, clicked_discussion) {
    super();
    this.route = route2;
    this.file_tree = file_tree;
    this.audit_metadata = audit_metadata;
    this.source_files = source_files;
    this.discussions = discussions;
    this.discussion_models = discussion_models;
    this.keyboard_model = keyboard_model;
    this.selected_discussion = selected_discussion;
    this.selected_node_id = selected_node_id;
    this.focused_discussion = focused_discussion;
    this.clicked_discussion = clicked_discussion;
  }
};
var O11aHomeRoute = class extends CustomType {
};
var AuditDashboardRoute = class extends CustomType {
  constructor(audit_name) {
    super();
    this.audit_name = audit_name;
  }
};
var AuditPageRoute = class extends CustomType {
  constructor(audit_name, page_path) {
    super();
    this.audit_name = audit_name;
    this.page_path = page_path;
  }
};
var OnRouteChange = class extends CustomType {
  constructor(route2) {
    super();
    this.route = route2;
  }
};
var ClientFetchedAuditMetadata = class extends CustomType {
  constructor(audit_name, metadata) {
    super();
    this.audit_name = audit_name;
    this.metadata = metadata;
  }
};
var ClientFetchedSourceFile = class extends CustomType {
  constructor(page_path, source_file) {
    super();
    this.page_path = page_path;
    this.source_file = source_file;
  }
};
var ClientFetchedDiscussion = class extends CustomType {
  constructor(audit_name, discussion) {
    super();
    this.audit_name = audit_name;
    this.discussion = discussion;
  }
};
var ServerUpdatedDiscussion = class extends CustomType {
  constructor(audit_name) {
    super();
    this.audit_name = audit_name;
  }
};
var UserEnteredKey = class extends CustomType {
  constructor(browser_event) {
    super();
    this.browser_event = browser_event;
  }
};
var UserSelectedDiscussionEntry2 = class extends CustomType {
  constructor(kind, line_number, column_number, node_id, topic_id, topic_title, is_reference) {
    super();
    this.kind = kind;
    this.line_number = line_number;
    this.column_number = column_number;
    this.node_id = node_id;
    this.topic_id = topic_id;
    this.topic_title = topic_title;
    this.is_reference = is_reference;
  }
};
var UserUnselectedDiscussionEntry2 = class extends CustomType {
  constructor(kind) {
    super();
    this.kind = kind;
  }
};
var UserClickedDiscussionEntry2 = class extends CustomType {
  constructor(line_number, column_number) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
  }
};
var UserClickedInsideDiscussion2 = class extends CustomType {
  constructor(line_number, column_number) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
  }
};
var UserClickedOutsideDiscussion = class extends CustomType {
};
var UserUpdatedDiscussion2 = class extends CustomType {
  constructor(line_number, column_number, update4) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
    this.update = update4;
  }
};
var UserSuccessfullySubmittedNote = class extends CustomType {
  constructor(updated_model) {
    super();
    this.updated_model = updated_model;
  }
};
var UserFailedToSubmitNote = class extends CustomType {
  constructor(error2) {
    super();
    this.error = error2;
  }
};
function parse_route(uri) {
  let $ = path_segments(uri.path);
  if ($.hasLength(0)) {
    return new O11aHomeRoute();
  } else if ($.hasLength(1) && $.head === "dashboard") {
    return new O11aHomeRoute();
  } else if ($.hasLength(1)) {
    let audit_name = $.head;
    return new AuditDashboardRoute(audit_name);
  } else if ($.hasLength(2) && $.tail.head === "dashboard") {
    let audit_name = $.head;
    return new AuditDashboardRoute(audit_name);
  } else {
    let audit_name = $.head;
    return new AuditPageRoute(
      audit_name,
      (() => {
        let _pipe = uri.path;
        return drop_start(_pipe, 1);
      })()
    );
  }
}
function on_url_change(uri) {
  echo3("on_url_change", "src/o11a_client.gleam", 108);
  echo3(uri, "src/o11a_client.gleam", 109);
  let _pipe = parse_route(uri);
  return new OnRouteChange(_pipe);
}
function file_tree_from_route(route2, audit_metadata) {
  if (route2 instanceof O11aHomeRoute) {
    return new_map();
  } else if (route2 instanceof AuditDashboardRoute) {
    let audit_name = route2.audit_name;
    let _block;
    let _pipe = map_get(audit_metadata, audit_name);
    let _pipe$1 = map3(
      _pipe,
      (audit_metadata2) => {
        if (audit_metadata2.isOk()) {
          let audit_metadata$1 = audit_metadata2[0];
          return audit_metadata$1.in_scope_files;
        } else {
          return toList([]);
        }
      }
    );
    _block = unwrap2(_pipe$1, toList([]));
    let in_scope_files = _block;
    return group_files_by_parent(
      in_scope_files,
      dashboard_path(audit_name),
      audit_name
    );
  } else {
    let audit_name = route2.audit_name;
    let current_file_path = route2.page_path;
    let _block;
    let _pipe = map_get(audit_metadata, audit_name);
    let _pipe$1 = map3(
      _pipe,
      (audit_metadata2) => {
        if (audit_metadata2.isOk()) {
          let audit_metadata$1 = audit_metadata2[0];
          return audit_metadata$1.in_scope_files;
        } else {
          return toList([]);
        }
      }
    );
    _block = unwrap2(_pipe$1, toList([]));
    let in_scope_files = _block;
    return group_files_by_parent(
      in_scope_files,
      current_file_path,
      audit_name
    );
  }
}
function fetch_metadata(model, audit_name) {
  let $ = map_get(model.audit_metadata, audit_name);
  if ($.isOk() && $[0].isOk()) {
    return none();
  } else {
    return get2(
      "/audit-metadata/" + audit_name,
      expect_json(
        audit_metadata_decoder(),
        (_capture) => {
          return new ClientFetchedAuditMetadata(audit_name, _capture);
        }
      )
    );
  }
}
function fetch_source_file(model, page_path) {
  let $ = map_get(model.source_files, page_path);
  if ($.isOk() && $[0].isOk()) {
    return none();
  } else {
    return get2(
      "/source-file/" + page_path,
      expect_json(
        list2(pre_processed_line_decoder()),
        (_capture) => {
          return new ClientFetchedSourceFile(page_path, _capture);
        }
      )
    );
  }
}
function fetch_discussion(audit_name) {
  return get2(
    "/audit-discussion/" + audit_name,
    expect_json(
      list2(computed_note_decoder()),
      (_capture) => {
        return new ClientFetchedDiscussion(audit_name, _capture);
      }
    )
  );
}
function route_change_effect(model, route2) {
  if (route2 instanceof AuditDashboardRoute) {
    let audit_name = route2.audit_name;
    return batch(
      toList([fetch_metadata(model, audit_name), fetch_discussion(audit_name)])
    );
  } else if (route2 instanceof AuditPageRoute) {
    let audit_name = route2.audit_name;
    let page_path = route2.page_path;
    return batch(
      toList([
        fetch_discussion(audit_name),
        fetch_metadata(model, audit_name),
        fetch_source_file(model, page_path)
      ])
    );
  } else {
    return none();
  }
}
function init4(_) {
  let _block;
  let $ = do_initial_uri();
  if ($.isOk()) {
    let uri = $[0];
    _block = parse_route(uri);
  } else {
    _block = new O11aHomeRoute();
  }
  let route2 = _block;
  let init_model = new Model3(
    route2,
    new_map(),
    new_map(),
    new_map(),
    new_map(),
    new_map(),
    init2(),
    new None(),
    new None(),
    new None(),
    new None()
  );
  return [
    init_model,
    batch(
      toList([
        init(on_url_change),
        from(
          (dispatch) => {
            return addEventListener3(
              "keydown",
              (event4) => {
                prevent_default(event4);
                return dispatch(new UserEnteredKey(event4));
              }
            );
          }
        ),
        route_change_effect(init_model, init_model.route)
      ])
    )
  ];
}
function submit_note(audit_name, topic_id, note_submission, discussion_model) {
  return post(
    "/submit-note/" + audit_name,
    object2(
      toList([
        ["topic_id", string4(topic_id)],
        ["note_submission", encode_note_submission(note_submission)]
      ])
    ),
    expect_json(
      field(
        "msg",
        string3,
        (msg) => {
          if (msg === "success") {
            return success(void 0);
          } else {
            return failure(void 0, msg);
          }
        }
      ),
      (response) => {
        if (response.isOk() && !response[0]) {
          return new UserSuccessfullySubmittedNote(discussion_model);
        } else {
          let e = response[0];
          return new UserFailedToSubmitNote(e);
        }
      }
    )
  );
}
function update3(model, msg) {
  if (msg instanceof OnRouteChange) {
    let route2 = msg.route;
    return [
      (() => {
        let _record = model;
        return new Model3(
          route2,
          file_tree_from_route(route2, model.audit_metadata),
          _record.audit_metadata,
          _record.source_files,
          _record.discussions,
          _record.discussion_models,
          _record.keyboard_model,
          _record.selected_discussion,
          _record.selected_node_id,
          _record.focused_discussion,
          _record.clicked_discussion
        );
      })(),
      route_change_effect(model, route2)
    ];
  } else if (msg instanceof ClientFetchedAuditMetadata) {
    let audit_name = msg.audit_name;
    let metadata = msg.metadata;
    let updated_audit_metadata = insert(
      model.audit_metadata,
      audit_name,
      metadata
    );
    return [
      (() => {
        let _record = model;
        return new Model3(
          _record.route,
          file_tree_from_route(model.route, updated_audit_metadata),
          updated_audit_metadata,
          _record.source_files,
          _record.discussions,
          _record.discussion_models,
          _record.keyboard_model,
          _record.selected_discussion,
          _record.selected_node_id,
          _record.focused_discussion,
          _record.clicked_discussion
        );
      })(),
      none()
    ];
  } else if (msg instanceof ClientFetchedSourceFile) {
    let page_path = msg.page_path;
    let source_files = msg.source_file;
    return [
      (() => {
        let _record = model;
        return new Model3(
          _record.route,
          _record.file_tree,
          _record.audit_metadata,
          insert(model.source_files, page_path, source_files),
          _record.discussions,
          _record.discussion_models,
          (() => {
            let _record$1 = model.keyboard_model;
            return new Model(
              _record$1.current_line_number,
              _record$1.current_column_number,
              _record$1.current_line_column_count,
              (() => {
                if (source_files.isOk()) {
                  let source_files$1 = source_files[0];
                  return length(source_files$1);
                } else {
                  return model.keyboard_model.line_count;
                }
              })()
            );
          })(),
          _record.selected_discussion,
          _record.selected_node_id,
          _record.focused_discussion,
          _record.clicked_discussion
        );
      })(),
      none()
    ];
  } else if (msg instanceof ClientFetchedDiscussion) {
    let audit_name = msg.audit_name;
    let discussion = msg.discussion;
    if (discussion.isOk()) {
      let discussion$1 = discussion[0];
      return [
        (() => {
          let _record = model;
          return new Model3(
            _record.route,
            _record.file_tree,
            _record.audit_metadata,
            _record.source_files,
            insert(
              model.discussions,
              audit_name,
              (() => {
                let _pipe = discussion$1;
                return group(_pipe, (note) => {
                  return note.parent_id;
                });
              })()
            ),
            _record.discussion_models,
            _record.keyboard_model,
            _record.selected_discussion,
            _record.selected_node_id,
            _record.focused_discussion,
            _record.clicked_discussion
          );
        })(),
        none()
      ];
    } else {
      let e = discussion[0];
      console_log("Failed to fetch discussion: " + inspect2(e));
      return [model, none()];
    }
  } else if (msg instanceof ServerUpdatedDiscussion) {
    let audit_name = msg.audit_name;
    return [model, fetch_discussion(audit_name)];
  } else if (msg instanceof UserEnteredKey) {
    let browser_event = msg.browser_event;
    let $ = do_page_navigation(
      browser_event,
      model.keyboard_model
    );
    let keyboard_model = $[0];
    let effect = $[1];
    return [
      (() => {
        let _record = model;
        return new Model3(
          _record.route,
          _record.file_tree,
          _record.audit_metadata,
          _record.source_files,
          _record.discussions,
          _record.discussion_models,
          keyboard_model,
          _record.selected_discussion,
          _record.selected_node_id,
          _record.focused_discussion,
          _record.clicked_discussion
        );
      })(),
      effect
    ];
  } else if (msg instanceof UserSelectedDiscussionEntry2) {
    let kind = msg.kind;
    let line_number = msg.line_number;
    let column_number = msg.column_number;
    let node_id = msg.node_id;
    let topic_id = msg.topic_id;
    let topic_title = msg.topic_title;
    let is_reference = msg.is_reference;
    let selected_discussion = [line_number, column_number];
    let _block;
    let $ = map_get(model.discussion_models, selected_discussion);
    if ($.isOk()) {
      _block = model.discussion_models;
    } else {
      _block = insert(
        model.discussion_models,
        selected_discussion,
        init3(
          line_number,
          column_number,
          topic_id,
          topic_title,
          is_reference
        )
      );
    }
    let discussion_models = _block;
    return [
      (() => {
        if (kind instanceof EntryHover) {
          let _record = model;
          return new Model3(
            _record.route,
            _record.file_tree,
            _record.audit_metadata,
            _record.source_files,
            _record.discussions,
            discussion_models,
            _record.keyboard_model,
            new Some(selected_discussion),
            node_id,
            _record.focused_discussion,
            _record.clicked_discussion
          );
        } else {
          let _record = model;
          return new Model3(
            _record.route,
            _record.file_tree,
            _record.audit_metadata,
            _record.source_files,
            _record.discussions,
            discussion_models,
            (() => {
              let _record$1 = model.keyboard_model;
              return new Model(
                line_number,
                column_number,
                _record$1.current_line_column_count,
                _record$1.line_count
              );
            })(),
            _record.selected_discussion,
            node_id,
            new Some(selected_discussion),
            _record.clicked_discussion
          );
        }
      })(),
      none()
    ];
  } else if (msg instanceof UserUnselectedDiscussionEntry2) {
    let kind = msg.kind;
    echo3(
      "Unselecting discussion " + inspect2(kind),
      "src/o11a_client.gleam",
      347
    );
    return [
      (() => {
        if (kind instanceof EntryHover) {
          let _record = model;
          return new Model3(
            _record.route,
            _record.file_tree,
            _record.audit_metadata,
            _record.source_files,
            _record.discussions,
            _record.discussion_models,
            _record.keyboard_model,
            new None(),
            new None(),
            _record.focused_discussion,
            _record.clicked_discussion
          );
        } else {
          let _record = model;
          return new Model3(
            _record.route,
            _record.file_tree,
            _record.audit_metadata,
            _record.source_files,
            _record.discussions,
            _record.discussion_models,
            _record.keyboard_model,
            _record.selected_discussion,
            new None(),
            new None(),
            _record.clicked_discussion
          );
        }
      })(),
      none()
    ];
  } else if (msg instanceof UserClickedDiscussionEntry2) {
    let line_number = msg.line_number;
    let column_number = msg.column_number;
    return [
      (() => {
        let _record = model;
        return new Model3(
          _record.route,
          _record.file_tree,
          _record.audit_metadata,
          _record.source_files,
          _record.discussions,
          _record.discussion_models,
          _record.keyboard_model,
          _record.selected_discussion,
          _record.selected_node_id,
          _record.focused_discussion,
          new Some([line_number, column_number])
        );
      })(),
      from(
        (_) => {
          let _block;
          let _pipe = discussion_input(line_number, column_number);
          _block = map3(_pipe, focus);
          let res = _block;
          if (res.isOk() && !res[0]) {
            return void 0;
          } else {
            return console_log("Failed to focus discussion input");
          }
        }
      )
    ];
  } else if (msg instanceof UserClickedInsideDiscussion2) {
    let line_number = msg.line_number;
    let column_number = msg.column_number;
    echo3("User clicked inside discussion", "src/o11a_client.gleam", 387);
    let _block;
    let $ = !isEqual(
      model.selected_discussion,
      new Some([line_number, column_number])
    );
    if ($) {
      let _record = model;
      _block = new Model3(
        _record.route,
        _record.file_tree,
        _record.audit_metadata,
        _record.source_files,
        _record.discussions,
        _record.discussion_models,
        _record.keyboard_model,
        new None(),
        _record.selected_node_id,
        _record.focused_discussion,
        _record.clicked_discussion
      );
    } else {
      _block = model;
    }
    let model$1 = _block;
    let _block$1;
    let $1 = !isEqual(
      model$1.focused_discussion,
      new Some([line_number, column_number])
    );
    if ($1) {
      let _record = model$1;
      _block$1 = new Model3(
        _record.route,
        _record.file_tree,
        _record.audit_metadata,
        _record.source_files,
        _record.discussions,
        _record.discussion_models,
        _record.keyboard_model,
        _record.selected_discussion,
        _record.selected_node_id,
        new None(),
        _record.clicked_discussion
      );
    } else {
      _block$1 = model$1;
    }
    let model$2 = _block$1;
    let _block$2;
    let $2 = !isEqual(
      model$2.clicked_discussion,
      new Some([line_number, column_number])
    );
    if ($2) {
      let _record = model$2;
      _block$2 = new Model3(
        _record.route,
        _record.file_tree,
        _record.audit_metadata,
        _record.source_files,
        _record.discussions,
        _record.discussion_models,
        _record.keyboard_model,
        _record.selected_discussion,
        _record.selected_node_id,
        _record.focused_discussion,
        new None()
      );
    } else {
      _block$2 = model$2;
    }
    let model$3 = _block$2;
    return [model$3, none()];
  } else if (msg instanceof UserClickedOutsideDiscussion) {
    echo3("User clicked outside discussion", "src/o11a_client.gleam", 413);
    return [
      (() => {
        let _record = model;
        return new Model3(
          _record.route,
          _record.file_tree,
          _record.audit_metadata,
          _record.source_files,
          _record.discussions,
          _record.discussion_models,
          _record.keyboard_model,
          new None(),
          _record.selected_node_id,
          new None(),
          new None()
        );
      })(),
      none()
    ];
  } else if (msg instanceof UserUpdatedDiscussion2) {
    let line_number = msg.line_number;
    let column_number = msg.column_number;
    let update$1 = msg.update;
    let discussion_model = update$1[0];
    let discussion_effect = update$1[1];
    if (discussion_effect instanceof SubmitNote) {
      let note_submission = discussion_effect.note;
      let topic_id = discussion_effect.topic_id;
      return [
        model,
        (() => {
          let $ = model.route;
          if ($ instanceof AuditPageRoute) {
            let audit_name = $.audit_name;
            return submit_note(
              audit_name,
              topic_id,
              note_submission,
              discussion_model
            );
          } else if ($ instanceof AuditDashboardRoute) {
            let audit_name = $.audit_name;
            return submit_note(
              audit_name,
              topic_id,
              note_submission,
              discussion_model
            );
          } else {
            return none();
          }
        })()
      ];
    } else if (discussion_effect instanceof FocusDiscussionInput) {
      let line_number$1 = discussion_effect.line_number;
      let column_number$1 = discussion_effect.column_number;
      echo3(
        "Focusing discussion input, user is typing",
        "src/o11a_client.gleam",
        445
      );
      set_is_user_typing(true);
      return [
        (() => {
          let _record = model;
          return new Model3(
            _record.route,
            _record.file_tree,
            _record.audit_metadata,
            _record.source_files,
            _record.discussions,
            _record.discussion_models,
            _record.keyboard_model,
            _record.selected_discussion,
            _record.selected_node_id,
            new Some([line_number$1, column_number$1]),
            _record.clicked_discussion
          );
        })(),
        none()
      ];
    } else if (discussion_effect instanceof FocusExpandedDiscussionInput) {
      let line_number$1 = discussion_effect.line_number;
      let column_number$1 = discussion_effect.column_number;
      set_is_user_typing(true);
      return [
        (() => {
          let _record = model;
          return new Model3(
            _record.route,
            _record.file_tree,
            _record.audit_metadata,
            _record.source_files,
            _record.discussions,
            _record.discussion_models,
            _record.keyboard_model,
            _record.selected_discussion,
            _record.selected_node_id,
            new Some([line_number$1, column_number$1]),
            _record.clicked_discussion
          );
        })(),
        none()
      ];
    } else if (discussion_effect instanceof UnfocusDiscussionInput) {
      echo3("Unfocusing discussion input", "src/o11a_client.gleam", 468);
      set_is_user_typing(false);
      return [model, none()];
    } else if (discussion_effect instanceof MaximizeDiscussion) {
      return [
        (() => {
          let _record = model;
          return new Model3(
            _record.route,
            _record.file_tree,
            _record.audit_metadata,
            _record.source_files,
            _record.discussions,
            insert(
              model.discussion_models,
              [line_number, column_number],
              discussion_model
            ),
            _record.keyboard_model,
            _record.selected_discussion,
            _record.selected_node_id,
            _record.focused_discussion,
            _record.clicked_discussion
          );
        })(),
        none()
      ];
    } else {
      return [
        (() => {
          let _record = model;
          return new Model3(
            _record.route,
            _record.file_tree,
            _record.audit_metadata,
            _record.source_files,
            _record.discussions,
            insert(
              model.discussion_models,
              [line_number, column_number],
              discussion_model
            ),
            _record.keyboard_model,
            _record.selected_discussion,
            _record.selected_node_id,
            _record.focused_discussion,
            _record.clicked_discussion
          );
        })(),
        none()
      ];
    }
  } else if (msg instanceof UserSuccessfullySubmittedNote) {
    let updated_model = msg.updated_model;
    return [
      (() => {
        let _record = model;
        return new Model3(
          _record.route,
          _record.file_tree,
          _record.audit_metadata,
          _record.source_files,
          _record.discussions,
          insert(
            model.discussion_models,
            [updated_model.line_number, updated_model.column_number],
            updated_model
          ),
          _record.keyboard_model,
          _record.selected_discussion,
          _record.selected_node_id,
          _record.focused_discussion,
          _record.clicked_discussion
        );
      })(),
      none()
    ];
  } else {
    let error2 = msg.error;
    print("Failed to submit note: " + inspect2(error2));
    return [model, none()];
  }
}
function get_selected_discussion(model) {
  let $ = model.focused_discussion;
  let $1 = model.clicked_discussion;
  let $2 = model.selected_discussion;
  if ($ instanceof Some) {
    let discussion = $[0];
    let _pipe = map_get(model.discussion_models, discussion);
    let _pipe$1 = map3(
      _pipe,
      (model2) => {
        return new Some(
          new DiscussionReference(
            discussion[0],
            discussion[1],
            model2
          )
        );
      }
    );
    return unwrap2(_pipe$1, new None());
  } else if ($1 instanceof Some) {
    let discussion = $1[0];
    let _pipe = map_get(model.discussion_models, discussion);
    let _pipe$1 = map3(
      _pipe,
      (model2) => {
        return new Some(
          new DiscussionReference(
            discussion[0],
            discussion[1],
            model2
          )
        );
      }
    );
    return unwrap2(_pipe$1, new None());
  } else if ($2 instanceof Some) {
    let discussion = $2[0];
    let _pipe = map_get(model.discussion_models, discussion);
    let _pipe$1 = map3(
      _pipe,
      (model2) => {
        return new Some(
          new DiscussionReference(
            discussion[0],
            discussion[1],
            model2
          )
        );
      }
    );
    return unwrap2(_pipe$1, new None());
  } else {
    return new None();
  }
}
function on_server_updated_discussion(msg) {
  return on(
    server_updated_discussion,
    subfield(
      toList(["detail", "audit_name"]),
      string3,
      (audit_name) => {
        return success(msg(audit_name));
      }
    )
  );
}
function map_audit_page_msg(msg) {
  if (msg instanceof UserSelectedDiscussionEntry) {
    let kind = msg.kind;
    let line_number = msg.line_number;
    let column_number = msg.column_number;
    let node_id = msg.node_id;
    let topic_id = msg.topic_id;
    let topic_title = msg.topic_title;
    let is_reference = msg.is_reference;
    return new UserSelectedDiscussionEntry2(
      kind,
      line_number,
      column_number,
      node_id,
      topic_id,
      topic_title,
      is_reference
    );
  } else if (msg instanceof UserUnselectedDiscussionEntry) {
    let kind = msg.kind;
    return new UserUnselectedDiscussionEntry2(kind);
  } else if (msg instanceof UserClickedDiscussionEntry) {
    let line_number = msg.line_number;
    let column_number = msg.column_number;
    return new UserClickedDiscussionEntry2(line_number, column_number);
  } else if (msg instanceof UserUpdatedDiscussion) {
    let line_number = msg.line_number;
    let column_number = msg.column_number;
    let update$1 = msg.update;
    return new UserUpdatedDiscussion2(line_number, column_number, update$1);
  } else {
    let line_number = msg.line_number;
    let column_number = msg.column_number;
    return new UserClickedInsideDiscussion2(line_number, column_number);
  }
}
function map_discussion_msg2(msg, selected_discussion) {
  return new UserUpdatedDiscussion2(
    selected_discussion.line_number,
    selected_discussion.column_number,
    update2(selected_discussion.model, msg)
  );
}
function view3(model) {
  let $ = model.route;
  if ($ instanceof AuditDashboardRoute) {
    let audit_name = $.audit_name;
    return div(
      toList([]),
      toList([
        element3(
          toList([
            route("/component-discussion/" + audit_name)
          ]),
          toList([])
        ),
        view2(
          p(toList([]), toList([text3("Dashboard")])),
          new None(),
          model.file_tree,
          audit_name,
          dashboard_path(audit_name)
        )
      ])
    );
  } else if ($ instanceof AuditPageRoute) {
    let audit_name = $.audit_name;
    let page_path = $.page_path;
    let selected_discussion = get_selected_discussion(model);
    let _block;
    let _pipe = map_get(model.discussions, audit_name);
    _block = unwrap2(_pipe, new_map());
    let discussion = _block;
    let _block$1;
    let _pipe$1 = map_get(model.source_files, page_path);
    let _pipe$2 = map3(
      _pipe$1,
      (source_files) => {
        if (source_files.isOk()) {
          let source_files$1 = source_files[0];
          return source_files$1;
        } else {
          return toList([]);
        }
      }
    );
    _block$1 = unwrap2(_pipe$2, toList([]));
    let preprocessed_source = _block$1;
    return div(
      toList([on_click(new UserClickedOutsideDiscussion())]),
      toList([
        (() => {
          let $1 = model.selected_node_id;
          if ($1 instanceof Some) {
            let selected_node_id = $1[0];
            return style2(
              toList([]),
              ".N" + to_string(selected_node_id) + " { background-color: var(--highlight-color); border-radius: 0.15rem; }"
            );
          } else {
            return fragment2(toList([]));
          }
        })(),
        element3(
          toList([
            route("/component-discussion/" + audit_name),
            on_server_updated_discussion(
              (var0) => {
                return new ServerUpdatedDiscussion(var0);
              }
            )
          ]),
          toList([])
        ),
        view2(
          (() => {
            let _pipe$3 = view(
              preprocessed_source,
              discussion,
              selected_discussion
            );
            return map5(_pipe$3, map_audit_page_msg);
          })(),
          map(
            selected_discussion,
            (selected_discussion2) => {
              let _pipe$3 = panel_view(
                selected_discussion2.model,
                discussion
              );
              return map5(
                _pipe$3,
                (_capture) => {
                  return map_discussion_msg2(_capture, selected_discussion2);
                }
              );
            }
          ),
          model.file_tree,
          audit_name,
          page_path
        )
      ])
    );
  } else {
    return p(toList([]), toList([text3("Home")]));
  }
}
function main() {
  console_log("Starting client controller");
  let _pipe = application(init4, update3, view3);
  return start3(_pipe, "#app", void 0);
}
function echo3(value3, file, line2) {
  const grey = "\x1B[90m";
  const reset_color = "\x1B[39m";
  const file_line = `${file}:${line2}`;
  const string_value = echo$inspect3(value3);
  if (globalThis.process?.stderr?.write) {
    const string6 = `${grey}${file_line}${reset_color}
${string_value}
`;
    process.stderr.write(string6);
  } else if (globalThis.Deno) {
    const string6 = `${grey}${file_line}${reset_color}
${string_value}
`;
    globalThis.Deno.stderr.writeSync(new TextEncoder().encode(string6));
  } else {
    const string6 = `${file_line}
${string_value}`;
    globalThis.console.log(string6);
  }
  return value3;
}
function echo$inspectString3(str) {
  let new_str = '"';
  for (let i = 0; i < str.length; i++) {
    let char = str[i];
    if (char == "\n") new_str += "\\n";
    else if (char == "\r") new_str += "\\r";
    else if (char == "	") new_str += "\\t";
    else if (char == "\f") new_str += "\\f";
    else if (char == "\\") new_str += "\\\\";
    else if (char == '"') new_str += '\\"';
    else if (char < " " || char > "~" && char < "\xA0") {
      new_str += "\\u{" + char.charCodeAt(0).toString(16).toUpperCase().padStart(4, "0") + "}";
    } else {
      new_str += char;
    }
  }
  new_str += '"';
  return new_str;
}
function echo$inspectDict3(map7) {
  let body2 = "dict.from_list([";
  let first2 = true;
  let key_value_pairs = [];
  map7.forEach((value3, key2) => {
    key_value_pairs.push([key2, value3]);
  });
  key_value_pairs.sort();
  key_value_pairs.forEach(([key2, value3]) => {
    if (!first2) body2 = body2 + ", ";
    body2 = body2 + "#(" + echo$inspect3(key2) + ", " + echo$inspect3(value3) + ")";
    first2 = false;
  });
  return body2 + "])";
}
function echo$inspectCustomType3(record) {
  const props = globalThis.Object.keys(record).map((label) => {
    const value3 = echo$inspect3(record[label]);
    return isNaN(parseInt(label)) ? `${label}: ${value3}` : value3;
  }).join(", ");
  return props ? `${record.constructor.name}(${props})` : record.constructor.name;
}
function echo$inspectObject3(v) {
  const name = Object.getPrototypeOf(v)?.constructor?.name || "Object";
  const props = [];
  for (const k of Object.keys(v)) {
    props.push(`${echo$inspect3(k)}: ${echo$inspect3(v[k])}`);
  }
  const body2 = props.length ? " " + props.join(", ") + " " : "";
  const head = name === "Object" ? "" : name + " ";
  return `//js(${head}{${body2}})`;
}
function echo$inspect3(v) {
  const t = typeof v;
  if (v === true) return "True";
  if (v === false) return "False";
  if (v === null) return "//js(null)";
  if (v === void 0) return "Nil";
  if (t === "string") return echo$inspectString3(v);
  if (t === "bigint" || t === "number") return v.toString();
  if (globalThis.Array.isArray(v))
    return `#(${v.map(echo$inspect3).join(", ")})`;
  if (v instanceof List)
    return `[${v.toArray().map(echo$inspect3).join(", ")}]`;
  if (v instanceof UtfCodepoint)
    return `//utfcodepoint(${String.fromCodePoint(v.value)})`;
  if (v instanceof BitArray) return echo$inspectBitArray3(v);
  if (v instanceof CustomType) return echo$inspectCustomType3(v);
  if (echo$isDict3(v)) return echo$inspectDict3(v);
  if (v instanceof Set)
    return `//js(Set(${[...v].map(echo$inspect3).join(", ")}))`;
  if (v instanceof RegExp) return `//js(${v})`;
  if (v instanceof Date) return `//js(Date("${v.toISOString()}"))`;
  if (v instanceof Function) {
    const args = [];
    for (const i of Array(v.length).keys())
      args.push(String.fromCharCode(i + 97));
    return `//fn(${args.join(", ")}) { ... }`;
  }
  return echo$inspectObject3(v);
}
function echo$inspectBitArray3(bitArray) {
  let endOfAlignedBytes = bitArray.bitOffset + 8 * Math.trunc(bitArray.bitSize / 8);
  let alignedBytes = bitArraySlice(
    bitArray,
    bitArray.bitOffset,
    endOfAlignedBytes
  );
  let remainingUnalignedBits = bitArray.bitSize % 8;
  if (remainingUnalignedBits > 0) {
    let remainingBits = bitArraySliceToInt(
      bitArray,
      endOfAlignedBytes,
      bitArray.bitSize,
      false,
      false
    );
    let alignedBytesArray = Array.from(alignedBytes.rawBuffer);
    let suffix = `${remainingBits}:size(${remainingUnalignedBits})`;
    if (alignedBytesArray.length === 0) {
      return `<<${suffix}>>`;
    } else {
      return `<<${Array.from(alignedBytes.rawBuffer).join(", ")}, ${suffix}>>`;
    }
  } else {
    return `<<${Array.from(alignedBytes.rawBuffer).join(", ")}>>`;
  }
}
function echo$isDict3(value3) {
  try {
    return value3 instanceof Dict;
  } catch {
    return false;
  }
}

// build/.lustre/entry.mjs
main();
