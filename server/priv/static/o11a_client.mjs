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
    while (desired-- > 0 && current)
      current = current.tail;
    return current !== void 0;
  }
  // @internal
  hasLength(desired) {
    let current = this;
    while (desired-- > 0 && current)
      current = current.tail;
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
function prepend(element2, tail) {
  return new NonEmpty(element2, tail);
}
function toList(elements2, tail) {
  return List.fromArray(elements2, tail);
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
  constructor(value4) {
    this.value = value4;
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
function bitArraySlice(bitArray, start3, end) {
  end ??= bitArray.bitSize;
  bitArrayValidateRange(bitArray, start3, end);
  if (start3 === end) {
    return new BitArray(new Uint8Array());
  }
  if (start3 === 0 && end === bitArray.bitSize) {
    return bitArray;
  }
  start3 += bitArray.bitOffset;
  end += bitArray.bitOffset;
  const startByteIndex = Math.trunc(start3 / 8);
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
  return new BitArray(buffer, end - start3, start3 % 8);
}
function bitArraySliceToInt(bitArray, start3, end, isBigEndian, isSigned) {
  bitArrayValidateRange(bitArray, start3, end);
  if (start3 === end) {
    return 0;
  }
  start3 += bitArray.bitOffset;
  end += bitArray.bitOffset;
  const isStartByteAligned = start3 % 8 === 0;
  const isEndByteAligned = end % 8 === 0;
  if (isStartByteAligned && isEndByteAligned) {
    return intFromAlignedSlice(
      bitArray,
      start3 / 8,
      end / 8,
      isBigEndian,
      isSigned
    );
  }
  const size = end - start3;
  const startByteIndex = Math.trunc(start3 / 8);
  const endByteIndex = Math.trunc((end - 1) / 8);
  if (startByteIndex == endByteIndex) {
    const mask2 = 255 >> start3 % 8;
    const unusedLowBitCount = (8 - end % 8) % 8;
    let value4 = (bitArray.rawBuffer[startByteIndex] & mask2) >> unusedLowBitCount;
    if (isSigned) {
      const highBit = 2 ** (size - 1);
      if (value4 >= highBit) {
        value4 -= highBit * 2;
      }
    }
    return value4;
  }
  if (size <= 53) {
    return intFromUnalignedSliceUsingNumber(
      bitArray.rawBuffer,
      start3,
      end,
      isBigEndian,
      isSigned
    );
  } else {
    return intFromUnalignedSliceUsingBigInt(
      bitArray.rawBuffer,
      start3,
      end,
      isBigEndian,
      isSigned
    );
  }
}
function intFromAlignedSlice(bitArray, start3, end, isBigEndian, isSigned) {
  const byteSize = end - start3;
  if (byteSize <= 6) {
    return intFromAlignedSliceUsingNumber(
      bitArray.rawBuffer,
      start3,
      end,
      isBigEndian,
      isSigned
    );
  } else {
    return intFromAlignedSliceUsingBigInt(
      bitArray.rawBuffer,
      start3,
      end,
      isBigEndian,
      isSigned
    );
  }
}
function intFromAlignedSliceUsingNumber(buffer, start3, end, isBigEndian, isSigned) {
  const byteSize = end - start3;
  let value4 = 0;
  if (isBigEndian) {
    for (let i = start3; i < end; i++) {
      value4 *= 256;
      value4 += buffer[i];
    }
  } else {
    for (let i = end - 1; i >= start3; i--) {
      value4 *= 256;
      value4 += buffer[i];
    }
  }
  if (isSigned) {
    const highBit = 2 ** (byteSize * 8 - 1);
    if (value4 >= highBit) {
      value4 -= highBit * 2;
    }
  }
  return value4;
}
function intFromAlignedSliceUsingBigInt(buffer, start3, end, isBigEndian, isSigned) {
  const byteSize = end - start3;
  let value4 = 0n;
  if (isBigEndian) {
    for (let i = start3; i < end; i++) {
      value4 *= 256n;
      value4 += BigInt(buffer[i]);
    }
  } else {
    for (let i = end - 1; i >= start3; i--) {
      value4 *= 256n;
      value4 += BigInt(buffer[i]);
    }
  }
  if (isSigned) {
    const highBit = 1n << BigInt(byteSize * 8 - 1);
    if (value4 >= highBit) {
      value4 -= highBit * 2n;
    }
  }
  return Number(value4);
}
function intFromUnalignedSliceUsingNumber(buffer, start3, end, isBigEndian, isSigned) {
  const isStartByteAligned = start3 % 8 === 0;
  let size = end - start3;
  let byteIndex = Math.trunc(start3 / 8);
  let value4 = 0;
  if (isBigEndian) {
    if (!isStartByteAligned) {
      const leadingBitsCount = 8 - start3 % 8;
      value4 = buffer[byteIndex++] & (1 << leadingBitsCount) - 1;
      size -= leadingBitsCount;
    }
    while (size >= 8) {
      value4 *= 256;
      value4 += buffer[byteIndex++];
      size -= 8;
    }
    if (size > 0) {
      value4 *= 2 ** size;
      value4 += buffer[byteIndex] >> 8 - size;
    }
  } else {
    if (isStartByteAligned) {
      let size2 = end - start3;
      let scale = 1;
      while (size2 >= 8) {
        value4 += buffer[byteIndex++] * scale;
        scale *= 256;
        size2 -= 8;
      }
      value4 += (buffer[byteIndex] >> 8 - size2) * scale;
    } else {
      const highBitsCount = start3 % 8;
      const lowBitsCount = 8 - highBitsCount;
      let size2 = end - start3;
      let scale = 1;
      while (size2 >= 8) {
        const byte = buffer[byteIndex] << highBitsCount | buffer[byteIndex + 1] >> lowBitsCount;
        value4 += (byte & 255) * scale;
        scale *= 256;
        size2 -= 8;
        byteIndex++;
      }
      if (size2 > 0) {
        const lowBitsUsed = size2 - Math.max(0, size2 - lowBitsCount);
        let trailingByte = (buffer[byteIndex] & (1 << lowBitsCount) - 1) >> lowBitsCount - lowBitsUsed;
        size2 -= lowBitsUsed;
        if (size2 > 0) {
          trailingByte *= 2 ** size2;
          trailingByte += buffer[byteIndex + 1] >> 8 - size2;
        }
        value4 += trailingByte * scale;
      }
    }
  }
  if (isSigned) {
    const highBit = 2 ** (end - start3 - 1);
    if (value4 >= highBit) {
      value4 -= highBit * 2;
    }
  }
  return value4;
}
function intFromUnalignedSliceUsingBigInt(buffer, start3, end, isBigEndian, isSigned) {
  const isStartByteAligned = start3 % 8 === 0;
  let size = end - start3;
  let byteIndex = Math.trunc(start3 / 8);
  let value4 = 0n;
  if (isBigEndian) {
    if (!isStartByteAligned) {
      const leadingBitsCount = 8 - start3 % 8;
      value4 = BigInt(buffer[byteIndex++] & (1 << leadingBitsCount) - 1);
      size -= leadingBitsCount;
    }
    while (size >= 8) {
      value4 *= 256n;
      value4 += BigInt(buffer[byteIndex++]);
      size -= 8;
    }
    if (size > 0) {
      value4 <<= BigInt(size);
      value4 += BigInt(buffer[byteIndex] >> 8 - size);
    }
  } else {
    if (isStartByteAligned) {
      let size2 = end - start3;
      let shift = 0n;
      while (size2 >= 8) {
        value4 += BigInt(buffer[byteIndex++]) << shift;
        shift += 8n;
        size2 -= 8;
      }
      value4 += BigInt(buffer[byteIndex] >> 8 - size2) << shift;
    } else {
      const highBitsCount = start3 % 8;
      const lowBitsCount = 8 - highBitsCount;
      let size2 = end - start3;
      let shift = 0n;
      while (size2 >= 8) {
        const byte = buffer[byteIndex] << highBitsCount | buffer[byteIndex + 1] >> lowBitsCount;
        value4 += BigInt(byte & 255) << shift;
        shift += 8n;
        size2 -= 8;
        byteIndex++;
      }
      if (size2 > 0) {
        const lowBitsUsed = size2 - Math.max(0, size2 - lowBitsCount);
        let trailingByte = (buffer[byteIndex] & (1 << lowBitsCount) - 1) >> lowBitsCount - lowBitsUsed;
        size2 -= lowBitsUsed;
        if (size2 > 0) {
          trailingByte <<= size2;
          trailingByte += buffer[byteIndex + 1] >> 8 - size2;
        }
        value4 += BigInt(trailingByte) << shift;
      }
    }
  }
  if (isSigned) {
    const highBit = 2n ** BigInt(end - start3 - 1);
    if (value4 >= highBit) {
      value4 -= highBit * 2n;
    }
  }
  return Number(value4);
}
function bitArrayValidateRange(bitArray, start3, end) {
  if (start3 < 0 || start3 > bitArray.bitSize || end < start3 || end > bitArray.bitSize) {
    const msg = `Invalid bit array slice: start = ${start3}, end = ${end}, bit size = ${bitArray.bitSize}`;
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
  constructor(value4) {
    super();
    this[0] = value4;
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
  let values2 = [x2, y];
  while (values2.length) {
    let a2 = values2.pop();
    let b = values2.pop();
    if (a2 === b)
      continue;
    if (!isObject(a2) || !isObject(b))
      return false;
    let unequal = !structurallyCompatibleObjects(a2, b) || unequalDates(a2, b) || unequalBuffers(a2, b) || unequalArrays(a2, b) || unequalMaps(a2, b) || unequalSets(a2, b) || unequalRegExps(a2, b);
    if (unequal)
      return false;
    const proto = Object.getPrototypeOf(a2);
    if (proto !== null && typeof proto.equals === "function") {
      try {
        if (a2.equals(b))
          continue;
        else
          return false;
      } catch {
      }
    }
    let [keys2, get2] = getters(a2);
    for (let k of keys2(a2)) {
      values2.push(get2(a2, k), get2(b, k));
    }
  }
  return true;
}
function getters(object3) {
  if (object3 instanceof Map) {
    return [(x2) => x2.keys(), (x2, y) => x2.get(y)];
  } else {
    let extra = object3 instanceof globalThis.Error ? ["message"] : [];
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
  if (nonstructural.some((c) => a2 instanceof c))
    return false;
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
  for (let k in extra)
    error2[k] = extra[k];
  return error2;
}

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
function insert(dict2, key2, value4) {
  return map_insert(key2, value4, dict2);
}
function from_list_loop(loop$list, loop$initial) {
  while (true) {
    let list4 = loop$list;
    let initial = loop$initial;
    if (list4.hasLength(0)) {
      return initial;
    } else {
      let key2 = list4.head[0];
      let value4 = list4.head[1];
      let rest = list4.tail;
      loop$list = rest;
      loop$initial = insert(initial, key2, value4);
    }
  }
}
function from_list(list4) {
  return from_list_loop(list4, new_map());
}
function reverse_and_concat(loop$remaining, loop$accumulator) {
  while (true) {
    let remaining = loop$remaining;
    let accumulator = loop$accumulator;
    if (remaining.hasLength(0)) {
      return accumulator;
    } else {
      let first3 = remaining.head;
      let rest = remaining.tail;
      loop$remaining = rest;
      loop$accumulator = prepend(first3, accumulator);
    }
  }
}
function do_keys_loop(loop$list, loop$acc) {
  while (true) {
    let list4 = loop$list;
    let acc = loop$acc;
    if (list4.hasLength(0)) {
      return reverse_and_concat(acc, toList([]));
    } else {
      let key2 = list4.head[0];
      let rest = list4.tail;
      loop$list = rest;
      loop$acc = prepend(key2, acc);
    }
  }
}
function keys(dict2) {
  return do_keys_loop(map_to_list(dict2), toList([]));
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
      let new_acc = (() => {
        let $ = fun(first$1);
        if ($) {
          return prepend(first$1, acc);
        } else {
          return acc;
        }
      })();
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
      let new_acc = (() => {
        let $ = fun(first$1);
        if ($.isOk()) {
          let first$2 = $[0];
          return prepend(first$2, acc);
        } else {
          return acc;
        }
      })();
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
    let first3 = loop$first;
    let second2 = loop$second;
    if (first3.hasLength(0)) {
      return second2;
    } else {
      let first$1 = first3.head;
      let rest$1 = first3.tail;
      loop$first = rest$1;
      loop$second = prepend(first$1, second2);
    }
  }
}
function append(first3, second2) {
  return append_loop(reverse(first3), second2);
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
    let value4 = loop$value;
    let inspected = loop$inspected;
    if (list4.atLeastLength(1) && isEqual(list4.head[0], key2)) {
      let k = list4.head[0];
      let rest$1 = list4.tail;
      return reverse_and_prepend(inspected, prepend([k, value4], rest$1));
    } else if (list4.atLeastLength(1)) {
      let first$1 = list4.head;
      let rest$1 = list4.tail;
      loop$list = rest$1;
      loop$key = key2;
      loop$value = value4;
      loop$inspected = prepend(first$1, inspected);
    } else {
      return reverse(prepend([key2, value4], inspected));
    }
  }
}
function key_set(list4, key2, value4) {
  return key_set_loop(list4, key2, value4, toList([]));
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
    let value4 = result[0];
    return new Ok(value4);
  } else {
    let error2 = result[0];
    return fun(error2);
  }
}

// build/dev/javascript/gleam_stdlib/gleam/string_tree.mjs
function append2(tree, second2) {
  return add(tree, identity(second2));
}
function reverse2(tree) {
  let _pipe = tree;
  let _pipe$1 = identity(_pipe);
  let _pipe$2 = graphemes(_pipe$1);
  let _pipe$3 = reverse(_pipe$2);
  return concat(_pipe$3);
}

// build/dev/javascript/gleam_stdlib/gleam/dynamic.mjs
var DecodeError = class extends CustomType {
  constructor(expected, found, path2) {
    super();
    this.expected = expected;
    this.found = found;
    this.path = path2;
  }
};
function map_errors(result, f) {
  return map_error(
    result,
    (_capture) => {
      return map2(_capture, f);
    }
  );
}
function string2(data2) {
  return decode_string(data2);
}
function do_any(decoders) {
  return (data2) => {
    if (decoders.hasLength(0)) {
      return new Error(
        toList([new DecodeError("another type", classify_dynamic(data2), toList([]))])
      );
    } else {
      let decoder = decoders.head;
      let decoders$1 = decoders.tail;
      let $ = decoder(data2);
      if ($.isOk()) {
        let decoded = $[0];
        return new Ok(decoded);
      } else {
        return do_any(decoders$1)(data2);
      }
    }
  };
}
function push_path(error2, name) {
  let name$1 = identity(name);
  let decoder = do_any(
    toList([
      decode_string,
      (x2) => {
        return map3(decode_int(x2), to_string);
      }
    ])
  );
  let name$2 = (() => {
    let $ = decoder(name$1);
    if ($.isOk()) {
      let name$22 = $[0];
      return name$22;
    } else {
      let _pipe = toList(["<", classify_dynamic(name$1), ">"]);
      let _pipe$1 = concat(_pipe);
      return identity(_pipe$1);
    }
  })();
  let _record = error2;
  return new DecodeError(
    _record.expected,
    _record.found,
    prepend(name$2, error2.path)
  );
}
function field(name, inner_type) {
  return (value4) => {
    let missing_field_error = new DecodeError("field", "nothing", toList([]));
    return try$(
      decode_field(value4, name),
      (maybe_inner) => {
        let _pipe = maybe_inner;
        let _pipe$1 = to_result(_pipe, toList([missing_field_error]));
        let _pipe$2 = try$(_pipe$1, inner_type);
        return map_errors(
          _pipe$2,
          (_capture) => {
            return push_path(_capture, name);
          }
        );
      }
    );
  };
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
  if (u === null)
    return 1108378658;
  if (u === void 0)
    return 1108378659;
  if (u === true)
    return 1108378657;
  if (u === false)
    return 1108378656;
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
function cloneAndSet(arr, at2, val) {
  const len = arr.length;
  const out = new Array(len);
  for (let i = 0; i < len; ++i) {
    out[i] = arr[i];
  }
  out[at2] = val;
  return out;
}
function spliceIn(arr, at2, val) {
  const len = arr.length;
  const out = new Array(len + 1);
  let i = 0;
  let g = 0;
  while (i < at2) {
    out[g++] = arr[i++];
  }
  out[g++] = val;
  while (i < len) {
    out[g++] = arr[i++];
  }
  return out;
}
function spliceOut(arr, at2) {
  const len = arr.length;
  const out = new Array(len - 1);
  let i = 0;
  let g = 0;
  while (i < at2) {
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
function assoc(root, shift, hash, key2, val, addedLeaf) {
  switch (root.type) {
    case ARRAY_NODE:
      return assocArray(root, shift, hash, key2, val, addedLeaf);
    case INDEX_NODE:
      return assocIndex(root, shift, hash, key2, val, addedLeaf);
    case COLLISION_NODE:
      return assocCollision(root, shift, hash, key2, val, addedLeaf);
  }
}
function assocArray(root, shift, hash, key2, val, addedLeaf) {
  const idx = mask(hash, shift);
  const node = root.array[idx];
  if (node === void 0) {
    addedLeaf.val = true;
    return {
      type: ARRAY_NODE,
      size: root.size + 1,
      array: cloneAndSet(root.array, idx, { type: ENTRY, k: key2, v: val })
    };
  }
  if (node.type === ENTRY) {
    if (isEqual(key2, node.k)) {
      if (val === node.v) {
        return root;
      }
      return {
        type: ARRAY_NODE,
        size: root.size,
        array: cloneAndSet(root.array, idx, {
          type: ENTRY,
          k: key2,
          v: val
        })
      };
    }
    addedLeaf.val = true;
    return {
      type: ARRAY_NODE,
      size: root.size,
      array: cloneAndSet(
        root.array,
        idx,
        createNode(shift + SHIFT, node.k, node.v, hash, key2, val)
      )
    };
  }
  const n = assoc(node, shift + SHIFT, hash, key2, val, addedLeaf);
  if (n === node) {
    return root;
  }
  return {
    type: ARRAY_NODE,
    size: root.size,
    array: cloneAndSet(root.array, idx, n)
  };
}
function assocIndex(root, shift, hash, key2, val, addedLeaf) {
  const bit = bitpos(hash, shift);
  const idx = index(root.bitmap, bit);
  if ((root.bitmap & bit) !== 0) {
    const node = root.array[idx];
    if (node.type !== ENTRY) {
      const n = assoc(node, shift + SHIFT, hash, key2, val, addedLeaf);
      if (n === node) {
        return root;
      }
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap,
        array: cloneAndSet(root.array, idx, n)
      };
    }
    const nodeKey = node.k;
    if (isEqual(key2, nodeKey)) {
      if (val === node.v) {
        return root;
      }
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap,
        array: cloneAndSet(root.array, idx, {
          type: ENTRY,
          k: key2,
          v: val
        })
      };
    }
    addedLeaf.val = true;
    return {
      type: INDEX_NODE,
      bitmap: root.bitmap,
      array: cloneAndSet(
        root.array,
        idx,
        createNode(shift + SHIFT, nodeKey, node.v, hash, key2, val)
      )
    };
  } else {
    const n = root.array.length;
    if (n >= MAX_INDEX_NODE) {
      const nodes = new Array(32);
      const jdx = mask(hash, shift);
      nodes[jdx] = assocIndex(EMPTY, shift + SHIFT, hash, key2, val, addedLeaf);
      let j = 0;
      let bitmap = root.bitmap;
      for (let i = 0; i < 32; i++) {
        if ((bitmap & 1) !== 0) {
          const node = root.array[j++];
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
      const newArray = spliceIn(root.array, idx, {
        type: ENTRY,
        k: key2,
        v: val
      });
      addedLeaf.val = true;
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap | bit,
        array: newArray
      };
    }
  }
}
function assocCollision(root, shift, hash, key2, val, addedLeaf) {
  if (hash === root.hash) {
    const idx = collisionIndexOf(root, key2);
    if (idx !== -1) {
      const entry = root.array[idx];
      if (entry.v === val) {
        return root;
      }
      return {
        type: COLLISION_NODE,
        hash,
        array: cloneAndSet(root.array, idx, { type: ENTRY, k: key2, v: val })
      };
    }
    const size = root.array.length;
    addedLeaf.val = true;
    return {
      type: COLLISION_NODE,
      hash,
      array: cloneAndSet(root.array, size, { type: ENTRY, k: key2, v: val })
    };
  }
  return assoc(
    {
      type: INDEX_NODE,
      bitmap: bitpos(root.hash, shift),
      array: [root]
    },
    shift,
    hash,
    key2,
    val,
    addedLeaf
  );
}
function collisionIndexOf(root, key2) {
  const size = root.array.length;
  for (let i = 0; i < size; i++) {
    if (isEqual(key2, root.array[i].k)) {
      return i;
    }
  }
  return -1;
}
function find2(root, shift, hash, key2) {
  switch (root.type) {
    case ARRAY_NODE:
      return findArray(root, shift, hash, key2);
    case INDEX_NODE:
      return findIndex(root, shift, hash, key2);
    case COLLISION_NODE:
      return findCollision(root, key2);
  }
}
function findArray(root, shift, hash, key2) {
  const idx = mask(hash, shift);
  const node = root.array[idx];
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
function findIndex(root, shift, hash, key2) {
  const bit = bitpos(hash, shift);
  if ((root.bitmap & bit) === 0) {
    return void 0;
  }
  const idx = index(root.bitmap, bit);
  const node = root.array[idx];
  if (node.type !== ENTRY) {
    return find2(node, shift + SHIFT, hash, key2);
  }
  if (isEqual(key2, node.k)) {
    return node;
  }
  return void 0;
}
function findCollision(root, key2) {
  const idx = collisionIndexOf(root, key2);
  if (idx < 0) {
    return void 0;
  }
  return root.array[idx];
}
function without(root, shift, hash, key2) {
  switch (root.type) {
    case ARRAY_NODE:
      return withoutArray(root, shift, hash, key2);
    case INDEX_NODE:
      return withoutIndex(root, shift, hash, key2);
    case COLLISION_NODE:
      return withoutCollision(root, key2);
  }
}
function withoutArray(root, shift, hash, key2) {
  const idx = mask(hash, shift);
  const node = root.array[idx];
  if (node === void 0) {
    return root;
  }
  let n = void 0;
  if (node.type === ENTRY) {
    if (!isEqual(node.k, key2)) {
      return root;
    }
  } else {
    n = without(node, shift + SHIFT, hash, key2);
    if (n === node) {
      return root;
    }
  }
  if (n === void 0) {
    if (root.size <= MIN_ARRAY_NODE) {
      const arr = root.array;
      const out = new Array(root.size - 1);
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
      size: root.size - 1,
      array: cloneAndSet(root.array, idx, n)
    };
  }
  return {
    type: ARRAY_NODE,
    size: root.size,
    array: cloneAndSet(root.array, idx, n)
  };
}
function withoutIndex(root, shift, hash, key2) {
  const bit = bitpos(hash, shift);
  if ((root.bitmap & bit) === 0) {
    return root;
  }
  const idx = index(root.bitmap, bit);
  const node = root.array[idx];
  if (node.type !== ENTRY) {
    const n = without(node, shift + SHIFT, hash, key2);
    if (n === node) {
      return root;
    }
    if (n !== void 0) {
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap,
        array: cloneAndSet(root.array, idx, n)
      };
    }
    if (root.bitmap === bit) {
      return void 0;
    }
    return {
      type: INDEX_NODE,
      bitmap: root.bitmap ^ bit,
      array: spliceOut(root.array, idx)
    };
  }
  if (isEqual(key2, node.k)) {
    if (root.bitmap === bit) {
      return void 0;
    }
    return {
      type: INDEX_NODE,
      bitmap: root.bitmap ^ bit,
      array: spliceOut(root.array, idx)
    };
  }
  return root;
}
function withoutCollision(root, key2) {
  const idx = collisionIndexOf(root, key2);
  if (idx < 0) {
    return root;
  }
  if (root.array.length === 1) {
    return void 0;
  }
  return {
    type: COLLISION_NODE,
    hash: root.hash,
    array: spliceOut(root.array, idx)
  };
}
function forEach(root, fn) {
  if (root === void 0) {
    return;
  }
  const items = root.array;
  const size = items.length;
  for (let i = 0; i < size; i++) {
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
  constructor(root, size) {
    this.root = root;
    this.size = size;
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
    const root = this.root === void 0 ? EMPTY : this.root;
    const newRoot = assoc(root, 0, getHash(key2), key2, val, addedLeaf);
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
function parse_int(value4) {
  if (/^[-+]?(\d+)$/.test(value4)) {
    return new Ok(parseInt(value4));
  } else {
    return new Error(Nil);
  }
}
function to_string(term) {
  return term.toString();
}
function float_to_string(float4) {
  const string6 = float4.toString().replace("+", "");
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
  let first3;
  const iterator = graphemes_iterator(string6);
  if (iterator) {
    first3 = iterator.next().value?.segment;
  } else {
    first3 = string6.match(/./su)?.[0];
  }
  if (first3) {
    return new Ok([first3, string6.slice(first3.length)]);
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
function add(a2, b) {
  return a2 + b;
}
function split(xs, pattern) {
  return List.fromArray(xs.split(pattern));
}
function join(xs, separator) {
  const iterator = xs[Symbol.iterator]();
  let result = iterator.next().value || "";
  let current = iterator.next();
  while (!current.done) {
    result = result + separator + current.value;
    current = iterator.next();
  }
  return result;
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
function floor(float4) {
  return Math.floor(float4);
}
function round2(float4) {
  return Math.round(float4);
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
function map_to_list(map8) {
  return List.fromArray(map8.entries());
}
function map_remove(key2, map8) {
  return map8.delete(key2);
}
function map_get(map8, key2) {
  const value4 = map8.get(key2, NOT_FOUND);
  if (value4 === NOT_FOUND) {
    return new Error(Nil);
  }
  return new Ok(value4);
}
function map_insert(key2, value4, map8) {
  return map8.set(key2, value4);
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
function decoder_error(expected, got) {
  return decoder_error_no_classify(expected, classify_dynamic(got));
}
function decoder_error_no_classify(expected, got) {
  return new Error(
    List.fromArray([new DecodeError(expected, got, List.fromArray([]))])
  );
}
function decode_string(data2) {
  return typeof data2 === "string" ? new Ok(data2) : decoder_error("String", data2);
}
function decode_int(data2) {
  return Number.isInteger(data2) ? new Ok(data2) : decoder_error("Int", data2);
}
function decode_field(value4, name) {
  const not_a_map_error = () => decoder_error("Dict", value4);
  if (value4 instanceof Dict || value4 instanceof WeakMap || value4 instanceof Map) {
    const entry = map_get(value4, name);
    return new Ok(entry.isOk() ? new Some(entry[0]) : new None());
  } else if (value4 === null) {
    return not_a_map_error();
  } else if (Object.getPrototypeOf(value4) == Object.prototype) {
    return try_get_field(value4, name, () => new Ok(new None()));
  } else {
    return try_get_field(value4, name, not_a_map_error);
  }
}
function try_get_field(value4, field3, or_else) {
  try {
    return field3 in value4 ? new Ok(new Some(value4[field3])) : or_else();
  } catch {
    return or_else();
  }
}
function inspect(v) {
  const t = typeof v;
  if (v === true)
    return "True";
  if (v === false)
    return "False";
  if (v === null)
    return "//js(null)";
  if (v === void 0)
    return "Nil";
  if (t === "string")
    return inspectString(v);
  if (t === "bigint" || Number.isInteger(v))
    return v.toString();
  if (t === "number")
    return float_to_string(v);
  if (Array.isArray(v))
    return `#(${v.map(inspect).join(", ")})`;
  if (v instanceof List)
    return inspectList(v);
  if (v instanceof UtfCodepoint)
    return inspectUtfCodepoint(v);
  if (v instanceof BitArray)
    return `<<${bit_array_inspect(v, "")}>>`;
  if (v instanceof CustomType)
    return inspectCustomType(v);
  if (v instanceof Dict)
    return inspectDict(v);
  if (v instanceof Set)
    return `//js(Set(${[...v].map(inspect).join(", ")}))`;
  if (v instanceof RegExp)
    return `//js(${v})`;
  if (v instanceof Date)
    return `//js(Date("${v.toISOString()}"))`;
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
function inspectDict(map8) {
  let body2 = "dict.from_list([";
  let first3 = true;
  map8.forEach((value4, key2) => {
    if (!first3)
      body2 = body2 + ", ";
    body2 = body2 + "#(" + inspect(key2) + ", " + inspect(value4) + ")";
    first3 = false;
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
    const value4 = inspect(record[label]);
    return isNaN(parseInt(label)) ? `${label}: ${value4}` : value4;
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
function append3(first3, second2) {
  let _pipe = first3;
  let _pipe$1 = identity(_pipe);
  let _pipe$2 = append2(_pipe$1, second2);
  return identity(_pipe$2);
}
function concat2(strings) {
  let _pipe = strings;
  let _pipe$1 = concat(_pipe);
  return identity(_pipe$1);
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
    if (entry === token2)
      return new Ok(new None());
    return new Ok(new Some(entry));
  }
  const key_is_int = Number.isInteger(key2);
  if (key_is_int && key2 >= 0 && key2 < 8 && data2 instanceof List) {
    let i = 0;
    for (const value4 of data2) {
      if (i === key2)
        return new Ok(new Some(value4));
      i++;
    }
    return new Error("Indexable");
  }
  if (key_is_int && Array.isArray(data2) || data2 && typeof data2 === "object" || data2 && Object.getPrototypeOf(data2) === Object.prototype) {
    if (key2 in data2)
      return new Ok(new Some(data2[key2]));
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
  for (const element2 of data2) {
    const layer = decode2(element2);
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
  if (Number.isInteger(data2))
    return new Ok(data2);
  return new Error(0);
}
function string3(data2) {
  if (typeof data2 === "string")
    return new Ok(data2);
  return new Error(0);
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
function one_of(first3, alternatives) {
  return new Decoder(
    (dynamic_data) => {
      let $ = first3.function(dynamic_data);
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
  return run_dynamic_function(data2, "String", string3);
}
var string4 = /* @__PURE__ */ new Decoder(decode_string2);
function list2(inner) {
  return new Decoder(
    (data2) => {
      return list(
        data2,
        inner.function,
        (p2, k) => {
          return push_path2(p2, toList([k]));
        },
        0,
        toList([])
      );
    }
  );
}
function push_path2(layer, path2) {
  let decoder = one_of(
    string4,
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
      return push_path2(_pipe, reverse(position));
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
        return push_path2(_pipe, reverse(position));
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
          return push_path2(_pipe, reverse(position));
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
function at(path2, inner) {
  return new Decoder(
    (data2) => {
      return index3(
        path2,
        toList([]),
        inner.function,
        data2,
        (data3, position) => {
          let $ = inner.function(data3);
          let default$ = $[0];
          let _pipe = [
            default$,
            toList([new DecodeError2("Field", "Nothing", toList([]))])
          ];
          return push_path2(_pipe, reverse(position));
        }
      );
    }
  );
}
function field2(field_name, field_decoder, next) {
  return subfield(toList([field_name]), field_decoder, next);
}

// build/dev/javascript/gleam_json/gleam_json_ffi.mjs
function json_to_string(json) {
  return JSON.stringify(json);
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
function getJsonDecodeError(stdErr, json) {
  if (isUnexpectedEndOfInput(stdErr))
    return new UnexpectedEndOfInput();
  return toUnexpectedByteError(stdErr, json);
}
function isUnexpectedEndOfInput(err) {
  const unexpectedEndOfInputRegex = /((unexpected (end|eof))|(end of data)|(unterminated string)|(json( parse error|\.parse)\: expected '(\:|\}|\])'))/i;
  return unexpectedEndOfInputRegex.test(err.message);
}
function toUnexpectedByteError(err, json) {
  let converters = [
    v8UnexpectedByteError,
    oldV8UnexpectedByteError,
    jsCoreUnexpectedByteError,
    spidermonkeyUnexpectedByteError
  ];
  for (let converter of converters) {
    let result = converter(err, json);
    if (result)
      return result;
  }
  return new UnexpectedByte("", 0);
}
function v8UnexpectedByteError(err) {
  const regex = /unexpected token '(.)', ".+" is not valid JSON/i;
  const match = regex.exec(err.message);
  if (!match)
    return null;
  const byte = toHex(match[1]);
  return new UnexpectedByte(byte, -1);
}
function oldV8UnexpectedByteError(err) {
  const regex = /unexpected token (.) in JSON at position (\d+)/i;
  const match = regex.exec(err.message);
  if (!match)
    return null;
  const byte = toHex(match[1]);
  const position = Number(match[2]);
  return new UnexpectedByte(byte, position);
}
function spidermonkeyUnexpectedByteError(err, json) {
  const regex = /(unexpected character|expected .*) at line (\d+) column (\d+)/i;
  const match = regex.exec(err.message);
  if (!match)
    return null;
  const line2 = Number(match[2]);
  const column = Number(match[3]);
  const position = getPositionFromMultiline(line2, column, json);
  const byte = toHex(json[position]);
  return new UnexpectedByte(byte, position);
}
function jsCoreUnexpectedByteError(err) {
  const regex = /unexpected (identifier|token) "(.)"/i;
  const match = regex.exec(err.message);
  if (!match)
    return null;
  const byte = toHex(match[2]);
  return new UnexpectedByte(byte, 0);
}
function toHex(char) {
  return "0x" + char.charCodeAt(0).toString(16).toUpperCase();
}
function getPositionFromMultiline(line2, column, string6) {
  if (line2 === 1)
    return column - 1;
  let currentLn = 1;
  let position = 0;
  string6.split("").find((char, idx) => {
    if (char === "\n")
      currentLn += 1;
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
function do_parse(json, decoder) {
  return then$(
    decode(json),
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
function parse(json, decoder) {
  return do_parse(json, decoder);
}
function to_string2(json) {
  return json_to_string(json);
}
function string5(input2) {
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
    let value4 = input2[0];
    return inner_type(value4);
  } else {
    return null$();
  }
}
function object2(entries) {
  return object(entries);
}

// build/dev/javascript/gleam_stdlib/gleam/uri.mjs
var Uri = class extends CustomType {
  constructor(scheme, userinfo, host, port, path2, query, fragment2) {
    super();
    this.scheme = scheme;
    this.userinfo = userinfo;
    this.host = host;
    this.port = port;
    this.path = path2;
    this.query = query;
    this.fragment = fragment2;
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
    let size = loop$size;
    if (uri_string.startsWith("#") && size === 0) {
      let rest = uri_string.slice(1);
      return parse_fragment(rest, pieces);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      let query = string_codeunit_slice(original, 0, size);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          _record.scheme,
          _record.userinfo,
          _record.host,
          _record.port,
          _record.path,
          new Some(query),
          _record.fragment
        );
      })();
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
      loop$size = size + 1;
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
    let size = loop$size;
    if (uri_string.startsWith("?")) {
      let rest = uri_string.slice(1);
      let path2 = string_codeunit_slice(original, 0, size);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          _record.scheme,
          _record.userinfo,
          _record.host,
          _record.port,
          path2,
          _record.query,
          _record.fragment
        );
      })();
      return parse_query_with_question_mark(rest, pieces$1);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      let path2 = string_codeunit_slice(original, 0, size);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          _record.scheme,
          _record.userinfo,
          _record.host,
          _record.port,
          path2,
          _record.query,
          _record.fragment
        );
      })();
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
      loop$size = size + 1;
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
      let pieces$1 = (() => {
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
      })();
      return parse_query_with_question_mark(rest, pieces$1);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      let pieces$1 = (() => {
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
      })();
      return parse_fragment(rest, pieces$1);
    } else if (uri_string.startsWith("/")) {
      let pieces$1 = (() => {
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
      })();
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
    let size = loop$size;
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
      let host = string_codeunit_slice(original, 0, size);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          _record.scheme,
          _record.userinfo,
          new Some(host),
          _record.port,
          _record.path,
          _record.query,
          _record.fragment
        );
      })();
      return parse_port(uri_string, pieces$1);
    } else if (uri_string.startsWith("/")) {
      let host = string_codeunit_slice(original, 0, size);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          _record.scheme,
          _record.userinfo,
          new Some(host),
          _record.port,
          _record.path,
          _record.query,
          _record.fragment
        );
      })();
      return parse_path(uri_string, pieces$1);
    } else if (uri_string.startsWith("?")) {
      let rest = uri_string.slice(1);
      let host = string_codeunit_slice(original, 0, size);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          _record.scheme,
          _record.userinfo,
          new Some(host),
          _record.port,
          _record.path,
          _record.query,
          _record.fragment
        );
      })();
      return parse_query_with_question_mark(rest, pieces$1);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      let host = string_codeunit_slice(original, 0, size);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          _record.scheme,
          _record.userinfo,
          new Some(host),
          _record.port,
          _record.path,
          _record.query,
          _record.fragment
        );
      })();
      return parse_fragment(rest, pieces$1);
    } else {
      let $ = pop_codeunit(uri_string);
      let rest = $[1];
      loop$original = original;
      loop$uri_string = rest;
      loop$pieces = pieces;
      loop$size = size + 1;
    }
  }
}
function parse_host_within_brackets_loop(loop$original, loop$uri_string, loop$pieces, loop$size) {
  while (true) {
    let original = loop$original;
    let uri_string = loop$uri_string;
    let pieces = loop$pieces;
    let size = loop$size;
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
    } else if (uri_string.startsWith("]") && size === 0) {
      let rest = uri_string.slice(1);
      return parse_port(rest, pieces);
    } else if (uri_string.startsWith("]")) {
      let rest = uri_string.slice(1);
      let host = string_codeunit_slice(original, 0, size + 1);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          _record.scheme,
          _record.userinfo,
          new Some(host),
          _record.port,
          _record.path,
          _record.query,
          _record.fragment
        );
      })();
      return parse_port(rest, pieces$1);
    } else if (uri_string.startsWith("/") && size === 0) {
      return parse_path(uri_string, pieces);
    } else if (uri_string.startsWith("/")) {
      let host = string_codeunit_slice(original, 0, size);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          _record.scheme,
          _record.userinfo,
          new Some(host),
          _record.port,
          _record.path,
          _record.query,
          _record.fragment
        );
      })();
      return parse_path(uri_string, pieces$1);
    } else if (uri_string.startsWith("?") && size === 0) {
      let rest = uri_string.slice(1);
      return parse_query_with_question_mark(rest, pieces);
    } else if (uri_string.startsWith("?")) {
      let rest = uri_string.slice(1);
      let host = string_codeunit_slice(original, 0, size);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          _record.scheme,
          _record.userinfo,
          new Some(host),
          _record.port,
          _record.path,
          _record.query,
          _record.fragment
        );
      })();
      return parse_query_with_question_mark(rest, pieces$1);
    } else if (uri_string.startsWith("#") && size === 0) {
      let rest = uri_string.slice(1);
      return parse_fragment(rest, pieces);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      let host = string_codeunit_slice(original, 0, size);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          _record.scheme,
          _record.userinfo,
          new Some(host),
          _record.port,
          _record.path,
          _record.query,
          _record.fragment
        );
      })();
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
        loop$size = size + 1;
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
    let pieces$1 = (() => {
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
    })();
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
    let size = loop$size;
    if (uri_string.startsWith("@") && size === 0) {
      let rest = uri_string.slice(1);
      return parse_host(rest, pieces);
    } else if (uri_string.startsWith("@")) {
      let rest = uri_string.slice(1);
      let userinfo = string_codeunit_slice(original, 0, size);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          _record.scheme,
          new Some(userinfo),
          _record.host,
          _record.port,
          _record.path,
          _record.query,
          _record.fragment
        );
      })();
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
      loop$size = size + 1;
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
    let size = loop$size;
    if (uri_string.startsWith("/") && size === 0) {
      return parse_authority_with_slashes(uri_string, pieces);
    } else if (uri_string.startsWith("/")) {
      let scheme = string_codeunit_slice(original, 0, size);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          new Some(lowercase(scheme)),
          _record.userinfo,
          _record.host,
          _record.port,
          _record.path,
          _record.query,
          _record.fragment
        );
      })();
      return parse_authority_with_slashes(uri_string, pieces$1);
    } else if (uri_string.startsWith("?") && size === 0) {
      let rest = uri_string.slice(1);
      return parse_query_with_question_mark(rest, pieces);
    } else if (uri_string.startsWith("?")) {
      let rest = uri_string.slice(1);
      let scheme = string_codeunit_slice(original, 0, size);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          new Some(lowercase(scheme)),
          _record.userinfo,
          _record.host,
          _record.port,
          _record.path,
          _record.query,
          _record.fragment
        );
      })();
      return parse_query_with_question_mark(rest, pieces$1);
    } else if (uri_string.startsWith("#") && size === 0) {
      let rest = uri_string.slice(1);
      return parse_fragment(rest, pieces);
    } else if (uri_string.startsWith("#")) {
      let rest = uri_string.slice(1);
      let scheme = string_codeunit_slice(original, 0, size);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          new Some(lowercase(scheme)),
          _record.userinfo,
          _record.host,
          _record.port,
          _record.path,
          _record.query,
          _record.fragment
        );
      })();
      return parse_fragment(rest, pieces$1);
    } else if (uri_string.startsWith(":") && size === 0) {
      return new Error(void 0);
    } else if (uri_string.startsWith(":")) {
      let rest = uri_string.slice(1);
      let scheme = string_codeunit_slice(original, 0, size);
      let pieces$1 = (() => {
        let _record = pieces;
        return new Uri(
          new Some(lowercase(scheme)),
          _record.userinfo,
          _record.host,
          _record.port,
          _record.path,
          _record.query,
          _record.fragment
        );
      })();
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
      loop$size = size + 1;
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
      let accumulator$1 = (() => {
        if (segment === "") {
          let accumulator$12 = accumulator;
          return accumulator$12;
        } else if (segment === ".") {
          let accumulator$12 = accumulator;
          return accumulator$12;
        } else if (segment === ".." && accumulator.hasLength(0)) {
          return toList([]);
        } else if (segment === ".." && accumulator.atLeastLength(1)) {
          let accumulator$12 = accumulator.tail;
          return accumulator$12;
        } else {
          let segment$1 = segment;
          let accumulator$12 = accumulator;
          return prepend(segment$1, accumulator$12);
        }
      })();
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
  let parts = (() => {
    let $ = uri.fragment;
    if ($ instanceof Some) {
      let fragment2 = $[0];
      return toList(["#", fragment2]);
    } else {
      return toList([]);
    }
  })();
  let parts$1 = (() => {
    let $ = uri.query;
    if ($ instanceof Some) {
      let query = $[0];
      return prepend("?", prepend(query, parts));
    } else {
      return parts;
    }
  })();
  let parts$2 = prepend(uri.path, parts$1);
  let parts$3 = (() => {
    let $ = uri.host;
    let $1 = starts_with(uri.path, "/");
    if ($ instanceof Some && !$1 && $[0] !== "") {
      let host = $[0];
      return prepend("/", parts$2);
    } else {
      return parts$2;
    }
  })();
  let parts$4 = (() => {
    let $ = uri.host;
    let $1 = uri.port;
    if ($ instanceof Some && $1 instanceof Some) {
      let port = $1[0];
      return prepend(":", prepend(to_string(port), parts$3));
    } else {
      return parts$3;
    }
  })();
  let parts$5 = (() => {
    let $ = uri.scheme;
    let $1 = uri.userinfo;
    let $2 = uri.host;
    if ($ instanceof Some && $1 instanceof Some && $2 instanceof Some) {
      let s = $[0];
      let u = $1[0];
      let h = $2[0];
      return prepend(
        s,
        prepend(
          "://",
          prepend(u, prepend("@", prepend(h, parts$4)))
        )
      );
    } else if ($ instanceof Some && $1 instanceof None && $2 instanceof Some) {
      let s = $[0];
      let h = $2[0];
      return prepend(s, prepend("://", prepend(h, parts$4)));
    } else if ($ instanceof Some && $1 instanceof Some && $2 instanceof None) {
      let s = $[0];
      return prepend(s, prepend(":", parts$4));
    } else if ($ instanceof Some && $1 instanceof None && $2 instanceof None) {
      let s = $[0];
      return prepend(s, prepend(":", parts$4));
    } else if ($ instanceof None && $1 instanceof None && $2 instanceof Some) {
      let h = $2[0];
      return prepend("//", prepend(h, parts$4));
    } else {
      return parts$4;
    }
  })();
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

// build/dev/javascript/lustre/lustre/effect.mjs
var Effect = class extends CustomType {
  constructor(all3) {
    super();
    this.all = all3;
  }
};
function custom(run2) {
  return new Effect(
    toList([
      (actions) => {
        return run2(actions.dispatch, actions.emit, actions.select, actions.root);
      }
    ])
  );
}
function from(effect) {
  return custom((dispatch, _, _1, _2) => {
    return effect(dispatch);
  });
}
function none() {
  return new Effect(toList([]));
}
function batch(effects) {
  return new Effect(
    fold(
      effects,
      toList([]),
      (b, _use1) => {
        let a2 = _use1.all;
        return append(b, a2);
      }
    )
  );
}

// build/dev/javascript/lustre/lustre/internals/vdom.mjs
var Text = class extends CustomType {
  constructor(content) {
    super();
    this.content = content;
  }
};
var Element2 = class extends CustomType {
  constructor(key2, namespace2, tag, attrs2, children2, self_closing, void$) {
    super();
    this.key = key2;
    this.namespace = namespace2;
    this.tag = tag;
    this.attrs = attrs2;
    this.children = children2;
    this.self_closing = self_closing;
    this.void = void$;
  }
};
var Map2 = class extends CustomType {
  constructor(subtree) {
    super();
    this.subtree = subtree;
  }
};
var Attribute = class extends CustomType {
  constructor(x0, x1, as_property) {
    super();
    this[0] = x0;
    this[1] = x1;
    this.as_property = as_property;
  }
};
var Event2 = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
function attribute_to_event_handler(attribute2) {
  if (attribute2 instanceof Attribute) {
    return new Error(void 0);
  } else {
    let name = attribute2[0];
    let handler = attribute2[1];
    let name$1 = drop_start(name, 2);
    return new Ok([name$1, handler]);
  }
}
function do_element_list_handlers(elements2, handlers2, key2) {
  return index_fold(
    elements2,
    handlers2,
    (handlers3, element2, index5) => {
      let key$1 = key2 + "-" + to_string(index5);
      return do_handlers(element2, handlers3, key$1);
    }
  );
}
function do_handlers(loop$element, loop$handlers, loop$key) {
  while (true) {
    let element2 = loop$element;
    let handlers2 = loop$handlers;
    let key2 = loop$key;
    if (element2 instanceof Text) {
      return handlers2;
    } else if (element2 instanceof Map2) {
      let subtree = element2.subtree;
      loop$element = subtree();
      loop$handlers = handlers2;
      loop$key = key2;
    } else {
      let attrs2 = element2.attrs;
      let children2 = element2.children;
      let handlers$1 = fold(
        attrs2,
        handlers2,
        (handlers3, attr) => {
          let $ = attribute_to_event_handler(attr);
          if ($.isOk()) {
            let name = $[0][0];
            let handler = $[0][1];
            return insert(handlers3, key2 + "-" + name, handler);
          } else {
            return handlers3;
          }
        }
      );
      return do_element_list_handlers(children2, handlers$1, key2);
    }
  }
}
function handlers(element2) {
  return do_handlers(element2, new_map(), "0");
}

// build/dev/javascript/lustre/lustre/attribute.mjs
function attribute(name, value4) {
  return new Attribute(name, identity(value4), false);
}
function on(name, handler) {
  return new Event2("on" + name, handler);
}
function map5(attr, f) {
  if (attr instanceof Attribute) {
    let name$1 = attr[0];
    let value$1 = attr[1];
    let as_property = attr.as_property;
    return new Attribute(name$1, value$1, as_property);
  } else {
    let on$1 = attr[0];
    let handler = attr[1];
    return new Event2(on$1, (e) => {
      return map3(handler(e), f);
    });
  }
}
function style(properties) {
  return attribute(
    "style",
    fold(
      properties,
      "",
      (styles, _use1) => {
        let name$1 = _use1[0];
        let value$1 = _use1[1];
        return styles + name$1 + ":" + value$1 + ";";
      }
    )
  );
}
function class$(name) {
  return attribute("class", name);
}
function data(key2, value4) {
  return attribute("data-" + key2, value4);
}
function id(name) {
  return attribute("id", name);
}
function value(val) {
  return attribute("value", val);
}
function placeholder(text3) {
  return attribute("placeholder", text3);
}
function href(uri) {
  return attribute("href", uri);
}
function rel(relationship) {
  return attribute("rel", relationship);
}

// build/dev/javascript/lustre/lustre/element.mjs
function element(tag, attrs2, children2) {
  if (tag === "area") {
    return new Element2("", "", tag, attrs2, toList([]), false, true);
  } else if (tag === "base") {
    return new Element2("", "", tag, attrs2, toList([]), false, true);
  } else if (tag === "br") {
    return new Element2("", "", tag, attrs2, toList([]), false, true);
  } else if (tag === "col") {
    return new Element2("", "", tag, attrs2, toList([]), false, true);
  } else if (tag === "embed") {
    return new Element2("", "", tag, attrs2, toList([]), false, true);
  } else if (tag === "hr") {
    return new Element2("", "", tag, attrs2, toList([]), false, true);
  } else if (tag === "img") {
    return new Element2("", "", tag, attrs2, toList([]), false, true);
  } else if (tag === "input") {
    return new Element2("", "", tag, attrs2, toList([]), false, true);
  } else if (tag === "link") {
    return new Element2("", "", tag, attrs2, toList([]), false, true);
  } else if (tag === "meta") {
    return new Element2("", "", tag, attrs2, toList([]), false, true);
  } else if (tag === "param") {
    return new Element2("", "", tag, attrs2, toList([]), false, true);
  } else if (tag === "source") {
    return new Element2("", "", tag, attrs2, toList([]), false, true);
  } else if (tag === "track") {
    return new Element2("", "", tag, attrs2, toList([]), false, true);
  } else if (tag === "wbr") {
    return new Element2("", "", tag, attrs2, toList([]), false, true);
  } else {
    return new Element2("", "", tag, attrs2, children2, false, false);
  }
}
function do_keyed(el, key2) {
  if (el instanceof Element2) {
    let namespace2 = el.namespace;
    let tag = el.tag;
    let attrs2 = el.attrs;
    let children2 = el.children;
    let self_closing = el.self_closing;
    let void$ = el.void;
    return new Element2(
      key2,
      namespace2,
      tag,
      attrs2,
      children2,
      self_closing,
      void$
    );
  } else if (el instanceof Map2) {
    let subtree = el.subtree;
    return new Map2(() => {
      return do_keyed(subtree(), key2);
    });
  } else {
    return el;
  }
}
function keyed(el, children2) {
  return el(
    map2(
      children2,
      (_use0) => {
        let key2 = _use0[0];
        let child = _use0[1];
        return do_keyed(child, key2);
      }
    )
  );
}
function namespaced(namespace2, tag, attrs2, children2) {
  return new Element2("", namespace2, tag, attrs2, children2, false, false);
}
function text(content) {
  return new Text(content);
}
function fragment(elements2) {
  return element(
    "lustre-fragment",
    toList([style(toList([["display", "contents"]]))]),
    elements2
  );
}
function map6(element2, f) {
  if (element2 instanceof Text) {
    let content = element2.content;
    return new Text(content);
  } else if (element2 instanceof Map2) {
    let subtree = element2.subtree;
    return new Map2(() => {
      return map6(subtree(), f);
    });
  } else {
    let key2 = element2.key;
    let namespace2 = element2.namespace;
    let tag = element2.tag;
    let attrs2 = element2.attrs;
    let children2 = element2.children;
    let self_closing = element2.self_closing;
    let void$ = element2.void;
    return new Map2(
      () => {
        return new Element2(
          key2,
          namespace2,
          tag,
          map2(
            attrs2,
            (_capture) => {
              return map5(_capture, f);
            }
          ),
          map2(children2, (_capture) => {
            return map6(_capture, f);
          }),
          self_closing,
          void$
        );
      }
    );
  }
}

// build/dev/javascript/gleam_stdlib/gleam/set.mjs
var Set2 = class extends CustomType {
  constructor(dict2) {
    super();
    this.dict = dict2;
  }
};
function new$2() {
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

// build/dev/javascript/lustre/lustre/internals/patch.mjs
var Diff = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Emit = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Init = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
function is_empty_element_diff(diff2) {
  return isEqual(diff2.created, new_map()) && isEqual(
    diff2.removed,
    new$2()
  ) && isEqual(diff2.updated, new_map());
}

// build/dev/javascript/lustre/lustre/internals/runtime.mjs
var Attrs = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Batch = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Debug = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Dispatch = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Emit2 = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Event3 = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Shutdown = class extends CustomType {
};
var Subscribe = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Unsubscribe = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var ForceModel = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};

// build/dev/javascript/lustre/vdom.ffi.mjs
if (globalThis.customElements && !globalThis.customElements.get("lustre-fragment")) {
  globalThis.customElements.define(
    "lustre-fragment",
    class LustreFragment extends HTMLElement {
      constructor() {
        super();
      }
    }
  );
}
function morph(prev, next, dispatch) {
  let out;
  let stack = [{ prev, next, parent: prev.parentNode }];
  while (stack.length) {
    let { prev: prev2, next: next2, parent } = stack.pop();
    while (next2.subtree !== void 0)
      next2 = next2.subtree();
    if (next2.content !== void 0) {
      if (!prev2) {
        const created = document.createTextNode(next2.content);
        parent.appendChild(created);
        out ??= created;
      } else if (prev2.nodeType === Node.TEXT_NODE) {
        if (prev2.textContent !== next2.content)
          prev2.textContent = next2.content;
        out ??= prev2;
      } else {
        const created = document.createTextNode(next2.content);
        parent.replaceChild(created, prev2);
        out ??= created;
      }
    } else if (next2.tag !== void 0) {
      const created = createElementNode({
        prev: prev2,
        next: next2,
        dispatch,
        stack
      });
      if (!prev2) {
        parent.appendChild(created);
      } else if (prev2 !== created) {
        parent.replaceChild(created, prev2);
      }
      out ??= created;
    }
  }
  return out;
}
function createElementNode({ prev, next, dispatch, stack }) {
  const namespace2 = next.namespace || "http://www.w3.org/1999/xhtml";
  const canMorph = prev && prev.nodeType === Node.ELEMENT_NODE && prev.localName === next.tag && prev.namespaceURI === (next.namespace || "http://www.w3.org/1999/xhtml");
  const el = canMorph ? prev : namespace2 ? document.createElementNS(namespace2, next.tag) : document.createElement(next.tag);
  let handlersForEl;
  if (!registeredHandlers.has(el)) {
    const emptyHandlers = /* @__PURE__ */ new Map();
    registeredHandlers.set(el, emptyHandlers);
    handlersForEl = emptyHandlers;
  } else {
    handlersForEl = registeredHandlers.get(el);
  }
  const prevHandlers = canMorph ? new Set(handlersForEl.keys()) : null;
  const prevAttributes = canMorph ? new Set(Array.from(prev.attributes, (a2) => a2.name)) : null;
  let className = null;
  let style2 = null;
  let innerHTML = null;
  if (canMorph && next.tag === "textarea") {
    const innertText = next.children[Symbol.iterator]().next().value?.content;
    if (innertText !== void 0)
      el.value = innertText;
  }
  const delegated = [];
  for (const attr of next.attrs) {
    const name = attr[0];
    const value4 = attr[1];
    if (attr.as_property) {
      if (el[name] !== value4)
        el[name] = value4;
      if (canMorph)
        prevAttributes.delete(name);
    } else if (name.startsWith("on")) {
      const eventName = name.slice(2);
      const callback = dispatch(value4, eventName === "input");
      if (!handlersForEl.has(eventName)) {
        el.addEventListener(eventName, lustreGenericEventHandler);
      }
      handlersForEl.set(eventName, callback);
      if (canMorph)
        prevHandlers.delete(eventName);
    } else if (name.startsWith("data-lustre-on-")) {
      const eventName = name.slice(15);
      const callback = dispatch(lustreServerEventHandler);
      if (!handlersForEl.has(eventName)) {
        el.addEventListener(eventName, lustreGenericEventHandler);
      }
      handlersForEl.set(eventName, callback);
      el.setAttribute(name, value4);
      if (canMorph) {
        prevHandlers.delete(eventName);
        prevAttributes.delete(name);
      }
    } else if (name.startsWith("delegate:data-") || name.startsWith("delegate:aria-")) {
      el.setAttribute(name, value4);
      delegated.push([name.slice(10), value4]);
    } else if (name === "class") {
      className = className === null ? value4 : className + " " + value4;
    } else if (name === "style") {
      style2 = style2 === null ? value4 : style2 + value4;
    } else if (name === "dangerous-unescaped-html") {
      innerHTML = value4;
    } else {
      if (el.getAttribute(name) !== value4)
        el.setAttribute(name, value4);
      if (name === "value" || name === "selected")
        el[name] = value4;
      if (canMorph)
        prevAttributes.delete(name);
    }
  }
  if (className !== null) {
    el.setAttribute("class", className);
    if (canMorph)
      prevAttributes.delete("class");
  }
  if (style2 !== null) {
    el.setAttribute("style", style2);
    if (canMorph)
      prevAttributes.delete("style");
  }
  if (canMorph) {
    for (const attr of prevAttributes) {
      el.removeAttribute(attr);
    }
    for (const eventName of prevHandlers) {
      handlersForEl.delete(eventName);
      el.removeEventListener(eventName, lustreGenericEventHandler);
    }
  }
  if (next.tag === "slot") {
    window.queueMicrotask(() => {
      for (const child of el.assignedElements()) {
        for (const [name, value4] of delegated) {
          if (!child.hasAttribute(name)) {
            child.setAttribute(name, value4);
          }
        }
      }
    });
  }
  if (next.key !== void 0 && next.key !== "") {
    el.setAttribute("data-lustre-key", next.key);
  } else if (innerHTML !== null) {
    el.innerHTML = innerHTML;
    return el;
  }
  let prevChild = el.firstChild;
  let seenKeys = null;
  let keyedChildren = null;
  let incomingKeyedChildren = null;
  let firstChild = children(next).next().value;
  if (canMorph && firstChild !== void 0 && // Explicit checks are more verbose but truthy checks force a bunch of comparisons
  // we don't care about: it's never gonna be a number etc.
  firstChild.key !== void 0 && firstChild.key !== "") {
    seenKeys = /* @__PURE__ */ new Set();
    keyedChildren = getKeyedChildren(prev);
    incomingKeyedChildren = getKeyedChildren(next);
    for (const child of children(next)) {
      prevChild = diffKeyedChild(
        prevChild,
        child,
        el,
        stack,
        incomingKeyedChildren,
        keyedChildren,
        seenKeys
      );
    }
  } else {
    for (const child of children(next)) {
      stack.unshift({ prev: prevChild, next: child, parent: el });
      prevChild = prevChild?.nextSibling;
    }
  }
  while (prevChild) {
    const next2 = prevChild.nextSibling;
    el.removeChild(prevChild);
    prevChild = next2;
  }
  return el;
}
var registeredHandlers = /* @__PURE__ */ new WeakMap();
function lustreGenericEventHandler(event3) {
  const target2 = event3.currentTarget;
  if (!registeredHandlers.has(target2)) {
    target2.removeEventListener(event3.type, lustreGenericEventHandler);
    return;
  }
  const handlersForEventTarget = registeredHandlers.get(target2);
  if (!handlersForEventTarget.has(event3.type)) {
    target2.removeEventListener(event3.type, lustreGenericEventHandler);
    return;
  }
  handlersForEventTarget.get(event3.type)(event3);
}
function lustreServerEventHandler(event3) {
  const el = event3.currentTarget;
  const tag = el.getAttribute(`data-lustre-on-${event3.type}`);
  const data2 = JSON.parse(el.getAttribute("data-lustre-data") || "{}");
  const include = JSON.parse(el.getAttribute("data-lustre-include") || "[]");
  switch (event3.type) {
    case "input":
    case "change":
      include.push("target.value");
      break;
  }
  return {
    tag,
    data: include.reduce(
      (data3, property) => {
        const path2 = property.split(".");
        for (let i = 0, o = data3, e = event3; i < path2.length; i++) {
          if (i === path2.length - 1) {
            o[path2[i]] = e[path2[i]];
          } else {
            o[path2[i]] ??= {};
            e = e[path2[i]];
            o = o[path2[i]];
          }
        }
        return data3;
      },
      { data: data2 }
    )
  };
}
function getKeyedChildren(el) {
  const keyedChildren = /* @__PURE__ */ new Map();
  if (el) {
    for (const child of children(el)) {
      const key2 = child?.key || child?.getAttribute?.("data-lustre-key");
      if (key2)
        keyedChildren.set(key2, child);
    }
  }
  return keyedChildren;
}
function diffKeyedChild(prevChild, child, el, stack, incomingKeyedChildren, keyedChildren, seenKeys) {
  while (prevChild && !incomingKeyedChildren.has(prevChild.getAttribute("data-lustre-key"))) {
    const nextChild = prevChild.nextSibling;
    el.removeChild(prevChild);
    prevChild = nextChild;
  }
  if (keyedChildren.size === 0) {
    stack.unshift({ prev: prevChild, next: child, parent: el });
    prevChild = prevChild?.nextSibling;
    return prevChild;
  }
  if (seenKeys.has(child.key)) {
    console.warn(`Duplicate key found in Lustre vnode: ${child.key}`);
    stack.unshift({ prev: null, next: child, parent: el });
    return prevChild;
  }
  seenKeys.add(child.key);
  const keyedChild = keyedChildren.get(child.key);
  if (!keyedChild && !prevChild) {
    stack.unshift({ prev: null, next: child, parent: el });
    return prevChild;
  }
  if (!keyedChild && prevChild !== null) {
    const placeholder2 = document.createTextNode("");
    el.insertBefore(placeholder2, prevChild);
    stack.unshift({ prev: placeholder2, next: child, parent: el });
    return prevChild;
  }
  if (!keyedChild || keyedChild === prevChild) {
    stack.unshift({ prev: prevChild, next: child, parent: el });
    prevChild = prevChild?.nextSibling;
    return prevChild;
  }
  el.insertBefore(keyedChild, prevChild);
  stack.unshift({ prev: keyedChild, next: child, parent: el });
  return prevChild;
}
function* children(element2) {
  for (const child of element2.children) {
    yield* forceChild(child);
  }
}
function* forceChild(element2) {
  if (element2.subtree !== void 0) {
    yield* forceChild(element2.subtree());
  } else {
    yield element2;
  }
}

// build/dev/javascript/lustre/lustre.ffi.mjs
var LustreClientApplication = class _LustreClientApplication {
  /**
   * @template Flags
   *
   * @param {object} app
   * @param {(flags: Flags) => [Model, Lustre.Effect<Msg>]} app.init
   * @param {(msg: Msg, model: Model) => [Model, Lustre.Effect<Msg>]} app.update
   * @param {(model: Model) => Lustre.Element<Msg>} app.view
   * @param {string | HTMLElement} selector
   * @param {Flags} flags
   *
   * @returns {Gleam.Ok<(action: Lustre.Action<Lustre.Client, Msg>>) => void>}
   */
  static start({ init: init6, update: update3, view: view5 }, selector, flags) {
    if (!is_browser())
      return new Error(new NotABrowser());
    const root = selector instanceof HTMLElement ? selector : document.querySelector(selector);
    if (!root)
      return new Error(new ElementNotFound(selector));
    const app = new _LustreClientApplication(root, init6(flags), update3, view5);
    return new Ok((action) => app.send(action));
  }
  /**
   * @param {Element} root
   * @param {[Model, Lustre.Effect<Msg>]} init
   * @param {(model: Model, msg: Msg) => [Model, Lustre.Effect<Msg>]} update
   * @param {(model: Model) => Lustre.Element<Msg>} view
   *
   * @returns {LustreClientApplication}
   */
  constructor(root, [init6, effects], update3, view5) {
    this.root = root;
    this.#model = init6;
    this.#update = update3;
    this.#view = view5;
    this.#tickScheduled = window.setTimeout(
      () => this.#tick(effects.all.toArray(), true),
      0
    );
  }
  /** @type {Element} */
  root;
  /**
   * @param {Lustre.Action<Lustre.Client, Msg>} action
   *
   * @returns {void}
   */
  send(action) {
    if (action instanceof Debug) {
      if (action[0] instanceof ForceModel) {
        this.#tickScheduled = window.clearTimeout(this.#tickScheduled);
        this.#queue = [];
        this.#model = action[0][0];
        const vdom = this.#view(this.#model);
        const dispatch = (handler, immediate = false) => (event3) => {
          const result = handler(event3);
          if (result instanceof Ok) {
            this.send(new Dispatch(result[0], immediate));
          }
        };
        const prev = this.root.firstChild ?? this.root.appendChild(document.createTextNode(""));
        morph(prev, vdom, dispatch);
      }
    } else if (action instanceof Dispatch) {
      const msg = action[0];
      const immediate = action[1] ?? false;
      this.#queue.push(msg);
      if (immediate) {
        this.#tickScheduled = window.clearTimeout(this.#tickScheduled);
        this.#tick();
      } else if (!this.#tickScheduled) {
        this.#tickScheduled = window.setTimeout(() => this.#tick());
      }
    } else if (action instanceof Emit2) {
      const event3 = action[0];
      const data2 = action[1];
      this.root.dispatchEvent(
        new CustomEvent(event3, {
          detail: data2,
          bubbles: true,
          composed: true
        })
      );
    } else if (action instanceof Shutdown) {
      this.#tickScheduled = window.clearTimeout(this.#tickScheduled);
      this.#model = null;
      this.#update = null;
      this.#view = null;
      this.#queue = null;
      while (this.root.firstChild) {
        this.root.firstChild.remove();
      }
    }
  }
  /** @type {Model} */
  #model;
  /** @type {(model: Model, msg: Msg) => [Model, Lustre.Effect<Msg>]} */
  #update;
  /** @type {(model: Model) => Lustre.Element<Msg>} */
  #view;
  /** @type {Array<Msg>} */
  #queue = [];
  /** @type {number | undefined} */
  #tickScheduled;
  /**
   * @param {Lustre.Effect<Msg>[]} effects
   */
  #tick(effects = []) {
    this.#tickScheduled = void 0;
    this.#flush(effects);
    const vdom = this.#view(this.#model);
    const dispatch = (handler, immediate = false) => (event3) => {
      const result = handler(event3);
      if (result instanceof Ok) {
        this.send(new Dispatch(result[0], immediate));
      }
    };
    const prev = this.root.firstChild ?? this.root.appendChild(document.createTextNode(""));
    morph(prev, vdom, dispatch);
  }
  #flush(effects = []) {
    while (this.#queue.length > 0) {
      const msg = this.#queue.shift();
      const [next, effect] = this.#update(this.#model, msg);
      effects = effects.concat(effect.all.toArray());
      this.#model = next;
    }
    while (effects.length > 0) {
      const effect = effects.shift();
      const dispatch = (msg) => this.send(new Dispatch(msg));
      const emit2 = (event3, data2) => this.root.dispatchEvent(
        new CustomEvent(event3, {
          detail: data2,
          bubbles: true,
          composed: true
        })
      );
      const select = () => {
      };
      const root = this.root;
      effect({ dispatch, emit: emit2, select, root });
    }
    if (this.#queue.length > 0) {
      this.#flush(effects);
    }
  }
};
var start = LustreClientApplication.start;
var LustreServerApplication = class _LustreServerApplication {
  static start({ init: init6, update: update3, view: view5, on_attribute_change }, flags) {
    const app = new _LustreServerApplication(
      init6(flags),
      update3,
      view5,
      on_attribute_change
    );
    return new Ok((action) => app.send(action));
  }
  constructor([model, effects], update3, view5, on_attribute_change) {
    this.#model = model;
    this.#update = update3;
    this.#view = view5;
    this.#html = view5(model);
    this.#onAttributeChange = on_attribute_change;
    this.#renderers = /* @__PURE__ */ new Map();
    this.#handlers = handlers(this.#html);
    this.#tick(effects.all.toArray());
  }
  send(action) {
    if (action instanceof Attrs) {
      for (const attr of action[0]) {
        const decoder = this.#onAttributeChange.get(attr[0]);
        if (!decoder)
          continue;
        const msg = decoder(attr[1]);
        if (msg instanceof Error)
          continue;
        this.#queue.push(msg);
      }
      this.#tick();
    } else if (action instanceof Batch) {
      this.#queue = this.#queue.concat(action[0].toArray());
      this.#tick(action[1].all.toArray());
    } else if (action instanceof Debug) {
    } else if (action instanceof Dispatch) {
      this.#queue.push(action[0]);
      this.#tick();
    } else if (action instanceof Emit2) {
      const event3 = new Emit(action[0], action[1]);
      for (const [_, renderer] of this.#renderers) {
        renderer(event3);
      }
    } else if (action instanceof Event3) {
      const handler = this.#handlers.get(action[0]);
      if (!handler)
        return;
      const msg = handler(action[1]);
      if (msg instanceof Error)
        return;
      this.#queue.push(msg[0]);
      this.#tick();
    } else if (action instanceof Subscribe) {
      const attrs2 = keys(this.#onAttributeChange);
      const patch = new Init(attrs2, this.#html);
      this.#renderers = this.#renderers.set(action[0], action[1]);
      action[1](patch);
    } else if (action instanceof Unsubscribe) {
      this.#renderers = this.#renderers.delete(action[0]);
    }
  }
  #model;
  #update;
  #queue;
  #view;
  #html;
  #renderers;
  #handlers;
  #onAttributeChange;
  #tick(effects = []) {
    this.#flush(effects);
    const vdom = this.#view(this.#model);
    const diff2 = elements(this.#html, vdom);
    if (!is_empty_element_diff(diff2)) {
      const patch = new Diff(diff2);
      for (const [_, renderer] of this.#renderers) {
        renderer(patch);
      }
    }
    this.#html = vdom;
    this.#handlers = diff2.handlers;
  }
  #flush(effects = []) {
    while (this.#queue.length > 0) {
      const msg = this.#queue.shift();
      const [next, effect] = this.#update(this.#model, msg);
      effects = effects.concat(effect.all.toArray());
      this.#model = next;
    }
    while (effects.length > 0) {
      const effect = effects.shift();
      const dispatch = (msg) => this.send(new Dispatch(msg));
      const emit2 = (event3, data2) => this.root.dispatchEvent(
        new CustomEvent(event3, {
          detail: data2,
          bubbles: true,
          composed: true
        })
      );
      const select = () => {
      };
      const root = null;
      effect({ dispatch, emit: emit2, select, root });
    }
    if (this.#queue.length > 0) {
      this.#flush(effects);
    }
  }
};
var start_server_application = LustreServerApplication.start;
var is_browser = () => globalThis.window && window.document;

// build/dev/javascript/lustre/lustre.mjs
var App = class extends CustomType {
  constructor(init6, update3, view5, on_attribute_change) {
    super();
    this.init = init6;
    this.update = update3;
    this.view = view5;
    this.on_attribute_change = on_attribute_change;
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
function application(init6, update3, view5) {
  return new App(init6, update3, view5, new None());
}
function start2(app, selector, flags) {
  return guard(
    !is_browser(),
    new Error(new NotABrowser()),
    () => {
      return start(app, selector, flags);
    }
  );
}

// build/dev/javascript/lustre/lustre/element/html.mjs
function text2(content) {
  return text(content);
}
function h3(attrs2, children2) {
  return element("h3", attrs2, children2);
}
function div(attrs2, children2) {
  return element("div", attrs2, children2);
}
function hr(attrs2) {
  return element("hr", attrs2, toList([]));
}
function p(attrs2, children2) {
  return element("p", attrs2, children2);
}
function a(attrs2, children2) {
  return element("a", attrs2, children2);
}
function span(attrs2, children2) {
  return element("span", attrs2, children2);
}
function button(attrs2, children2) {
  return element("button", attrs2, children2);
}
function input(attrs2) {
  return element("input", attrs2, toList([]));
}
function textarea(attrs2, content) {
  return element("textarea", attrs2, toList([text(content)]));
}

// build/dev/javascript/lustre/lustre/event.mjs
function on2(name, handler) {
  return on(name, handler);
}
function on_click(msg) {
  return on2("click", (_) => {
    return new Ok(msg);
  });
}
function on_mouse_enter(msg) {
  return on2("mouseenter", (_) => {
    return new Ok(msg);
  });
}
function on_mouse_leave(msg) {
  return on2("mouseleave", (_) => {
    return new Ok(msg);
  });
}
function on_focus(msg) {
  return on2("focus", (_) => {
    return new Ok(msg);
  });
}
function on_blur(msg) {
  return on2("blur", (_) => {
    return new Ok(msg);
  });
}
function value2(event3) {
  let _pipe = event3;
  return field("target", field("value", string2))(
    _pipe
  );
}
function on_input(msg) {
  return on2(
    "input",
    (event3) => {
      let _pipe = value2(event3);
      return map3(_pipe, msg);
    }
  );
}

// build/dev/javascript/lustre/lustre/server_component.mjs
function component(attrs2) {
  return element("lustre-server-component", attrs2, toList([]));
}
function route(path2) {
  return attribute("route", path2);
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
var Patch = class extends CustomType {
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
  } else if (method instanceof Patch) {
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
function set_header(request, key2, value4) {
  let headers = key_set(request.headers, lowercase(key2), value4);
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
  static wrap(value4) {
    return value4 instanceof Promise ? new _PromiseLayer(value4) : value4;
  }
  static unwrap(value4) {
    return value4 instanceof _PromiseLayer ? value4.promise : value4;
  }
};
function resolve(value4) {
  return Promise.resolve(PromiseLayer.wrap(value4));
}
function then_await(promise, fn) {
  return promise.then((value4) => fn(PromiseLayer.unwrap(value4)));
}
function map_promise(promise, fn) {
  return promise.then(
    (value4) => PromiseLayer.wrap(fn(PromiseLayer.unwrap(value4)))
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

// build/dev/javascript/gleam_fetch/ffi.mjs
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
function to_fetch_request(request) {
  let url = to_string3(to_uri(request));
  let method = method_to_string(request.method).toUpperCase();
  let options = {
    headers: make_headers(request.headers),
    method
  };
  if (method !== "GET" && method !== "HEAD")
    options.body = request.body;
  return new globalThis.Request(url, options);
}
function make_headers(headersList) {
  let headers = new globalThis.Headers();
  for (let [k, v] of headersList)
    headers.append(k.toLowerCase(), v);
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
function send(request) {
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
          let window_location$1 = (() => {
            let _record = window_location;
            return new Uri(
              _record.scheme,
              _record.userinfo,
              _record.host,
              _record.port,
              _record.path,
              new None(),
              new None()
            );
          })();
          let full_request_uri = (() => {
            if (url.startsWith("/")) {
              let _record = window_location$1;
              return new Uri(
                _record.scheme,
                _record.userinfo,
                _record.host,
                _record.port,
                url,
                _record.query,
                _record.fragment
              );
            } else {
              let _record = window_location$1;
              return new Uri(
                _record.scheme,
                _record.userinfo,
                _record.host,
                _record.port,
                window_location$1.path + "/" + url,
                _record.query,
                _record.fragment
              );
            }
          })();
          return from_uri(full_request_uri);
        }
      );
    }
  );
}
function do_send(req, expect, dispatch) {
  let _pipe = send(req);
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
function get(url, expect) {
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
            let json = $[0];
            return new Ok(json);
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
var initial_location = window?.location?.href;
var do_initial_uri = () => {
  if (!initial_location) {
    return new Error(void 0);
  } else {
    return new Ok(uri_from_url(new URL(initial_location)));
  }
};
var do_init = (dispatch, options = defaults) => {
  document.addEventListener("click", (event3) => {
    const a2 = find_anchor(event3.target);
    if (!a2)
      return;
    try {
      const url = new URL(a2.href);
      const uri = uri_from_url(url);
      const is_external = url.host !== window.location.host;
      if (!options.handle_external_links && is_external)
        return;
      if (!options.handle_internal_links && !is_external)
        return;
      event3.preventDefault();
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
function init2(handler) {
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
  return field2(
    "audit_name",
    string4,
    (audit_name) => {
      return field2(
        "audit_formatted_name",
        string4,
        (audit_formatted_name) => {
          return field2(
            "in_scope_files",
            list2(string4),
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
function new$3(date, time, offset2) {
  return datetime(date, time, offset2);
}
function from_unix_milli3(unix_ts) {
  return new$3(
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
      ["p", string5(note.parent_id)],
      [
        "s",
        int3(
          (() => {
            let _pipe = note.significance;
            return note_significance_to_int(_pipe);
          })()
        )
      ],
      ["u", string5(note.user_id)],
      ["m", string5(note.message)],
      ["x", nullable(note.expanded_message, string5)],
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
  return field2(
    "n",
    string4,
    (note_id) => {
      return field2(
        "p",
        string4,
        (parent_id) => {
          return field2(
            "s",
            int2,
            (significance) => {
              return field2(
                "u",
                string4,
                (user_name) => {
                  return field2(
                    "m",
                    string4,
                    (message) => {
                      return field2(
                        "x",
                        optional(string4),
                        (expanded_message) => {
                          return field2(
                            "t",
                            int2,
                            (time) => {
                              return field2(
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
  constructor(significance, line_number, line_number_text, line_tag, line_id, leading_spaces, elements2, columns) {
    super();
    this.significance = significance;
    this.line_number = line_number;
    this.line_number_text = line_number_text;
    this.line_tag = line_tag;
    this.line_id = line_id;
    this.leading_spaces = leading_spaces;
    this.elements = elements2;
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
  constructor(element2) {
    super();
    this.element = element2;
  }
};
var PreProcessedGapNode = class extends CustomType {
  constructor(element2, leading_spaces) {
    super();
    this.element = element2;
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
  return field2(
    "type",
    string4,
    (variant) => {
      if (variant === "single_declaration_line") {
        return field2(
          "topic_id",
          string4,
          (topic_id) => {
            return field2(
              "topic_title",
              string4,
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
  return field2(
    "title",
    string4,
    (title2) => {
      return field2(
        "topic_id",
        string4,
        (topic_id) => {
          return success(new NodeReference(title2, topic_id));
        }
      );
    }
  );
}
function node_declaration_decoder() {
  return field2(
    "title",
    string4,
    (title2) => {
      return field2(
        "topic_id",
        string4,
        (topic_id) => {
          return field2(
            "kind",
            string4,
            (kind) => {
              return field2(
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
  return field2(
    "type",
    string4,
    (variant) => {
      if (variant === "pre_processed_declaration") {
        return field2(
          "node_id",
          int2,
          (node_id) => {
            return field2(
              "node_declaration",
              node_declaration_decoder(),
              (node_declaration) => {
                return field2(
                  "tokens",
                  string4,
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
        return field2(
          "referenced_node_id",
          int2,
          (referenced_node_id) => {
            return field2(
              "referenced_node_declaration",
              node_declaration_decoder(),
              (referenced_node_declaration) => {
                return field2(
                  "tokens",
                  string4,
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
        return field2(
          "element",
          string4,
          (element2) => {
            return success(new PreProcessedNode(element2));
          }
        );
      } else if (variant === "pre_processed_gap_node") {
        return field2(
          "element",
          string4,
          (element2) => {
            return field2(
              "leading_spaces",
              int2,
              (leading_spaces) => {
                return success(
                  new PreProcessedGapNode(element2, leading_spaces)
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
  return field2(
    "s",
    pre_processed_line_significance_decoder(),
    (significance) => {
      return field2(
        "n",
        int2,
        (line_number) => {
          return field2(
            "i",
            string4,
            (line_id) => {
              return field2(
                "l",
                int2,
                (leading_spaces) => {
                  return field2(
                    "e",
                    list2(pre_processed_node_decoder()),
                    (elements2) => {
                      return field2(
                        "c",
                        int2,
                        (columns) => {
                          let line_number_text = (() => {
                            let _pipe = line_number;
                            return to_string(_pipe);
                          })();
                          return success(
                            new PreProcessedLine(
                              significance,
                              line_number,
                              line_number_text,
                              "L" + line_number_text,
                              line_id,
                              leading_spaces,
                              elements2,
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
function focus(element2) {
  element2.focus();
}
function datasetGet(el, key2) {
  if (key2 in el.dataset) {
    return new Ok(el.dataset[key2]);
  }
  return new Error(void 0);
}

// build/dev/javascript/plinth/event_ffi.mjs
function preventDefault(event3) {
  return event3.preventDefault();
}
function ctrlKey(event3) {
  return event3.ctrlKey;
}
function key(event3) {
  return event3.key;
}
function shiftKey(event3) {
  return event3.shiftKey;
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
  let text3 = window.prompt(message, defaultValue);
  if (text3 !== null) {
    return new Ok(text3);
  } else {
    return new Error();
  }
}
function addEventListener3(type, listener) {
  return window.addEventListener(type, listener);
}
function document2(window2) {
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
function queueMicrotask(callback) {
  return window.queueMicrotask(callback);
}
function requestAnimationFrame(callback) {
  return window.requestAnimationFrame(callback);
}
function cancelAnimationFrame(callback) {
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
function new$4(issue) {
  return new Snag(issue, toList([]));
}
function error(issue) {
  return new Error(new$4(issue));
}
function line_print(snag) {
  let _pipe = prepend(append3("error: ", snag.issue), snag.cause);
  return join(_pipe, " <- ");
}

// build/dev/javascript/o11a_client/o11a/client/attributes.mjs
function read_line_count_data(data2) {
  let _pipe = datasetGet(data2, "lc");
  let _pipe$1 = try$(_pipe, parse_int);
  return replace_error(
    _pipe$1,
    new$4("Failed to read line count data")
  );
}
function encode_column_count_data(column_count) {
  return data("cc", to_string(column_count));
}
function read_column_count_data(data2) {
  let _pipe = datasetGet(data2, "cc");
  let _pipe$1 = try$(_pipe, parse_int);
  return replace_error(
    _pipe$1,
    new$4("Failed to read column count data")
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
    new$4("Failed to find non-empty line")
  );
}
function discussion_entry2(line_number, column_number) {
  return querySelector(
    ".dl" + to_string(line_number) + ".dc" + to_string(
      column_number
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

// build/dev/javascript/o11a_client/o11a/client/page_navigation.mjs
var Model2 = class extends CustomType {
  constructor(current_line_number, current_column_number, current_line_column_count, is_user_typing) {
    super();
    this.current_line_number = current_line_number;
    this.current_column_number = current_column_number;
    this.current_line_column_count = current_line_column_count;
    this.is_user_typing = is_user_typing;
  }
};
function init3() {
  return new Model2(16, 1, 16, false);
}
function prevent_default2(event3) {
  let $ = key(event3);
  if ($ === "ArrowUp") {
    return preventDefault(event3);
  } else if ($ === "ArrowDown") {
    return preventDefault(event3);
  } else if ($ === "ArrowLeft") {
    return preventDefault(event3);
  } else if ($ === "ArrowRight") {
    return preventDefault(event3);
  } else if ($ === "PageUp") {
    return preventDefault(event3);
  } else if ($ === "PageDown") {
    return preventDefault(event3);
  } else if ($ === "Enter") {
    return preventDefault(event3);
  } else if ($ === "e") {
    return preventDefault(event3);
  } else if ($ === "Escape") {
    return preventDefault(event3);
  } else {
    return void 0;
  }
}
function handle_expanded_input_focus(event3, model, else_do) {
  let $ = ctrlKey(event3);
  let $1 = key(event3);
  if ($ && $1 === "e") {
    return new Ok([model, none()]);
  } else {
    return else_do();
  }
}
function handle_discussion_escape(_, model, _1) {
  return new Ok([model, none()]);
}
function handle_input_focus(_, model, _1) {
  return new Ok([model, none()]);
}
function find_next_discussion_line(current_line, step) {
  return try$(
    (() => {
      let _pipe = querySelector("#audit-page");
      let _pipe$1 = replace_error(
        _pipe,
        new$4("Failed to find audit page")
      );
      return try$(_pipe$1, read_line_count_data);
    })(),
    (line_count) => {
      if (step > 0 && current_line === line_count) {
        return error(
          "Line is " + to_string(line_count) + ", cannot go further down"
        );
      } else if (step < 0 && current_line === 1) {
        return error("Line is 1, cannot go further up");
      } else if (step === 0) {
        return error("Step is zero");
      } else {
        let next_line = max(1, min(line_count, current_line + step));
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
          return find_next_discussion_line(
            next_line,
            (() => {
              if (step > 0 && next_line === line_count) {
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
            })()
          );
        }
      }
    }
  );
}
function focus_line_discussion(line_number, column_number) {
  return from(
    (_) => {
      let $ = (() => {
        let _pipe = discussion_entry2(line_number, column_number);
        let _pipe$1 = replace_error(
          _pipe,
          new$4("Failed to find line discussion to focus")
        );
        return map3(_pipe$1, focus);
      })();
      return void 0;
    }
  );
}
function handle_input_escape(event3, model, else_do) {
  let $ = key(event3);
  if ($ === "Escape") {
    let _pipe = [
      model,
      focus_line_discussion(
        model.current_line_number,
        model.current_column_number
      )
    ];
    return new Ok(_pipe);
  } else {
    return else_do();
  }
}
function move_focus_line(model, step) {
  return map3(
    find_next_discussion_line(model.current_line_number, step),
    (_use0) => {
      let new_line = _use0[0];
      let column_count = _use0[1];
      return [
        (() => {
          let _record = model;
          return new Model2(
            _record.current_line_number,
            _record.current_column_number,
            column_count,
            _record.is_user_typing
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
  let new_column = (() => {
    let _pipe2 = max(1, model.current_column_number + step);
    return min(_pipe2, model.current_line_column_count);
  })();
  let _pipe = [
    model,
    focus_line_discussion(model.current_line_number, new_column)
  ];
  return new Ok(_pipe);
}
function handle_keyboard_navigation(event3, model, else_do) {
  let $ = shiftKey(event3);
  let $1 = key(event3);
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
function do_page_navigation(event3, model) {
  let res = (() => {
    let $ = model.is_user_typing;
    if ($) {
      return handle_expanded_input_focus(
        event3,
        model,
        () => {
          return handle_input_escape(
            event3,
            model,
            () => {
              return new Ok([model, none()]);
            }
          );
        }
      );
    } else {
      return handle_keyboard_navigation(
        event3,
        model,
        () => {
          return handle_input_focus(
            event3,
            model,
            () => {
              return handle_expanded_input_focus(
                event3,
                model,
                () => {
                  return handle_discussion_escape(
                    event3,
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
  })();
  if (res.isOk()) {
    let model_effect = res[0];
    return model_effect;
  } else {
    let e = res[0];
    console_log(line_print(e));
    return [model, none()];
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
function line(attrs2) {
  return namespaced(namespace, "line", attrs2, toList([]));
}
function polyline(attrs2) {
  return namespaced(namespace, "polyline", attrs2, toList([]));
}
function svg(attrs2, children2) {
  return namespaced(namespace, "svg", attrs2, children2);
}
function path(attrs2) {
  return namespaced(namespace, "path", attrs2, toList([]));
}

// build/dev/javascript/o11a_common/lib/lucide.mjs
function messages_square(attributes) {
  return svg(
    prepend(
      attribute("stroke-linejoin", "round"),
      prepend(
        attribute("stroke-linecap", "round"),
        prepend(
          attribute("stroke-width", "2"),
          prepend(
            attribute("stroke", "currentColor"),
            prepend(
              attribute("fill", "none"),
              prepend(
                attribute("viewBox", "0 0 24 24"),
                prepend(
                  attribute("height", "24"),
                  prepend(attribute("width", "24"), attributes)
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
          attribute(
            "d",
            "M14 9a2 2 0 0 1-2 2H6l-4 4V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2z"
          )
        ])
      ),
      path(
        toList([
          attribute("d", "M18 9h2a2 2 0 0 1 2 2v11l-4-4h-6a2 2 0 0 1-2-2v-1")
        ])
      )
    ])
  );
}
function pencil_ruler(attributes) {
  return svg(
    prepend(
      attribute("stroke-linejoin", "round"),
      prepend(
        attribute("stroke-linecap", "round"),
        prepend(
          attribute("stroke-width", "2"),
          prepend(
            attribute("stroke", "currentColor"),
            prepend(
              attribute("fill", "none"),
              prepend(
                attribute("viewBox", "0 0 24 24"),
                prepend(
                  attribute("height", "24"),
                  prepend(attribute("width", "24"), attributes)
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
          attribute(
            "d",
            "M13 7 8.7 2.7a2.41 2.41 0 0 0-3.4 0L2.7 5.3a2.41 2.41 0 0 0 0 3.4L7 13"
          )
        ])
      ),
      path(toList([attribute("d", "m8 6 2-2")])),
      path(toList([attribute("d", "m18 16 2-2")])),
      path(
        toList([
          attribute(
            "d",
            "m17 11 4.3 4.3c.94.94.94 2.46 0 3.4l-2.6 2.6c-.94.94-2.46.94-3.4 0L11 17"
          )
        ])
      ),
      path(
        toList([
          attribute(
            "d",
            "M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"
          )
        ])
      ),
      path(toList([attribute("d", "m15 5 4 4")]))
    ])
  );
}
function list_collapse(attributes) {
  return svg(
    prepend(
      attribute("stroke-linejoin", "round"),
      prepend(
        attribute("stroke-linecap", "round"),
        prepend(
          attribute("stroke-width", "2"),
          prepend(
            attribute("stroke", "currentColor"),
            prepend(
              attribute("fill", "none"),
              prepend(
                attribute("viewBox", "0 0 24 24"),
                prepend(
                  attribute("height", "24"),
                  prepend(attribute("width", "24"), attributes)
                )
              )
            )
          )
        )
      )
    ),
    toList([
      path(toList([attribute("d", "m3 10 2.5-2.5L3 5")])),
      path(toList([attribute("d", "m3 19 2.5-2.5L3 14")])),
      path(toList([attribute("d", "M10 6h11")])),
      path(toList([attribute("d", "M10 12h11")])),
      path(toList([attribute("d", "M10 18h11")]))
    ])
  );
}
function maximize_2(attributes) {
  return svg(
    prepend(
      attribute("stroke-linejoin", "round"),
      prepend(
        attribute("stroke-linecap", "round"),
        prepend(
          attribute("stroke-width", "2"),
          prepend(
            attribute("stroke", "currentColor"),
            prepend(
              attribute("fill", "none"),
              prepend(
                attribute("viewBox", "0 0 24 24"),
                prepend(
                  attribute("height", "24"),
                  prepend(attribute("width", "24"), attributes)
                )
              )
            )
          )
        )
      )
    ),
    toList([
      polyline(toList([attribute("points", "15 3 21 3 21 9")])),
      polyline(toList([attribute("points", "9 21 3 21 3 15")])),
      line(
        toList([
          attribute("y2", "10"),
          attribute("y1", "3"),
          attribute("x2", "14"),
          attribute("x1", "21")
        ])
      ),
      line(
        toList([
          attribute("y2", "14"),
          attribute("y1", "21"),
          attribute("x2", "10"),
          attribute("x1", "3")
        ])
      )
    ])
  );
}
function x(attributes) {
  return svg(
    prepend(
      attribute("stroke-linejoin", "round"),
      prepend(
        attribute("stroke-linecap", "round"),
        prepend(
          attribute("stroke-width", "2"),
          prepend(
            attribute("stroke", "currentColor"),
            prepend(
              attribute("fill", "none"),
              prepend(
                attribute("viewBox", "0 0 24 24"),
                prepend(
                  attribute("height", "24"),
                  prepend(attribute("width", "24"), attributes)
                )
              )
            )
          )
        )
      )
    ),
    toList([
      path(toList([attribute("d", "M18 6 6 18")])),
      path(toList([attribute("d", "m6 6 12 12")]))
    ])
  );
}
function pencil(attributes) {
  return svg(
    prepend(
      attribute("stroke-linejoin", "round"),
      prepend(
        attribute("stroke-linecap", "round"),
        prepend(
          attribute("stroke-width", "2"),
          prepend(
            attribute("stroke", "currentColor"),
            prepend(
              attribute("fill", "none"),
              prepend(
                attribute("viewBox", "0 0 24 24"),
                prepend(
                  attribute("height", "24"),
                  prepend(attribute("width", "24"), attributes)
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
          attribute(
            "d",
            "M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z"
          )
        ])
      ),
      path(toList([attribute("d", "m15 5 4 4")]))
    ])
  );
}

// build/dev/javascript/o11a_client/lib/eventx.mjs
function on_ctrl_enter(msg) {
  return on2(
    "keydown",
    (event3) => {
      let decoder = field2(
        "ctrlKey",
        bool,
        (ctrl_key) => {
          return field2(
            "key",
            string4,
            (key2) => {
              return success([ctrl_key, key2]);
            }
          );
        }
      );
      let empty_error = toList([new DecodeError("", "", toList([]))]);
      return try$(
        (() => {
          let _pipe = run(event3, decoder);
          return replace_error(_pipe, empty_error);
        })(),
        (_use0) => {
          let ctrl_key = _use0[0];
          let key2 = _use0[1];
          if (ctrl_key && key2 === "Enter") {
            return new Ok(msg);
          } else {
            return new Error(empty_error);
          }
        }
      );
    }
  );
}

// build/dev/javascript/o11a_client/o11a/ui/discussion_overlay.mjs
var Model3 = class extends CustomType {
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
function init4(line_number, column_number, topic_id, topic_title, is_reference) {
  return new Model3(
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
    new$2(),
    new None()
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
              toList([text2("Close Thread"), x(toList([]))])
            )
          ])
        ),
        text2("Current Thread: "),
        text2(active_thread.parent_note.message),
        (() => {
          let $1 = active_thread.parent_note.expanded_message;
          if ($1 instanceof Some) {
            let expanded_message = $1[0];
            return div(
              toList([class$("mt-[.5rem]")]),
              toList([
                p(toList([]), toList([text2(expanded_message)]))
              ])
            );
          } else {
            return fragment(toList([]));
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
                  toList([text2(model.topic_title)])
                );
              } else {
                return text2(model.topic_title);
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
                return fragment(toList([]));
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
      toList([text2(significance)])
    );
  } else {
    return fragment(toList([]));
  }
}
function comments_view(model, current_thread_notes) {
  return map2(
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
                  p(toList([]), toList([text2(note.user_name)])),
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
                      return fragment(toList([]));
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
                      return fragment(toList([]));
                    }
                  })()
                ])
              )
            ])
          ),
          p(toList([]), toList([text2(note.message)])),
          (() => {
            let $ = contains2(model.expanded_messages, note.note_id);
            if ($) {
              return div(
                toList([class$("mt-[.5rem]")]),
                toList([
                  p(
                    toList([]),
                    toList([
                      text2(
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
              return fragment(toList([]));
            }
          })(),
          hr(toList([class$("mt-[.5rem]")]))
        ])
      );
    }
  );
}
function expanded_message_view(model) {
  let expanded_message_style = "absolute overlay p-[.5rem] flex w-[100%] h-60 mt-2";
  let textarea_style = "grow text-[.95rem] resize-none p-[.3rem]";
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
    toList([
      textarea(
        toList([
          id("expanded-message-box"),
          class$(textarea_style),
          placeholder("Write an expanded message body"),
          on_input(
            (var0) => {
              return new UserWroteExpandedMessage(var0);
            }
          ),
          on_focus(new UserFocusedExpandedInput()),
          on_blur(new UserUnfocusedInput()),
          on_ctrl_enter(new UserSubmittedNote())
        ]),
        (() => {
          let _pipe = model.current_expanded_message_draft;
          return unwrap(_pipe, "");
        })()
      )
    ])
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
function update(model, msg) {
  if (msg instanceof UserWroteNote) {
    let draft = msg[0];
    return [
      (() => {
        let _record = model;
        return new Model3(
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
        let $1 = (() => {
          let $2 = model.editing_note;
          if ($2 instanceof Some) {
            let note2 = $2[0];
            return [new Edit(), note2.note_id];
          } else {
            return [new None2(), model.current_thread_id];
          }
        })();
        let modifier = $1[0];
        let parent_id = $1[1];
        let expanded_message = (() => {
          let $2 = (() => {
            let _pipe = model.current_expanded_message_draft;
            return map(_pipe, trim);
          })();
          if ($2 instanceof Some && $2[0] === "") {
            return new None();
          } else {
            let msg$1 = $2;
            return msg$1;
          }
        })();
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
            return new Model3(
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
        return new Model3(
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
    let new_active_thread = (() => {
      let _pipe = model.active_thread;
      let _pipe$1 = map(
        _pipe,
        (thread) => {
          return thread.prior_thread;
        }
      );
      return flatten(_pipe$1);
    })();
    let new_current_thread_id = (() => {
      let _pipe = map(
        new_active_thread,
        (thread) => {
          return thread.current_thread_id;
        }
      );
      return unwrap(_pipe, model.topic_id);
    })();
    return [
      (() => {
        let _record = model;
        return new Model3(
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
        return new Model3(
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
        return new Model3(
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
          return new Model3(
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
          return new Model3(
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
        return new Model3(
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
          return new Model3(
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
        return new Model3(
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
        return new Model3(
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
  return on2(
    "keydown",
    (event3) => {
      let decoder = field2(
        "ctrlKey",
        bool,
        (ctrl_key) => {
          return field2(
            "key",
            string4,
            (key2) => {
              return success([ctrl_key, key2]);
            }
          );
        }
      );
      let empty_error = toList([new DecodeError("", "", toList([]))]);
      return try$(
        (() => {
          let _pipe = run(event3, decoder);
          return replace_error(_pipe, empty_error);
        })(),
        (_use0) => {
          let ctrl_key = _use0[0];
          let key2 = _use0[1];
          if (ctrl_key && key2 === "Enter") {
            return new Ok(enter_msg);
          } else if (key2 === "ArrowUp") {
            return new Ok(up_msg);
          } else {
            return new Error(empty_error);
          }
        }
      );
    }
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
          return fragment(toList([]));
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
function view(model, notes) {
  console_log("Rendering line discussion " + model.topic_title);
  let current_thread_notes = (() => {
    let _pipe = map_get(notes, model.current_thread_id);
    return unwrap2(_pipe, toList([]));
  })();
  return div(
    toList([
      class$(
        "absolute z-[3] w-[30rem] not-italic text-wrap select-text text left-[-.3rem]"
      ),
      (() => {
        let $ = model.line_number < 27;
        if ($) {
          return class$("top-[1.4rem]");
        } else {
          return class$("bottom-[1.4rem]");
        }
      })()
    ]),
    toList([
      (() => {
        let $ = model.is_reference && !model.show_reference_discussion;
        if ($) {
          return fragment(
            toList([
              div(
                toList([class$("overlay p-[.5rem]")]),
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
                            toList([text2(model.topic_title)])
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
                        let $1 = isEqual(
                          note.significance,
                          new Informational2()
                        );
                        if ($1) {
                          return new Ok(
                            p(
                              toList([]),
                              toList([
                                text2(
                                  note.message + (() => {
                                    let $2 = is_some(
                                      note.expanded_message
                                    );
                                    if ($2) {
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
              )
            ])
          );
        } else {
          return fragment(
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
                      return div(
                        toList([
                          id("comment-list"),
                          class$(
                            "flex flex-col-reverse overflow-auto max-h-[30rem] gap-[.5rem] mb-[.5rem]"
                          )
                        ]),
                        comments_view(model, current_thread_notes)
                      );
                    } else {
                      return fragment(toList([]));
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

// build/dev/javascript/o11a_client/o11a/ui/audit_page.mjs
var DiscussionReference = class extends CustomType {
  constructor(line_number, column_number, model) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
    this.model = model;
  }
};
var UserHoveredDiscussionEntry = class extends CustomType {
  constructor(line_number, column_number, node_id, topic_id, topic_title, is_reference) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
    this.node_id = node_id;
    this.topic_id = topic_id;
    this.topic_title = topic_title;
    this.is_reference = is_reference;
  }
};
var UserUnhoveredDiscussionEntry = class extends CustomType {
};
var UserClickedDiscussionEntry = class extends CustomType {
  constructor(line_number, column_number) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
  }
};
var UserFocusedDiscussionEntry = class extends CustomType {
  constructor(line_number, column_number) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
  }
};
var UserUpdatedDiscussion = class extends CustomType {
  constructor(line_number, column_number, update3) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
    this.update = update3;
  }
};
function map_discussion_msg(msg, selected_discussion) {
  return new UserUpdatedDiscussion(
    selected_discussion.line_number,
    selected_discussion.column_number,
    update(selected_discussion.model, msg)
  );
}
function discussion_view(discussion, element_line_number, element_column_number, selected_discussion) {
  if (selected_discussion instanceof Some) {
    let selected_discussion$1 = selected_discussion[0];
    let $ = element_line_number === selected_discussion$1.line_number && element_column_number === selected_discussion$1.column_number;
    if ($) {
      let _pipe = view(
        selected_discussion$1.model,
        discussion
      );
      return map6(
        _pipe,
        (_capture) => {
          return map_discussion_msg(_capture, selected_discussion$1);
        }
      );
    } else {
      return fragment(toList([]));
    }
  } else {
    return fragment(toList([]));
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
        class$(
          "inline-comment font-code code-extras font-code fade-in relative"
        ),
        class$("comment-preview"),
        class$(discussion_entry),
        attribute("tabindex", "0"),
        encode_grid_location_data(
          (() => {
            let _pipe = element_line_number;
            return to_string(_pipe);
          })(),
          (() => {
            let _pipe = element_column_number;
            return to_string(_pipe);
          })()
        ),
        on_mouse_enter(
          new UserHoveredDiscussionEntry(
            element_line_number,
            element_column_number,
            new None(),
            topic_id,
            topic_title,
            false
          )
        ),
        on_mouse_leave(new UserUnhoveredDiscussionEntry()),
        on_focus(
          new UserFocusedDiscussionEntry(
            element_line_number,
            element_column_number
          )
        )
      ]),
      toList([
        span(
          toList([
            on_click(
              new UserClickedDiscussionEntry(
                element_line_number,
                element_column_number
              )
            )
          ]),
          toList([
            text2(
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
        class$("inline-comment font-code code-extras relative"),
        class$("new-thread-preview"),
        class$(discussion_entry),
        attribute("tabindex", "0"),
        encode_grid_location_data(
          (() => {
            let _pipe = element_line_number;
            return to_string(_pipe);
          })(),
          (() => {
            let _pipe = element_column_number;
            return to_string(_pipe);
          })()
        ),
        on_mouse_enter(
          new UserHoveredDiscussionEntry(
            element_line_number,
            element_column_number,
            new None(),
            topic_id,
            topic_title,
            false
          )
        ),
        on_mouse_leave(new UserUnhoveredDiscussionEntry()),
        on_focus(
          new UserFocusedDiscussionEntry(
            element_line_number,
            element_column_number
          )
        )
      ]),
      toList([
        span(
          toList([
            on_click(
              new UserClickedDiscussionEntry(
                element_line_number,
                element_column_number
              )
            )
          ]),
          toList([text2("Start new thread")])
        ),
        discussion_view(
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
      id(node_declaration.topic_id),
      class$(
        node_declaration_kind_to_string(node_declaration.kind)
      ),
      class$(
        "declaration-preview relative N" + to_string(node_id)
      ),
      class$(discussion_entry),
      class$(discussion_entry_hover),
      attribute("tabindex", "0"),
      encode_topic_id_data(node_declaration.topic_id),
      encode_topic_title_data(node_declaration.title),
      encode_is_reference_data(false),
      encode_grid_location_data(
        (() => {
          let _pipe = element_line_number;
          return to_string(_pipe);
        })(),
        (() => {
          let _pipe = element_column_number;
          return to_string(_pipe);
        })()
      ),
      on_mouse_enter(
        new UserHoveredDiscussionEntry(
          element_line_number,
          element_column_number,
          new Some(node_id),
          node_declaration.topic_id,
          node_declaration.title,
          false
        )
      ),
      on_mouse_leave(new UserUnhoveredDiscussionEntry()),
      on_focus(
        new UserFocusedDiscussionEntry(
          element_line_number,
          element_column_number
        )
      )
    ]),
    toList([
      span(
        toList([
          on_click(
            new UserClickedDiscussionEntry(
              element_line_number,
              element_column_number
            )
          )
        ]),
        toList([text2(tokens)])
      ),
      discussion_view(
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
      class$(
        node_declaration_kind_to_string(
          referenced_node_declaration.kind
        )
      ),
      class$(
        "reference-preview relative N" + to_string(referenced_node_id)
      ),
      class$(discussion_entry),
      class$(discussion_entry_hover),
      attribute("tabindex", "0"),
      encode_topic_id_data(referenced_node_declaration.topic_id),
      encode_topic_title_data(referenced_node_declaration.title),
      encode_is_reference_data(true),
      encode_grid_location_data(
        (() => {
          let _pipe = element_line_number;
          return to_string(_pipe);
        })(),
        (() => {
          let _pipe = element_column_number;
          return to_string(_pipe);
        })()
      ),
      on_mouse_enter(
        new UserHoveredDiscussionEntry(
          element_line_number,
          element_column_number,
          new Some(referenced_node_id),
          referenced_node_declaration.topic_id,
          referenced_node_declaration.title,
          false
        )
      ),
      on_mouse_leave(new UserUnhoveredDiscussionEntry()),
      on_focus(
        new UserFocusedDiscussionEntry(
          element_line_number,
          element_column_number
        )
      )
    ]),
    toList([
      span(
        toList([
          on_click(
            new UserClickedDiscussionEntry(
              element_line_number,
              element_column_number
            )
          )
        ]),
        toList([text2(tokens)])
      ),
      discussion_view(
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
    (index5, element2) => {
      if (element2 instanceof PreProcessedDeclaration) {
        let node_id = element2.node_id;
        let node_declaration = element2.node_declaration;
        let tokens = element2.tokens;
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
      } else if (element2 instanceof PreProcessedReference) {
        let referenced_node_id = element2.referenced_node_id;
        let referenced_node_declaration = element2.referenced_node_declaration;
        let tokens = element2.tokens;
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
      } else if (element2 instanceof PreProcessedNode) {
        let element$1 = element2.element;
        return [
          index5,
          span(
            toList([attribute("dangerous-unescaped-html", element$1)]),
            toList([])
          )
        ];
      } else {
        let element$1 = element2.element;
        return [
          index5,
          span(
            toList([attribute("dangerous-unescaped-html", element$1)]),
            toList([])
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
    let backwards = (() => {
      let _pipe = slice(comment, 0, columns_remaining);
      return reverse3(_pipe);
    })();
    let in_limit_comment_length = (() => {
      let _pipe = backwards;
      let _pipe$1 = split_once(_pipe, " ");
      let _pipe$2 = unwrap2(_pipe$1, ["", backwards]);
      let _pipe$3 = second(_pipe$2);
      return string_length(_pipe$3);
    })();
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
  let parent_notes = (() => {
    let _pipe = map_get(discussion, topic_id);
    let _pipe$1 = unwrap2(_pipe, toList([]));
    return filter_map(
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
  })();
  let info_notes = (() => {
    let _pipe = parent_notes;
    let _pipe$1 = filter(
      _pipe,
      (computed_note) => {
        return isEqual(
          computed_note.significance,
          new Informational2()
        );
      }
    );
    let _pipe$2 = map2(
      _pipe$1,
      (_capture) => {
        return split_info_note(_capture, leading_spaces);
      }
    );
    return flatten2(_pipe$2);
  })();
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
      keyed(
        fragment,
        index_map(
          info_notes,
          (_use0, index5) => {
            let note_index_id = _use0[0];
            let note_message = _use0[1];
            let child = p(
              toList([class$("loc flex")]),
              toList([
                span(
                  toList([class$("line-number code-extras relative")]),
                  toList([
                    text2(loc.line_number_text),
                    span(
                      toList([
                        class$(
                          "absolute code-extras pl-[.1rem] pt-[.15rem] text-[.9rem]"
                        )
                      ]),
                      toList([
                        text2(
                          translate_number_to_letter(index5 + 1)
                        )
                      ])
                    )
                  ])
                ),
                span(
                  toList([class$("comment italic")]),
                  toList([
                    text2(
                      (() => {
                        let _pipe = repeat(" ", loc.leading_spaces);
                        return join(_pipe, "");
                      })() + note_message
                    )
                  ])
                )
              ])
            );
            return [note_index_id, child];
          }
        )
      ),
      p(
        toList([class$("loc flex")]),
        toList([
          span(
            toList([class$("line-number code-extras relative")]),
            toList([text2(loc.line_number_text)])
          ),
          fragment(
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
          toList([text2(loc.line_number_text)])
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
function view2(preprocessed_source, discussion, selected_discussion) {
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
  let _pipe = (() => {
    let $ = split2(path2, "/");
    if ($.hasLength(1) && $.head === "") {
      return toList([]);
    } else if ($.atLeastLength(1) && $.head === "") {
      let rest = $.tail;
      return prepend("/", rest);
    } else {
      let rest = $;
      return rest;
    }
  })();
  return filter(_pipe, (x2) => {
    return x2 !== "";
  });
}
function pop_windows_drive_specifier(path2) {
  let start3 = slice(path2, 0, 3);
  let codepoints = to_utf_codepoints(start3);
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
  let segments = (() => {
    let _pipe = split2(path$1, "/");
    return flat_map(
      _pipe,
      (_capture) => {
        return split2(_capture, "\\");
      }
    );
  })();
  let segments$1 = (() => {
    if (drive instanceof Some) {
      let drive$1 = drive[0];
      return prepend(drive$1, segments);
    } else {
      return segments;
    }
  })();
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
  let $ = (() => {
    let _pipe = map_get(all_audit_files, dir_name);
    return unwrap2(_pipe, [toList([]), toList([])]);
  })();
  let subdirs = $[0];
  let direct_files = $[1];
  return div(
    toList([id(dir_name)]),
    toList([
      p(
        toList([class$("tree-item")]),
        toList([
          text2(
            (() => {
              let _pipe = dir_name;
              return base_name(_pipe);
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
                text2(
                  (() => {
                    let _pipe = file;
                    return base_name(_pipe);
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
  let $ = (() => {
    let _pipe = map_get(grouped_files, audit_name);
    return unwrap2(_pipe, [toList([]), toList([])]);
  })();
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
                text2(
                  (() => {
                    let _pipe = file;
                    return base_name(_pipe);
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
function view3(file_contents, side_panel, grouped_files, audit_name, current_file_path) {
  return div(
    toList([id("tree-grid")]),
    toList([
      div(
        toList([id("file-tree")]),
        toList([
          h3(
            toList([id("audit-tree-header")]),
            toList([text2(audit_name + " files")])
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
          return fragment(toList([]));
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
          return fragment(toList([]));
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
        let prev = (() => {
          let _pipe$32 = first(acc);
          return unwrap2(_pipe$32, "");
        })();
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
  let in_scope_files$1 = (() => {
    let $ = current_file_path === dashboard_path$1;
    if ($) {
      return prepend(current_file_path, in_scope_files);
    } else {
      let $1 = contains(in_scope_files, current_file_path);
      if ($1) {
        return prepend(dashboard_path$1, in_scope_files);
      } else {
        return prepend(
          current_file_path,
          prepend(dashboard_path$1, in_scope_files)
        );
      }
    }
  })();
  let in_scope_files$2 = (() => {
    let $ = contains(in_scope_files$1, dashboard_path$1);
    if ($) {
      return in_scope_files$1;
    } else {
      return prepend(dashboard_path$1, in_scope_files$1);
    }
  })();
  let parents = (() => {
    let _pipe2 = in_scope_files$2;
    let _pipe$12 = flat_map(_pipe2, get_all_parents);
    return unique(_pipe$12);
  })();
  let _pipe = parents;
  let _pipe$1 = map2(
    _pipe,
    (parent) => {
      let parent_prefix = parent + "/";
      let items = (() => {
        let _pipe$12 = in_scope_files$2;
        return filter(
          _pipe$12,
          (path2) => {
            return starts_with(path2, parent_prefix);
          }
        );
      })();
      let $ = (() => {
        let _pipe$12 = items;
        return partition(
          _pipe$12,
          (path2) => {
            let relative = replace(path2, parent_prefix, "");
            return contains_string(relative, "/");
          }
        );
      })();
      let dirs = $[0];
      let direct_files = $[1];
      let subdirs = (() => {
        let _pipe$12 = dirs;
        let _pipe$2 = map2(
          _pipe$12,
          (dir) => {
            let relative = replace(dir, parent_prefix, "");
            let first_dir = (() => {
              let _pipe$22 = split2(relative, "/");
              let _pipe$3 = first(_pipe$22);
              return unwrap2(_pipe$3, "");
            })();
            return parent_prefix + first_dir;
          }
        );
        return unique(_pipe$2);
      })();
      return [parent, [subdirs, direct_files]];
    }
  );
  return from_list(_pipe$1);
}

// build/dev/javascript/o11a_client/o11a_client.mjs
var Model4 = class extends CustomType {
  constructor(route2, file_tree, audit_metadata, source_files, discussions, discussion_overlay_models, keyboard_model, selected_discussion, selected_node_id) {
    super();
    this.route = route2;
    this.file_tree = file_tree;
    this.audit_metadata = audit_metadata;
    this.source_files = source_files;
    this.discussions = discussions;
    this.discussion_overlay_models = discussion_overlay_models;
    this.keyboard_model = keyboard_model;
    this.selected_discussion = selected_discussion;
    this.selected_node_id = selected_node_id;
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
var UserHoveredDiscussionEntry2 = class extends CustomType {
  constructor(line_number, column_number, node_id, topic_id, topic_title, is_reference) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
    this.node_id = node_id;
    this.topic_id = topic_id;
    this.topic_title = topic_title;
    this.is_reference = is_reference;
  }
};
var UserUnhoveredDiscussionEntry2 = class extends CustomType {
};
var UserClickedDiscussionEntry2 = class extends CustomType {
  constructor(line_number, column_number) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
  }
};
var UserFocusedDiscussionEntry2 = class extends CustomType {
  constructor(line_number, column_number) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
  }
};
var UserUpdatedDiscussion2 = class extends CustomType {
  constructor(line_number, column_number, update3) {
    super();
    this.line_number = line_number;
    this.column_number = column_number;
    this.update = update3;
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
  let _pipe = parse_route(uri);
  return new OnRouteChange(_pipe);
}
function file_tree_from_route(route2, audit_metadata) {
  if (route2 instanceof O11aHomeRoute) {
    return new_map();
  } else if (route2 instanceof AuditDashboardRoute) {
    let audit_name = route2.audit_name;
    let in_scope_files = (() => {
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
      return unwrap2(_pipe$1, toList([]));
    })();
    return group_files_by_parent(
      in_scope_files,
      dashboard_path(audit_name),
      audit_name
    );
  } else {
    let audit_name = route2.audit_name;
    let current_file_path = route2.page_path;
    let in_scope_files = (() => {
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
      return unwrap2(_pipe$1, toList([]));
    })();
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
    return get(
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
    return get(
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
  return get(
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
function init5(_) {
  let route2 = (() => {
    let $ = do_initial_uri();
    if ($.isOk()) {
      let uri = $[0];
      return parse_route(uri);
    } else {
      return new O11aHomeRoute();
    }
  })();
  let init_model = new Model4(
    route2,
    new_map(),
    new_map(),
    new_map(),
    new_map(),
    new_map(),
    init3(),
    new None(),
    new None()
  );
  return [
    init_model,
    batch(
      toList([
        init2(on_url_change),
        from(
          (dispatch) => {
            return addEventListener3(
              "keydown",
              (event3) => {
                prevent_default2(event3);
                return dispatch(new UserEnteredKey(event3));
              }
            );
          }
        ),
        route_change_effect(init_model, init_model.route)
      ])
    )
  ];
}
function update2(model, msg) {
  if (msg instanceof OnRouteChange) {
    let route2 = msg.route;
    return [
      (() => {
        let _record = model;
        return new Model4(
          route2,
          file_tree_from_route(route2, model.audit_metadata),
          _record.audit_metadata,
          _record.source_files,
          _record.discussions,
          _record.discussion_overlay_models,
          _record.keyboard_model,
          _record.selected_discussion,
          _record.selected_node_id
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
        return new Model4(
          _record.route,
          file_tree_from_route(model.route, updated_audit_metadata),
          updated_audit_metadata,
          _record.source_files,
          _record.discussions,
          _record.discussion_overlay_models,
          _record.keyboard_model,
          _record.selected_discussion,
          _record.selected_node_id
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
        return new Model4(
          _record.route,
          _record.file_tree,
          _record.audit_metadata,
          insert(model.source_files, page_path, source_files),
          _record.discussions,
          _record.discussion_overlay_models,
          _record.keyboard_model,
          _record.selected_discussion,
          _record.selected_node_id
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
          return new Model4(
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
            _record.discussion_overlay_models,
            _record.keyboard_model,
            _record.selected_discussion,
            _record.selected_node_id
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
        return new Model4(
          _record.route,
          _record.file_tree,
          _record.audit_metadata,
          _record.source_files,
          _record.discussions,
          _record.discussion_overlay_models,
          keyboard_model,
          _record.selected_discussion,
          _record.selected_node_id
        );
      })(),
      effect
    ];
  } else if (msg instanceof UserFocusedDiscussionEntry2) {
    let line_number = msg.line_number;
    let column_number = msg.column_number;
    return [
      (() => {
        let _record = model;
        return new Model4(
          _record.route,
          _record.file_tree,
          _record.audit_metadata,
          _record.source_files,
          _record.discussions,
          _record.discussion_overlay_models,
          (() => {
            let _record$1 = model.keyboard_model;
            return new Model2(
              line_number,
              column_number,
              _record$1.current_line_column_count,
              _record$1.is_user_typing
            );
          })(),
          _record.selected_discussion,
          _record.selected_node_id
        );
      })(),
      none()
    ];
  } else if (msg instanceof UserHoveredDiscussionEntry2) {
    let line_number = msg.line_number;
    let column_number = msg.column_number;
    let node_id = msg.node_id;
    let topic_id = msg.topic_id;
    let topic_title = msg.topic_title;
    let is_reference = msg.is_reference;
    let selected_discussion = [line_number, column_number];
    let discussion_overlay_models = (() => {
      let $ = map_get(model.discussion_overlay_models, selected_discussion);
      if ($.isOk()) {
        return model.discussion_overlay_models;
      } else {
        return insert(
          model.discussion_overlay_models,
          selected_discussion,
          init4(
            line_number,
            column_number,
            topic_id,
            topic_title,
            is_reference
          )
        );
      }
    })();
    return [
      (() => {
        let _record = model;
        return new Model4(
          _record.route,
          _record.file_tree,
          _record.audit_metadata,
          _record.source_files,
          _record.discussions,
          discussion_overlay_models,
          _record.keyboard_model,
          new Some(selected_discussion),
          node_id
        );
      })(),
      none()
    ];
  } else if (msg instanceof UserUnhoveredDiscussionEntry2) {
    return [
      (() => {
        let _record = model;
        return new Model4(
          _record.route,
          _record.file_tree,
          _record.audit_metadata,
          _record.source_files,
          _record.discussions,
          _record.discussion_overlay_models,
          _record.keyboard_model,
          new None(),
          new None()
        );
      })(),
      none()
    ];
  } else if (msg instanceof UserClickedDiscussionEntry2) {
    let line_number = msg.line_number;
    let column_number = msg.column_number;
    echo("clicked discussion entry", "src/o11a_client.gleam", 338);
    return [
      model,
      from(
        (_) => {
          let res = (() => {
            let _pipe = discussion_input(line_number, column_number);
            return map3(_pipe, focus);
          })();
          if (res.isOk() && !res[0]) {
            return void 0;
          } else {
            return console_log("Failed to focus discussion input");
          }
        }
      )
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
            return post(
              "/submit-note/" + audit_name,
              object2(
                toList([
                  ["topic_id", string5(topic_id)],
                  [
                    "note_submission",
                    encode_note_submission(note_submission)
                  ]
                ])
              ),
              expect_json(
                field2(
                  "msg",
                  string4,
                  (msg2) => {
                    let _pipe = (() => {
                      if (msg2 === "success") {
                        return success(void 0);
                      } else {
                        return failure(void 0, msg2);
                      }
                    })();
                    return echo(_pipe, "src/o11a_client.gleam", 377);
                  }
                ),
                (response) => {
                  let _pipe = (() => {
                    if (response.isOk() && !response[0]) {
                      return new UserSuccessfullySubmittedNote(discussion_model);
                    } else {
                      let e = response[0];
                      return new UserFailedToSubmitNote(e);
                    }
                  })();
                  return echo(_pipe, "src/o11a_client.gleam", 384);
                }
              )
            );
          } else if ($ instanceof AuditDashboardRoute) {
            let audit_name = $.audit_name;
            return post(
              "/submit-note/" + audit_name,
              object2(
                toList([
                  ["topic_id", string5(topic_id)],
                  [
                    "note_submission",
                    encode_note_submission(note_submission)
                  ]
                ])
              ),
              expect_json(
                field2(
                  "msg",
                  string4,
                  (msg2) => {
                    let _pipe = (() => {
                      if (msg2 === "success") {
                        return success(void 0);
                      } else {
                        return failure(void 0, msg2);
                      }
                    })();
                    return echo(_pipe, "src/o11a_client.gleam", 377);
                  }
                ),
                (response) => {
                  let _pipe = (() => {
                    if (response.isOk() && !response[0]) {
                      return new UserSuccessfullySubmittedNote(discussion_model);
                    } else {
                      let e = response[0];
                      return new UserFailedToSubmitNote(e);
                    }
                  })();
                  return echo(_pipe, "src/o11a_client.gleam", 384);
                }
              )
            );
          } else {
            return none();
          }
        })()
      ];
    } else if (discussion_effect instanceof FocusDiscussionInput) {
      return [
        (() => {
          let _record = model;
          return new Model4(
            _record.route,
            _record.file_tree,
            _record.audit_metadata,
            _record.source_files,
            _record.discussions,
            insert(
              model.discussion_overlay_models,
              [line_number, column_number],
              discussion_model
            ),
            _record.keyboard_model,
            _record.selected_discussion,
            _record.selected_node_id
          );
        })(),
        none()
      ];
    } else if (discussion_effect instanceof FocusExpandedDiscussionInput) {
      return [
        (() => {
          let _record = model;
          return new Model4(
            _record.route,
            _record.file_tree,
            _record.audit_metadata,
            _record.source_files,
            _record.discussions,
            insert(
              model.discussion_overlay_models,
              [line_number, column_number],
              discussion_model
            ),
            _record.keyboard_model,
            _record.selected_discussion,
            _record.selected_node_id
          );
        })(),
        none()
      ];
    } else if (discussion_effect instanceof UnfocusDiscussionInput) {
      return [
        (() => {
          let _record = model;
          return new Model4(
            _record.route,
            _record.file_tree,
            _record.audit_metadata,
            _record.source_files,
            _record.discussions,
            insert(
              model.discussion_overlay_models,
              [line_number, column_number],
              discussion_model
            ),
            _record.keyboard_model,
            _record.selected_discussion,
            _record.selected_node_id
          );
        })(),
        none()
      ];
    } else if (discussion_effect instanceof MaximizeDiscussion) {
      return [
        (() => {
          let _record = model;
          return new Model4(
            _record.route,
            _record.file_tree,
            _record.audit_metadata,
            _record.source_files,
            _record.discussions,
            insert(
              model.discussion_overlay_models,
              [line_number, column_number],
              discussion_model
            ),
            _record.keyboard_model,
            _record.selected_discussion,
            _record.selected_node_id
          );
        })(),
        none()
      ];
    } else {
      return [
        (() => {
          let _record = model;
          return new Model4(
            _record.route,
            _record.file_tree,
            _record.audit_metadata,
            _record.source_files,
            _record.discussions,
            insert(
              model.discussion_overlay_models,
              [line_number, column_number],
              discussion_model
            ),
            _record.keyboard_model,
            _record.selected_discussion,
            _record.selected_node_id
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
        return new Model4(
          _record.route,
          _record.file_tree,
          _record.audit_metadata,
          _record.source_files,
          _record.discussions,
          insert(
            model.discussion_overlay_models,
            [updated_model.line_number, updated_model.column_number],
            updated_model
          ),
          _record.keyboard_model,
          _record.selected_discussion,
          _record.selected_node_id
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
function on_server_updated_discussion(msg) {
  return on2(
    server_updated_discussion,
    (event3) => {
      let empty_error = toList([new DecodeError("", "", toList([]))]);
      return try$(
        (() => {
          let _pipe = run(
            event3,
            at(toList(["detail", "audit_name"]), string4)
          );
          return replace_error(_pipe, empty_error);
        })(),
        (audit_name) => {
          let _pipe = msg(audit_name);
          return new Ok(_pipe);
        }
      );
    }
  );
}
function map_audit_page_msg(msg) {
  if (msg instanceof UserHoveredDiscussionEntry) {
    let line_number = msg.line_number;
    let column_number = msg.column_number;
    let node_id = msg.node_id;
    let topic_id = msg.topic_id;
    let topic_title = msg.topic_title;
    let is_reference = msg.is_reference;
    return new UserHoveredDiscussionEntry2(
      line_number,
      column_number,
      node_id,
      topic_id,
      topic_title,
      is_reference
    );
  } else if (msg instanceof UserUnhoveredDiscussionEntry) {
    return new UserUnhoveredDiscussionEntry2();
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
    return new UserFocusedDiscussionEntry2(line_number, column_number);
  }
}
function view4(model) {
  let $ = model.route;
  if ($ instanceof AuditDashboardRoute) {
    let audit_name = $.audit_name;
    return div(
      toList([]),
      toList([
        component(
          toList([
            route("/component-discussion/" + audit_name)
          ])
        ),
        view3(
          p(toList([]), toList([text2("Dashboard")])),
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
    return div(
      toList([]),
      toList([
        component(
          toList([
            route("/component-discussion/" + audit_name),
            on_server_updated_discussion(
              (var0) => {
                return new ServerUpdatedDiscussion(var0);
              }
            )
          ])
        ),
        view3(
          (() => {
            let _pipe = view2(
              (() => {
                let _pipe2 = map_get(model.source_files, page_path);
                let _pipe$1 = map3(
                  _pipe2,
                  (source_files) => {
                    if (source_files.isOk()) {
                      let source_files$1 = source_files[0];
                      return source_files$1;
                    } else {
                      return toList([]);
                    }
                  }
                );
                return unwrap2(_pipe$1, toList([]));
              })(),
              (() => {
                let _pipe2 = map_get(model.discussions, audit_name);
                return unwrap2(_pipe2, new_map());
              })(),
              (() => {
                let $1 = model.selected_discussion;
                if ($1 instanceof Some) {
                  let selected_discussion = $1[0];
                  let _pipe2 = map_get(
                    model.discussion_overlay_models,
                    selected_discussion
                  );
                  let _pipe$1 = map3(
                    _pipe2,
                    (model2) => {
                      return new Some(
                        new DiscussionReference(
                          selected_discussion[0],
                          selected_discussion[1],
                          model2
                        )
                      );
                    }
                  );
                  return unwrap2(_pipe$1, new None());
                } else {
                  return new None();
                }
              })()
            );
            return map6(_pipe, map_audit_page_msg);
          })(),
          new None(),
          model.file_tree,
          audit_name,
          page_path
        )
      ])
    );
  } else {
    return p(toList([]), toList([text2("Home")]));
  }
}
function main() {
  console_log("Starting client controller");
  let _pipe = application(init5, update2, view4);
  return start2(_pipe, "#app", void 0);
}
function echo(value4, file, line2) {
  const grey = "\x1B[90m";
  const reset_color = "\x1B[39m";
  const file_line = `${file}:${line2}`;
  const string_value = echo$inspect(value4);
  if (typeof process === "object" && process.stderr?.write) {
    const string6 = `${grey}${file_line}${reset_color}
${string_value}
`;
    process.stderr.write(string6);
  } else if (typeof Deno === "object") {
    const string6 = `${grey}${file_line}${reset_color}
${string_value}
`;
    Deno.stderr.writeSync(new TextEncoder().encode(string6));
  } else {
    const string6 = `${file_line}
${string_value}`;
    console.log(string6);
  }
  return value4;
}
function echo$inspectString(str) {
  let new_str = '"';
  for (let i = 0; i < str.length; i++) {
    let char = str[i];
    if (char == "\n")
      new_str += "\\n";
    else if (char == "\r")
      new_str += "\\r";
    else if (char == "	")
      new_str += "\\t";
    else if (char == "\f")
      new_str += "\\f";
    else if (char == "\\")
      new_str += "\\\\";
    else if (char == '"')
      new_str += '\\"';
    else if (char < " " || char > "~" && char < "\xA0") {
      new_str += "\\u{" + char.charCodeAt(0).toString(16).toUpperCase().padStart(4, "0") + "}";
    } else {
      new_str += char;
    }
  }
  new_str += '"';
  return new_str;
}
function echo$inspectDict(map8) {
  let body2 = "dict.from_list([";
  let first3 = true;
  let key_value_pairs = [];
  map8.forEach((value4, key2) => {
    key_value_pairs.push([key2, value4]);
  });
  key_value_pairs.sort();
  key_value_pairs.forEach(([key2, value4]) => {
    if (!first3)
      body2 = body2 + ", ";
    body2 = body2 + "#(" + echo$inspect(key2) + ", " + echo$inspect(value4) + ")";
    first3 = false;
  });
  return body2 + "])";
}
function echo$inspectCustomType(record) {
  const props = Object.keys(record).map((label) => {
    const value4 = echo$inspect(record[label]);
    return isNaN(parseInt(label)) ? `${label}: ${value4}` : value4;
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
  if (v === true)
    return "True";
  if (v === false)
    return "False";
  if (v === null)
    return "//js(null)";
  if (v === void 0)
    return "Nil";
  if (t === "string")
    return echo$inspectString(v);
  if (t === "bigint" || t === "number")
    return v.toString();
  if (Array.isArray(v))
    return `#(${v.map(echo$inspect).join(", ")})`;
  if (v instanceof List)
    return `[${v.toArray().map(echo$inspect).join(", ")}]`;
  if (v instanceof UtfCodepoint)
    return `//utfcodepoint(${String.fromCodePoint(v.value)})`;
  if (v instanceof BitArray)
    return echo$inspectBitArray(v);
  if (v instanceof CustomType)
    return echo$inspectCustomType(v);
  if (echo$isDict(v))
    return echo$inspectDict(v);
  if (v instanceof Set)
    return `//js(Set(${[...v].map(echo$inspect).join(", ")}))`;
  if (v instanceof RegExp)
    return `//js(${v})`;
  if (v instanceof Date)
    return `//js(Date("${v.toISOString()}"))`;
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
  let alignedBytes = bitArraySlice(bitArray, bitArray.bitOffset, endOfAlignedBytes);
  let remainingUnalignedBits = bitArray.bitSize % 8;
  if (remainingUnalignedBits > 0) {
    let remainingBits = bitArraySliceToInt(bitArray, endOfAlignedBytes, bitArray.bitSize, false, false);
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
function echo$isDict(value4) {
  try {
    return value4 instanceof Dict;
  } catch {
    return false;
  }
}

// build/.lustre/entry.mjs
main();
