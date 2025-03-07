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
    for (let _ of this) {
      if (desired <= 0)
        return true;
      desired--;
    }
    return desired <= 0;
  }
  // @internal
  hasLength(desired) {
    for (let _ of this) {
      if (desired <= 0)
        return false;
      desired--;
    }
    return desired === 0;
  }
  // @internal
  countLength() {
    let length3 = 0;
    for (let _ of this)
      length3++;
    return length3;
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
var BitArray = class _BitArray {
  constructor(buffer) {
    if (!(buffer instanceof Uint8Array)) {
      throw "BitArray can only be constructed from a Uint8Array";
    }
    this.buffer = buffer;
  }
  // @internal
  get length() {
    return this.buffer.length;
  }
  // @internal
  byteAt(index4) {
    return this.buffer[index4];
  }
  // @internal
  floatFromSlice(start2, end, isBigEndian) {
    return byteArrayToFloat(this.buffer, start2, end, isBigEndian);
  }
  // @internal
  intFromSlice(start2, end, isBigEndian, isSigned) {
    return byteArrayToInt(this.buffer, start2, end, isBigEndian, isSigned);
  }
  // @internal
  binaryFromSlice(start2, end) {
    const buffer = new Uint8Array(
      this.buffer.buffer,
      this.buffer.byteOffset + start2,
      end - start2
    );
    return new _BitArray(buffer);
  }
  // @internal
  sliceAfter(index4) {
    const buffer = new Uint8Array(
      this.buffer.buffer,
      this.buffer.byteOffset + index4,
      this.buffer.byteLength - index4
    );
    return new _BitArray(buffer);
  }
};
var UtfCodepoint = class {
  constructor(value3) {
    this.value = value3;
  }
};
function byteArrayToInt(byteArray, start2, end, isBigEndian, isSigned) {
  const byteSize = end - start2;
  if (byteSize <= 6) {
    let value3 = 0;
    if (isBigEndian) {
      for (let i = start2; i < end; i++) {
        value3 = value3 * 256 + byteArray[i];
      }
    } else {
      for (let i = end - 1; i >= start2; i--) {
        value3 = value3 * 256 + byteArray[i];
      }
    }
    if (isSigned) {
      const highBit = 2 ** (byteSize * 8 - 1);
      if (value3 >= highBit) {
        value3 -= highBit * 2;
      }
    }
    return value3;
  } else {
    let value3 = 0n;
    if (isBigEndian) {
      for (let i = start2; i < end; i++) {
        value3 = (value3 << 8n) + BigInt(byteArray[i]);
      }
    } else {
      for (let i = end - 1; i >= start2; i--) {
        value3 = (value3 << 8n) + BigInt(byteArray[i]);
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
}
function byteArrayToFloat(byteArray, start2, end, isBigEndian) {
  const view2 = new DataView(byteArray.buffer);
  const byteSize = end - start2;
  if (byteSize === 8) {
    return view2.getFloat64(start2, !isBigEndian);
  } else if (byteSize === 4) {
    return view2.getFloat32(start2, !isBigEndian);
  } else {
    const msg = `Sized floats must be 32-bit or 64-bit on JavaScript, got size of ${byteSize * 8} bits`;
    throw new globalThis.Error(msg);
  }
}
var Result = class _Result extends CustomType {
  // @internal
  static isResult(data) {
    return data instanceof _Result;
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
function isEqual(x, y) {
  let values2 = [x, y];
  while (values2.length) {
    let a = values2.pop();
    let b = values2.pop();
    if (a === b)
      continue;
    if (!isObject(a) || !isObject(b))
      return false;
    let unequal = !structurallyCompatibleObjects(a, b) || unequalDates(a, b) || unequalBuffers(a, b) || unequalArrays(a, b) || unequalMaps(a, b) || unequalSets(a, b) || unequalRegExps(a, b);
    if (unequal)
      return false;
    const proto = Object.getPrototypeOf(a);
    if (proto !== null && typeof proto.equals === "function") {
      try {
        if (a.equals(b))
          continue;
        else
          return false;
      } catch {
      }
    }
    let [keys2, get] = getters(a);
    for (let k of keys2(a)) {
      values2.push(get(a, k), get(b, k));
    }
  }
  return true;
}
function getters(object3) {
  if (object3 instanceof Map) {
    return [(x) => x.keys(), (x, y) => x.get(y)];
  } else {
    let extra = object3 instanceof globalThis.Error ? ["message"] : [];
    return [(x) => [...extra, ...Object.keys(x)], (x, y) => x[y]];
  }
}
function unequalDates(a, b) {
  return a instanceof Date && (a > b || a < b);
}
function unequalBuffers(a, b) {
  return a.buffer instanceof ArrayBuffer && a.BYTES_PER_ELEMENT && !(a.byteLength === b.byteLength && a.every((n, i) => n === b[i]));
}
function unequalArrays(a, b) {
  return Array.isArray(a) && a.length !== b.length;
}
function unequalMaps(a, b) {
  return a instanceof Map && a.size !== b.size;
}
function unequalSets(a, b) {
  return a instanceof Set && (a.size != b.size || [...a].some((e) => !b.has(e)));
}
function unequalRegExps(a, b) {
  return a instanceof RegExp && (a.source !== b.source || a.flags !== b.flags);
}
function isObject(a) {
  return typeof a === "object" && a !== null;
}
function structurallyCompatibleObjects(a, b) {
  if (typeof a !== "object" && typeof b !== "object" && (!a || !b))
    return false;
  let nonstructural = [Promise, WeakSet, WeakMap, Function];
  if (nonstructural.some((c) => a instanceof c))
    return false;
  return a.constructor === b.constructor;
}
function remainderInt(a, b) {
  if (b === 0) {
    return 0;
  } else {
    return a % b;
  }
}
function divideInt(a, b) {
  return Math.trunc(divideFloat(a, b));
}
function divideFloat(a, b) {
  if (b === 0) {
    return 0;
  } else {
    return a / b;
  }
}
function makeError(variant, module, line, fn, message, extra) {
  let error = new globalThis.Error(message);
  error.gleam_error = variant;
  error.module = module;
  error.line = line;
  error.function = fn;
  error.fn = fn;
  for (let k in extra)
    error[k] = extra[k];
  return error;
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
    let a = option[0];
    return new Ok(a);
  } else {
    return new Error(e);
  }
}
function unwrap(option, default$) {
  if (option instanceof Some) {
    let x = option[0];
    return x;
  } else {
    return default$;
  }
}
function map(option, fun) {
  if (option instanceof Some) {
    let x = option[0];
    return new Some(fun(x));
  } else {
    return new None();
  }
}
function flatten(option) {
  if (option instanceof Some) {
    let x = option[0];
    return x;
  } else {
    return new None();
  }
}

// build/dev/javascript/gleam_stdlib/dict.mjs
var referenceMap = /* @__PURE__ */ new WeakMap();
var tempDataView = new DataView(new ArrayBuffer(8));
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
function hashMerge(a, b) {
  return a ^ b + 2654435769 + (a << 6) + (a >> 2) | 0;
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
      const code = o.hashCode(o);
      if (typeof code === "number") {
        return code;
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
function bitcount(x) {
  x -= x >> 1 & 1431655765;
  x = (x & 858993459) + (x >> 2 & 858993459);
  x = x + (x >> 4) & 252645135;
  x += x >> 8;
  x += x >> 16;
  return x & 127;
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
function assoc(root, shift, hash, key, val, addedLeaf) {
  switch (root.type) {
    case ARRAY_NODE:
      return assocArray(root, shift, hash, key, val, addedLeaf);
    case INDEX_NODE:
      return assocIndex(root, shift, hash, key, val, addedLeaf);
    case COLLISION_NODE:
      return assocCollision(root, shift, hash, key, val, addedLeaf);
  }
}
function assocArray(root, shift, hash, key, val, addedLeaf) {
  const idx = mask(hash, shift);
  const node = root.array[idx];
  if (node === void 0) {
    addedLeaf.val = true;
    return {
      type: ARRAY_NODE,
      size: root.size + 1,
      array: cloneAndSet(root.array, idx, { type: ENTRY, k: key, v: val })
    };
  }
  if (node.type === ENTRY) {
    if (isEqual(key, node.k)) {
      if (val === node.v) {
        return root;
      }
      return {
        type: ARRAY_NODE,
        size: root.size,
        array: cloneAndSet(root.array, idx, {
          type: ENTRY,
          k: key,
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
        createNode(shift + SHIFT, node.k, node.v, hash, key, val)
      )
    };
  }
  const n = assoc(node, shift + SHIFT, hash, key, val, addedLeaf);
  if (n === node) {
    return root;
  }
  return {
    type: ARRAY_NODE,
    size: root.size,
    array: cloneAndSet(root.array, idx, n)
  };
}
function assocIndex(root, shift, hash, key, val, addedLeaf) {
  const bit = bitpos(hash, shift);
  const idx = index(root.bitmap, bit);
  if ((root.bitmap & bit) !== 0) {
    const node = root.array[idx];
    if (node.type !== ENTRY) {
      const n = assoc(node, shift + SHIFT, hash, key, val, addedLeaf);
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
    if (isEqual(key, nodeKey)) {
      if (val === node.v) {
        return root;
      }
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap,
        array: cloneAndSet(root.array, idx, {
          type: ENTRY,
          k: key,
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
        createNode(shift + SHIFT, nodeKey, node.v, hash, key, val)
      )
    };
  } else {
    const n = root.array.length;
    if (n >= MAX_INDEX_NODE) {
      const nodes = new Array(32);
      const jdx = mask(hash, shift);
      nodes[jdx] = assocIndex(EMPTY, shift + SHIFT, hash, key, val, addedLeaf);
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
        k: key,
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
function assocCollision(root, shift, hash, key, val, addedLeaf) {
  if (hash === root.hash) {
    const idx = collisionIndexOf(root, key);
    if (idx !== -1) {
      const entry = root.array[idx];
      if (entry.v === val) {
        return root;
      }
      return {
        type: COLLISION_NODE,
        hash,
        array: cloneAndSet(root.array, idx, { type: ENTRY, k: key, v: val })
      };
    }
    const size = root.array.length;
    addedLeaf.val = true;
    return {
      type: COLLISION_NODE,
      hash,
      array: cloneAndSet(root.array, size, { type: ENTRY, k: key, v: val })
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
    key,
    val,
    addedLeaf
  );
}
function collisionIndexOf(root, key) {
  const size = root.array.length;
  for (let i = 0; i < size; i++) {
    if (isEqual(key, root.array[i].k)) {
      return i;
    }
  }
  return -1;
}
function find(root, shift, hash, key) {
  switch (root.type) {
    case ARRAY_NODE:
      return findArray(root, shift, hash, key);
    case INDEX_NODE:
      return findIndex(root, shift, hash, key);
    case COLLISION_NODE:
      return findCollision(root, key);
  }
}
function findArray(root, shift, hash, key) {
  const idx = mask(hash, shift);
  const node = root.array[idx];
  if (node === void 0) {
    return void 0;
  }
  if (node.type !== ENTRY) {
    return find(node, shift + SHIFT, hash, key);
  }
  if (isEqual(key, node.k)) {
    return node;
  }
  return void 0;
}
function findIndex(root, shift, hash, key) {
  const bit = bitpos(hash, shift);
  if ((root.bitmap & bit) === 0) {
    return void 0;
  }
  const idx = index(root.bitmap, bit);
  const node = root.array[idx];
  if (node.type !== ENTRY) {
    return find(node, shift + SHIFT, hash, key);
  }
  if (isEqual(key, node.k)) {
    return node;
  }
  return void 0;
}
function findCollision(root, key) {
  const idx = collisionIndexOf(root, key);
  if (idx < 0) {
    return void 0;
  }
  return root.array[idx];
}
function without(root, shift, hash, key) {
  switch (root.type) {
    case ARRAY_NODE:
      return withoutArray(root, shift, hash, key);
    case INDEX_NODE:
      return withoutIndex(root, shift, hash, key);
    case COLLISION_NODE:
      return withoutCollision(root, key);
  }
}
function withoutArray(root, shift, hash, key) {
  const idx = mask(hash, shift);
  const node = root.array[idx];
  if (node === void 0) {
    return root;
  }
  let n = void 0;
  if (node.type === ENTRY) {
    if (!isEqual(node.k, key)) {
      return root;
    }
  } else {
    n = without(node, shift + SHIFT, hash, key);
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
function withoutIndex(root, shift, hash, key) {
  const bit = bitpos(hash, shift);
  if ((root.bitmap & bit) === 0) {
    return root;
  }
  const idx = index(root.bitmap, bit);
  const node = root.array[idx];
  if (node.type !== ENTRY) {
    const n = without(node, shift + SHIFT, hash, key);
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
  if (isEqual(key, node.k)) {
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
function withoutCollision(root, key) {
  const idx = collisionIndexOf(root, key);
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
  get(key, notFound) {
    if (this.root === void 0) {
      return notFound;
    }
    const found = find(this.root, 0, getHash(key), key);
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
  set(key, val) {
    const addedLeaf = { val: false };
    const root = this.root === void 0 ? EMPTY : this.root;
    const newRoot = assoc(root, 0, getHash(key), key, val, addedLeaf);
    if (newRoot === this.root) {
      return this;
    }
    return new _Dict(newRoot, addedLeaf.val ? this.size + 1 : this.size);
  }
  /**
   * @param {K} key
   * @returns {Dict<K,V>}
   */
  delete(key) {
    if (this.root === void 0) {
      return this;
    }
    const newRoot = without(this.root, 0, getHash(key), key);
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
  has(key) {
    if (this.root === void 0) {
      return false;
    }
    return find(this.root, 0, getHash(key), key) !== void 0;
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
var unequalDictSymbol = Symbol();

// build/dev/javascript/gleam_stdlib/gleam_stdlib.mjs
var Nil = void 0;
var NOT_FOUND = {};
function identity(x) {
  return x;
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
function float_to_string(float4) {
  const string5 = float4.toString().replace("+", "");
  if (string5.indexOf(".") >= 0) {
    return string5;
  } else {
    const index4 = string5.indexOf("e");
    if (index4 >= 0) {
      return string5.slice(0, index4) + ".0" + string5.slice(index4);
    } else {
      return string5 + ".0";
    }
  }
}
function string_length(string5) {
  if (string5 === "") {
    return 0;
  }
  const iterator = graphemes_iterator(string5);
  if (iterator) {
    let i = 0;
    for (const _ of iterator) {
      i++;
    }
    return i;
  } else {
    return string5.match(/./gsu).length;
  }
}
var segmenter = void 0;
function graphemes_iterator(string5) {
  if (globalThis.Intl && Intl.Segmenter) {
    segmenter ||= new Intl.Segmenter();
    return segmenter.segment(string5)[Symbol.iterator]();
  }
}
function pop_grapheme(string5) {
  let first3;
  const iterator = graphemes_iterator(string5);
  if (iterator) {
    first3 = iterator.next().value?.segment;
  } else {
    first3 = string5.match(/./su)?.[0];
  }
  if (first3) {
    return new Ok([first3, string5.slice(first3.length)]);
  } else {
    return new Error(Nil);
  }
}
function concat(xs) {
  let result = "";
  for (const x of xs) {
    result = result + x;
  }
  return result;
}
function string_slice(string5, idx, len) {
  if (len <= 0 || idx >= string5.length) {
    return "";
  }
  const iterator = graphemes_iterator(string5);
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
    return string5.match(/./gsu).slice(idx, idx + len).join("");
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
var trim_start_regex = new RegExp(`^[${unicode_whitespaces}]*`);
var trim_end_regex = new RegExp(`[${unicode_whitespaces}]*$`);
function console_log(term) {
  console.log(term);
}
function floor(float4) {
  return Math.floor(float4);
}
function round(float4) {
  return Math.round(float4);
}
function random_uniform() {
  const random_uniform_result = Math.random();
  if (random_uniform_result === 1) {
    return random_uniform();
  }
  return random_uniform_result;
}
function new_map() {
  return Dict.new();
}
function map_to_list(map6) {
  return List.fromArray(map6.entries());
}
function map_remove(key, map6) {
  return map6.delete(key);
}
function map_get(map6, key) {
  const value3 = map6.get(key, NOT_FOUND);
  if (value3 === NOT_FOUND) {
    return new Error(Nil);
  }
  return new Ok(value3);
}
function map_insert(key, value3, map6) {
  return map6.set(key, value3);
}
function classify_dynamic(data) {
  if (typeof data === "string") {
    return "String";
  } else if (typeof data === "boolean") {
    return "Bool";
  } else if (data instanceof Result) {
    return "Result";
  } else if (data instanceof List) {
    return "List";
  } else if (data instanceof BitArray) {
    return "BitArray";
  } else if (data instanceof Dict) {
    return "Dict";
  } else if (Number.isInteger(data)) {
    return "Int";
  } else if (Array.isArray(data)) {
    return `Tuple of ${data.length} elements`;
  } else if (typeof data === "number") {
    return "Float";
  } else if (data === null) {
    return "Null";
  } else if (data === void 0) {
    return "Nil";
  } else {
    const type = typeof data;
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
function decode_string(data) {
  return typeof data === "string" ? new Ok(data) : decoder_error("String", data);
}
function decode_int(data) {
  return Number.isInteger(data) ? new Ok(data) : decoder_error("Int", data);
}
function decode_field(value3, name2) {
  const not_a_map_error = () => decoder_error("Dict", value3);
  if (value3 instanceof Dict || value3 instanceof WeakMap || value3 instanceof Map) {
    const entry = map_get(value3, name2);
    return new Ok(entry.isOk() ? new Some(entry[0]) : new None());
  } else if (value3 === null) {
    return not_a_map_error();
  } else if (Object.getPrototypeOf(value3) == Object.prototype) {
    return try_get_field(value3, name2, () => new Ok(new None()));
  } else {
    return try_get_field(value3, name2, not_a_map_error);
  }
}
function try_get_field(value3, field3, or_else) {
  try {
    return field3 in value3 ? new Ok(new Some(value3[field3])) : or_else();
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
    return inspectBitArray(v);
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
    let char = str[i];
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
function inspectDict(map6) {
  let body = "dict.from_list([";
  let first3 = true;
  map6.forEach((value3, key) => {
    if (!first3)
      body = body + ", ";
    body = body + "#(" + inspect(key) + ", " + inspect(value3) + ")";
    first3 = false;
  });
  return body + "])";
}
function inspectObject(v) {
  const name2 = Object.getPrototypeOf(v)?.constructor?.name || "Object";
  const props = [];
  for (const k of Object.keys(v)) {
    props.push(`${inspect(k)}: ${inspect(v[k])}`);
  }
  const body = props.length ? " " + props.join(", ") + " " : "";
  const head = name2 === "Object" ? "" : name2 + " ";
  return `//js(${head}{${body}})`;
}
function inspectCustomType(record) {
  const props = Object.keys(record).map((label) => {
    const value3 = inspect(record[label]);
    return isNaN(parseInt(label)) ? `${label}: ${value3}` : value3;
  }).join(", ");
  return props ? `${record.constructor.name}(${props})` : record.constructor.name;
}
function inspectList(list3) {
  return `[${list3.toArray().map(inspect).join(", ")}]`;
}
function inspectBitArray(bits) {
  return `<<${Array.from(bits.buffer).join(", ")}>>`;
}
function inspectUtfCodepoint(codepoint2) {
  return `//utfcodepoint(${String.fromCodePoint(codepoint2.value)})`;
}

// build/dev/javascript/gleam_stdlib/gleam/float.mjs
function negate(x) {
  return -1 * x;
}
function round2(x) {
  let $ = x >= 0;
  if ($) {
    return round(x);
  } else {
    return 0 - round(negate(x));
  }
}

// build/dev/javascript/gleam_stdlib/gleam/int.mjs
function random(max) {
  let _pipe = random_uniform() * identity(max);
  let _pipe$1 = floor(_pipe);
  return round2(_pipe$1);
}

// build/dev/javascript/gleam_stdlib/gleam/dict.mjs
function insert(dict2, key, value3) {
  return map_insert(key, value3, dict2);
}
function from_list_loop(loop$list, loop$initial) {
  while (true) {
    let list3 = loop$list;
    let initial = loop$initial;
    if (list3.hasLength(0)) {
      return initial;
    } else {
      let key = list3.head[0];
      let value3 = list3.head[1];
      let rest = list3.tail;
      loop$list = rest;
      loop$initial = insert(initial, key, value3);
    }
  }
}
function from_list(list3) {
  return from_list_loop(list3, new_map());
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
    let list3 = loop$list;
    let acc = loop$acc;
    if (list3.hasLength(0)) {
      return reverse_and_concat(acc, toList([]));
    } else {
      let key = list3.head[0];
      let rest = list3.tail;
      loop$list = rest;
      loop$acc = prepend(key, acc);
    }
  }
}
function keys(dict2) {
  return do_keys_loop(map_to_list(dict2), toList([]));
}
function delete$(dict2, key) {
  return map_remove(key, dict2);
}

// build/dev/javascript/gleam_stdlib/gleam/list.mjs
function length_loop(loop$list, loop$count) {
  while (true) {
    let list3 = loop$list;
    let count = loop$count;
    if (list3.atLeastLength(1)) {
      let list$1 = list3.tail;
      loop$list = list$1;
      loop$count = count + 1;
    } else {
      return count;
    }
  }
}
function length(list3) {
  return length_loop(list3, 0);
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
function reverse(list3) {
  return reverse_and_prepend(list3, toList([]));
}
function first(list3) {
  if (list3.hasLength(0)) {
    return new Error(void 0);
  } else {
    let first$1 = list3.head;
    return new Ok(first$1);
  }
}
function map_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list3 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list3.hasLength(0)) {
      return reverse(acc);
    } else {
      let first$1 = list3.head;
      let rest$1 = list3.tail;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = prepend(fun(first$1), acc);
    }
  }
}
function map2(list3, fun) {
  return map_loop(list3, fun, toList([]));
}
function append_loop(loop$first, loop$second) {
  while (true) {
    let first3 = loop$first;
    let second = loop$second;
    if (first3.hasLength(0)) {
      return second;
    } else {
      let first$1 = first3.head;
      let rest$1 = first3.tail;
      loop$first = rest$1;
      loop$second = prepend(first$1, second);
    }
  }
}
function append(first3, second) {
  return append_loop(reverse(first3), second);
}
function fold(loop$list, loop$initial, loop$fun) {
  while (true) {
    let list3 = loop$list;
    let initial = loop$initial;
    let fun = loop$fun;
    if (list3.hasLength(0)) {
      return initial;
    } else {
      let first$1 = list3.head;
      let rest$1 = list3.tail;
      loop$list = rest$1;
      loop$initial = fun(initial, first$1);
      loop$fun = fun;
    }
  }
}
function index_fold_loop(loop$over, loop$acc, loop$with, loop$index) {
  while (true) {
    let over = loop$over;
    let acc = loop$acc;
    let with$ = loop$with;
    let index4 = loop$index;
    if (over.hasLength(0)) {
      return acc;
    } else {
      let first$1 = over.head;
      let rest$1 = over.tail;
      loop$over = rest$1;
      loop$acc = with$(acc, first$1, index4);
      loop$with = with$;
      loop$index = index4 + 1;
    }
  }
}
function index_fold(list3, initial, fun) {
  return index_fold_loop(list3, initial, fun, 0);
}
function find2(loop$list, loop$is_desired) {
  while (true) {
    let list3 = loop$list;
    let is_desired = loop$is_desired;
    if (list3.hasLength(0)) {
      return new Error(void 0);
    } else {
      let first$1 = list3.head;
      let rest$1 = list3.tail;
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
function find_map(loop$list, loop$fun) {
  while (true) {
    let list3 = loop$list;
    let fun = loop$fun;
    if (list3.hasLength(0)) {
      return new Error(void 0);
    } else {
      let first$1 = list3.head;
      let rest$1 = list3.tail;
      let $ = fun(first$1);
      if ($.isOk()) {
        let first$2 = $[0];
        return new Ok(first$2);
      } else {
        loop$list = rest$1;
        loop$fun = fun;
      }
    }
  }
}

// build/dev/javascript/gleam_stdlib/gleam/string.mjs
function slice(string5, idx, len) {
  let $ = len < 0;
  if ($) {
    return "";
  } else {
    let $1 = idx < 0;
    if ($1) {
      let translated_idx = string_length(string5) + idx;
      let $2 = translated_idx < 0;
      if ($2) {
        return "";
      } else {
        return string_slice(string5, translated_idx, len);
      }
    } else {
      return string_slice(string5, idx, len);
    }
  }
}
function drop_start(loop$string, loop$num_graphemes) {
  while (true) {
    let string5 = loop$string;
    let num_graphemes = loop$num_graphemes;
    let $ = num_graphemes > 0;
    if (!$) {
      return string5;
    } else {
      let $1 = pop_grapheme(string5);
      if ($1.isOk()) {
        let string$1 = $1[0][1];
        loop$string = string$1;
        loop$num_graphemes = num_graphemes - 1;
      } else {
        return string5;
      }
    }
  }
}
function inspect2(term) {
  let _pipe = inspect(term);
  return identity(_pipe);
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
    let x = result[0];
    return new Ok(fun(x));
  } else {
    let e = result[0];
    return new Error(e);
  }
}
function map_error(result, fun) {
  if (result.isOk()) {
    let x = result[0];
    return new Ok(x);
  } else {
    let error = result[0];
    return new Error(fun(error));
  }
}
function try$(result, fun) {
  if (result.isOk()) {
    let x = result[0];
    return fun(x);
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
function replace_error(result, error) {
  if (result.isOk()) {
    let x = result[0];
    return new Ok(x);
  } else {
    return new Error(error);
  }
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
function string(data) {
  return decode_string(data);
}
function do_any(decoders) {
  return (data) => {
    if (decoders.hasLength(0)) {
      return new Error(
        toList([new DecodeError("another type", classify_dynamic(data), toList([]))])
      );
    } else {
      let decoder = decoders.head;
      let decoders$1 = decoders.tail;
      let $ = decoder(data);
      if ($.isOk()) {
        let decoded = $[0];
        return new Ok(decoded);
      } else {
        return do_any(decoders$1)(data);
      }
    }
  };
}
function push_path(error, name2) {
  let name$1 = identity(name2);
  let decoder = do_any(
    toList([
      decode_string,
      (x) => {
        return map3(decode_int(x), to_string);
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
  let _record = error;
  return new DecodeError(
    _record.expected,
    _record.found,
    prepend(name$2, error.path)
  );
}
function field(name2, inner_type) {
  return (value3) => {
    let missing_field_error = new DecodeError("field", "nothing", toList([]));
    return try$(
      decode_field(value3, name2),
      (maybe_inner) => {
        let _pipe = maybe_inner;
        let _pipe$1 = to_result(_pipe, toList([missing_field_error]));
        let _pipe$2 = try$(_pipe$1, inner_type);
        return map_errors(
          _pipe$2,
          (_capture) => {
            return push_path(_capture, name2);
          }
        );
      }
    );
  };
}

// build/dev/javascript/gleam_stdlib/gleam_stdlib_decode_ffi.mjs
function index2(data, key) {
  const int4 = Number.isInteger(key);
  if (data instanceof Dict || data instanceof WeakMap || data instanceof Map) {
    const token2 = {};
    const entry = data.get(key, token2);
    if (entry === token2)
      return new Ok(new None());
    return new Ok(new Some(entry));
  }
  if ((key === 0 || key === 1 || key === 2) && data instanceof List) {
    let i = 0;
    for (const value3 of data) {
      if (i === key)
        return new Ok(new Some(value3));
      i++;
    }
    return new Error("Indexable");
  }
  if (int4 && Array.isArray(data) || data && typeof data === "object" || data && Object.getPrototypeOf(data) === Object.prototype) {
    if (key in data)
      return new Ok(new Some(data[key]));
    return new Ok(new None());
  }
  return new Error(int4 ? "Indexable" : "Dict");
}
function list(data, decode2, pushPath, index4, emptyList) {
  if (!(data instanceof List || Array.isArray(data))) {
    let error = new DecodeError2("List", classify_dynamic(data), emptyList);
    return [emptyList, List.fromArray([error])];
  }
  const decoded = [];
  for (const element2 of data) {
    const layer = decode2(element2);
    const [out, errors] = layer;
    if (errors instanceof NonEmpty) {
      const [_, errors2] = pushPath(layer, index4.toString());
      return [emptyList, errors2];
    }
    decoded.push(out);
    index4++;
  }
  return [List.fromArray(decoded), emptyList];
}
function int(data) {
  if (Number.isInteger(data))
    return new Ok(data);
  return new Error(0);
}
function string2(data) {
  if (typeof data === "string")
    return new Ok(data);
  return new Error(0);
}
function is_null(data) {
  return data === null || data === void 0;
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
function run(data, decoder) {
  let $ = decoder.function(data);
  let maybe_invalid_data = $[0];
  let errors = $[1];
  if (errors.hasLength(0)) {
    return new Ok(maybe_invalid_data);
  } else {
    return new Error(errors);
  }
}
function success(data) {
  return new Decoder((_) => {
    return [data, toList([])];
  });
}
function map4(decoder, transformer) {
  return new Decoder(
    (d) => {
      let $ = decoder.function(d);
      let data = $[0];
      let errors = $[1];
      return [transformer(data), errors];
    }
  );
}
function run_decoders(loop$data, loop$failure, loop$decoders) {
  while (true) {
    let data = loop$data;
    let failure = loop$failure;
    let decoders = loop$decoders;
    if (decoders.hasLength(0)) {
      return failure;
    } else {
      let decoder = decoders.head;
      let decoders$1 = decoders.tail;
      let $ = decoder.function(data);
      let layer = $;
      let errors = $[1];
      if (errors.hasLength(0)) {
        return layer;
      } else {
        loop$data = data;
        loop$failure = failure;
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
    (data) => {
      let $ = is_null(data);
      if ($) {
        return [new None(), toList([])];
      } else {
        let $1 = inner.function(data);
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
function run_dynamic_function(data, name2, f) {
  let $ = f(data);
  if ($.isOk()) {
    let data$1 = $[0];
    return [data$1, toList([])];
  } else {
    let zero = $[0];
    return [
      zero,
      toList([new DecodeError2(name2, classify_dynamic(data), toList([]))])
    ];
  }
}
function decode_bool2(data) {
  let $ = isEqual(identity(true), data);
  if ($) {
    return [true, toList([])];
  } else {
    let $1 = isEqual(identity(false), data);
    if ($1) {
      return [false, toList([])];
    } else {
      return [false, decode_error("Bool", data)];
    }
  }
}
function decode_int2(data) {
  return run_dynamic_function(data, "Int", int);
}
var bool = /* @__PURE__ */ new Decoder(decode_bool2);
var int2 = /* @__PURE__ */ new Decoder(decode_int2);
function decode_string2(data) {
  return run_dynamic_function(data, "String", string2);
}
var string3 = /* @__PURE__ */ new Decoder(decode_string2);
function list2(inner) {
  return new Decoder(
    (data) => {
      return list(
        data,
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
    (key) => {
      let key$1 = identity(key);
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
    (error) => {
      let _record = error;
      return new DecodeError2(
        _record.expected,
        _record.found,
        append(path$1, error.path)
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
    let data = loop$data;
    let handle_miss = loop$handle_miss;
    if (path2.hasLength(0)) {
      let _pipe = inner(data);
      return push_path2(_pipe, reverse(position));
    } else {
      let key = path2.head;
      let path$1 = path2.tail;
      let $ = index2(data, key);
      if ($.isOk() && $[0] instanceof Some) {
        let data$1 = $[0][0];
        loop$path = path$1;
        loop$position = prepend(key, position);
        loop$inner = inner;
        loop$data = data$1;
        loop$handle_miss = handle_miss;
      } else if ($.isOk() && $[0] instanceof None) {
        return handle_miss(data, prepend(key, position));
      } else {
        let kind = $[0];
        let $1 = inner(data);
        let default$ = $1[0];
        let _pipe = [
          default$,
          toList([new DecodeError2(kind, classify_dynamic(data), toList([]))])
        ];
        return push_path2(_pipe, reverse(position));
      }
    }
  }
}
function subfield(field_path, field_decoder, next) {
  return new Decoder(
    (data) => {
      let $ = index3(
        field_path,
        toList([]),
        field_decoder.function,
        data,
        (data2, position) => {
          let $12 = field_decoder.function(data2);
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
      let $1 = next(out).function(data);
      let out$1 = $1[0];
      let errors2 = $1[1];
      return [out$1, append(errors1, errors2)];
    }
  );
}
function field2(field_name, field_decoder, next) {
  return subfield(toList([field_name]), field_decoder, next);
}

// build/dev/javascript/gleam_stdlib/gleam/bool.mjs
function lazy_guard(requirement, consequence, alternative) {
  if (requirement) {
    return consequence();
  } else {
    return alternative();
  }
}

// build/dev/javascript/gleam_json/gleam_json_ffi.mjs
function object(entries) {
  return Object.fromEntries(entries);
}
function identity2(x) {
  return x;
}
function do_null() {
  return null;
}
function decode(string5) {
  try {
    const result = JSON.parse(string5);
    return new Ok(result);
  } catch (err) {
    return new Error(getJsonDecodeError(err, string5));
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
  const line = Number(match[2]);
  const column = Number(match[3]);
  const position = getPositionFromMultiline(line, column, json);
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
function getPositionFromMultiline(line, column, string5) {
  if (line === 1)
    return column - 1;
  let currentLn = 1;
  let position = 0;
  string5.split("").find((char, idx) => {
    if (char === "\n")
      currentLn += 1;
    if (currentLn === line) {
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
function string4(input2) {
  return identity2(input2);
}
function bool2(input2) {
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
function event(name2, data) {
  return custom((_, emit3, _1, _2) => {
    return emit3(name2, data);
  });
}
function none() {
  return new Effect(toList([]));
}

// build/dev/javascript/lustre/lustre/internals/vdom.mjs
var Text = class extends CustomType {
  constructor(content) {
    super();
    this.content = content;
  }
};
var Element = class extends CustomType {
  constructor(key, namespace2, tag, attrs, children2, self_closing, void$) {
    super();
    this.key = key;
    this.namespace = namespace2;
    this.tag = tag;
    this.attrs = attrs;
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
var Event = class extends CustomType {
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
    let name2 = attribute2[0];
    let handler = attribute2[1];
    let name$1 = drop_start(name2, 2);
    return new Ok([name$1, handler]);
  }
}
function do_element_list_handlers(elements2, handlers2, key) {
  return index_fold(
    elements2,
    handlers2,
    (handlers3, element2, index4) => {
      let key$1 = key + "-" + to_string(index4);
      return do_handlers(element2, handlers3, key$1);
    }
  );
}
function do_handlers(loop$element, loop$handlers, loop$key) {
  while (true) {
    let element2 = loop$element;
    let handlers2 = loop$handlers;
    let key = loop$key;
    if (element2 instanceof Text) {
      return handlers2;
    } else if (element2 instanceof Map2) {
      let subtree = element2.subtree;
      loop$element = subtree();
      loop$handlers = handlers2;
      loop$key = key;
    } else {
      let attrs = element2.attrs;
      let children2 = element2.children;
      let handlers$1 = fold(
        attrs,
        handlers2,
        (handlers3, attr) => {
          let $ = attribute_to_event_handler(attr);
          if ($.isOk()) {
            let name2 = $[0][0];
            let handler = $[0][1];
            return insert(handlers3, key + "-" + name2, handler);
          } else {
            return handlers3;
          }
        }
      );
      return do_element_list_handlers(children2, handlers$1, key);
    }
  }
}
function handlers(element2) {
  return do_handlers(element2, new_map(), "0");
}

// build/dev/javascript/lustre/lustre/attribute.mjs
function attribute(name2, value3) {
  return new Attribute(name2, identity(value3), false);
}
function on(name2, handler) {
  return new Event("on" + name2, handler);
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
function class$(name2) {
  return attribute("class", name2);
}
function id(name2) {
  return attribute("id", name2);
}
function value(val) {
  return attribute("value", val);
}
function placeholder(text3) {
  return attribute("placeholder", text3);
}

// build/dev/javascript/lustre/lustre/element.mjs
function element(tag, attrs, children2) {
  if (tag === "area") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "base") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "br") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "col") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "embed") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "hr") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "img") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "input") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "link") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "meta") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "param") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "source") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "track") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "wbr") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else {
    return new Element("", "", tag, attrs, children2, false, false);
  }
}
function namespaced(namespace2, tag, attrs, children2) {
  return new Element("", namespace2, tag, attrs, children2, false, false);
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
function contains(set, member) {
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
var Event2 = class extends CustomType {
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

// build/dev/javascript/lustre/lustre.mjs
var App = class extends CustomType {
  constructor(init3, update2, view2, on_attribute_change) {
    super();
    this.init = init3;
    this.update = update2;
    this.view = view2;
    this.on_attribute_change = on_attribute_change;
  }
};
var BadComponentName = class extends CustomType {
  constructor(name2) {
    super();
    this.name = name2;
  }
};
var ComponentAlreadyRegistered = class extends CustomType {
  constructor(name2) {
    super();
    this.name = name2;
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
function component(init3, update2, view2, on_attribute_change) {
  return new App(init3, update2, view2, new Some(on_attribute_change));
}

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
  const prevAttributes = canMorph ? new Set(Array.from(prev.attributes, (a) => a.name)) : null;
  let className = null;
  let style3 = null;
  let innerHTML = null;
  if (canMorph && next.tag === "textarea") {
    const innertText = next.children[Symbol.iterator]().next().value?.content;
    if (innertText !== void 0)
      el.value = innertText;
  }
  const delegated = [];
  for (const attr of next.attrs) {
    const name2 = attr[0];
    const value3 = attr[1];
    if (attr.as_property) {
      if (el[name2] !== value3)
        el[name2] = value3;
      if (canMorph)
        prevAttributes.delete(name2);
    } else if (name2.startsWith("on")) {
      const eventName = name2.slice(2);
      const callback = dispatch(value3, eventName === "input");
      if (!handlersForEl.has(eventName)) {
        el.addEventListener(eventName, lustreGenericEventHandler);
      }
      handlersForEl.set(eventName, callback);
      if (canMorph)
        prevHandlers.delete(eventName);
    } else if (name2.startsWith("data-lustre-on-")) {
      const eventName = name2.slice(15);
      const callback = dispatch(lustreServerEventHandler);
      if (!handlersForEl.has(eventName)) {
        el.addEventListener(eventName, lustreGenericEventHandler);
      }
      handlersForEl.set(eventName, callback);
      el.setAttribute(name2, value3);
      if (canMorph) {
        prevHandlers.delete(eventName);
        prevAttributes.delete(name2);
      }
    } else if (name2.startsWith("delegate:data-") || name2.startsWith("delegate:aria-")) {
      el.setAttribute(name2, value3);
      delegated.push([name2.slice(10), value3]);
    } else if (name2 === "class") {
      className = className === null ? value3 : className + " " + value3;
    } else if (name2 === "style") {
      style3 = style3 === null ? value3 : style3 + value3;
    } else if (name2 === "dangerous-unescaped-html") {
      innerHTML = value3;
    } else {
      if (el.getAttribute(name2) !== value3)
        el.setAttribute(name2, value3);
      if (name2 === "value" || name2 === "selected")
        el[name2] = value3;
      if (canMorph)
        prevAttributes.delete(name2);
    }
  }
  if (className !== null) {
    el.setAttribute("class", className);
    if (canMorph)
      prevAttributes.delete("class");
  }
  if (style3 !== null) {
    el.setAttribute("style", style3);
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
        for (const [name2, value3] of delegated) {
          if (!child.hasAttribute(name2)) {
            child.setAttribute(name2, value3);
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
function lustreGenericEventHandler(event2) {
  const target = event2.currentTarget;
  if (!registeredHandlers.has(target)) {
    target.removeEventListener(event2.type, lustreGenericEventHandler);
    return;
  }
  const handlersForEventTarget = registeredHandlers.get(target);
  if (!handlersForEventTarget.has(event2.type)) {
    target.removeEventListener(event2.type, lustreGenericEventHandler);
    return;
  }
  handlersForEventTarget.get(event2.type)(event2);
}
function lustreServerEventHandler(event2) {
  const el = event2.currentTarget;
  const tag = el.getAttribute(`data-lustre-on-${event2.type}`);
  const data = JSON.parse(el.getAttribute("data-lustre-data") || "{}");
  const include = JSON.parse(el.getAttribute("data-lustre-include") || "[]");
  switch (event2.type) {
    case "input":
    case "change":
      include.push("target.value");
      break;
  }
  return {
    tag,
    data: include.reduce(
      (data2, property) => {
        const path2 = property.split(".");
        for (let i = 0, o = data2, e = event2; i < path2.length; i++) {
          if (i === path2.length - 1) {
            o[path2[i]] = e[path2[i]];
          } else {
            o[path2[i]] ??= {};
            e = e[path2[i]];
            o = o[path2[i]];
          }
        }
        return data2;
      },
      { data }
    )
  };
}
function getKeyedChildren(el) {
  const keyedChildren = /* @__PURE__ */ new Map();
  if (el) {
    for (const child of children(el)) {
      const key = child?.key || child?.getAttribute?.("data-lustre-key");
      if (key)
        keyedChildren.set(key, child);
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
  static start({ init: init3, update: update2, view: view2 }, selector, flags) {
    if (!is_browser())
      return new Error(new NotABrowser());
    const root = selector instanceof HTMLElement ? selector : document.querySelector(selector);
    if (!root)
      return new Error(new ElementNotFound(selector));
    const app = new _LustreClientApplication(root, init3(flags), update2, view2);
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
  constructor(root, [init3, effects], update2, view2) {
    this.root = root;
    this.#model = init3;
    this.#update = update2;
    this.#view = view2;
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
        const dispatch = (handler, immediate = false) => (event2) => {
          const result = handler(event2);
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
      const event2 = action[0];
      const data = action[1];
      this.root.dispatchEvent(
        new CustomEvent(event2, {
          detail: data,
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
    const dispatch = (handler, immediate = false) => (event2) => {
      const result = handler(event2);
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
      const emit3 = (event2, data) => this.root.dispatchEvent(
        new CustomEvent(event2, {
          detail: data,
          bubbles: true,
          composed: true
        })
      );
      const select = () => {
      };
      const root = this.root;
      effect({ dispatch, emit: emit3, select, root });
    }
    if (this.#queue.length > 0) {
      this.#flush(effects);
    }
  }
};
var start = LustreClientApplication.start;
var make_lustre_client_component = ({ init: init3, update: update2, view: view2, on_attribute_change }, name2) => {
  if (!is_browser())
    return new Error(new NotABrowser());
  if (!name2.includes("-"))
    return new Error(new BadComponentName(name2));
  if (window.customElements.get(name2)) {
    return new Error(new ComponentAlreadyRegistered(name2));
  }
  const [model, effects] = init3(void 0);
  const hasAttributes = on_attribute_change instanceof Some;
  const component3 = class LustreClientComponent extends HTMLElement {
    /**
     * @returns {string[]}
     */
    static get observedAttributes() {
      if (hasAttributes) {
        return on_attribute_change[0].entries().map(([name3]) => name3);
      } else {
        return [];
      }
    }
    /**
     * @returns {LustreClientComponent}
     */
    constructor() {
      super();
      this.attachShadow({ mode: "open" });
      this.internals = this.attachInternals();
      if (hasAttributes) {
        on_attribute_change[0].forEach((decoder, name3) => {
          const key = `__mirrored__${name3}`;
          Object.defineProperty(this, name3, {
            get() {
              return this[key];
            },
            set(value3) {
              const prev = this[key];
              if (this.#connected && isEqual(prev, value3))
                return;
              this[key] = value3;
              const decoded = decoder(value3);
              if (decoded instanceof Error)
                return;
              this.#queue.push(decoded[0]);
              if (this.#connected && !this.#tickScheduled) {
                this.#tickScheduled = window.requestAnimationFrame(
                  () => this.#tick()
                );
              }
            }
          });
        });
      }
    }
    /**
     *
     */
    connectedCallback() {
      this.#adoptStyleSheets().finally(() => {
        this.#tick(effects.all.toArray(), true);
        this.#connected = true;
      });
    }
    /**
     * @param {string} key
     * @param {string} prev
     * @param {string} next
     */
    attributeChangedCallback(key, prev, next) {
      if (prev !== next)
        this[key] = next;
    }
    /**
     *
     */
    disconnectedCallback() {
      this.#model = null;
      this.#queue = [];
      this.#tickScheduled = window.cancelAnimationFrame(this.#tickScheduled);
      this.#connected = false;
    }
    /**
     * @param {Lustre.Action<Msg, Lustre.ClientSpa>} action
     */
    send(action) {
      if (action instanceof Debug) {
        if (action[0] instanceof ForceModel) {
          this.#tickScheduled = window.cancelAnimationFrame(
            this.#tickScheduled
          );
          this.#queue = [];
          this.#model = action[0][0];
          const vdom = view2(this.#model);
          const dispatch = (handler, immediate = false) => (event2) => {
            const result = handler(event2);
            if (result instanceof Ok) {
              this.send(new Dispatch(result[0], immediate));
            }
          };
          const prev = this.shadowRoot.childNodes[this.#adoptedStyleElements.length] ?? this.shadowRoot.appendChild(document.createTextNode(""));
          morph(prev, vdom, dispatch);
        }
      } else if (action instanceof Dispatch) {
        const msg = action[0];
        const immediate = action[1] ?? false;
        this.#queue.push(msg);
        if (immediate) {
          this.#tickScheduled = window.cancelAnimationFrame(
            this.#tickScheduled
          );
          this.#tick();
        } else if (!this.#tickScheduled) {
          this.#tickScheduled = window.requestAnimationFrame(
            () => this.#tick()
          );
        }
      } else if (action instanceof Emit2) {
        const event2 = action[0];
        const data = action[1];
        this.dispatchEvent(
          new CustomEvent(event2, {
            detail: data,
            bubbles: true,
            composed: true
          })
        );
      }
    }
    /** @type {Element[]} */
    #adoptedStyleElements = [];
    /** @type {Model} */
    #model = model;
    /** @type {Array<Msg>} */
    #queue = [];
    /** @type {number | undefined} */
    #tickScheduled;
    /** @type {boolean} */
    #connected = true;
    #tick(effects2 = []) {
      if (!this.#connected)
        return;
      this.#tickScheduled = void 0;
      this.#flush(effects2);
      const vdom = view2(this.#model);
      const dispatch = (handler, immediate = false) => (event2) => {
        const result = handler(event2);
        if (result instanceof Ok) {
          this.send(new Dispatch(result[0], immediate));
        }
      };
      const prev = this.shadowRoot.childNodes[this.#adoptedStyleElements.length] ?? this.shadowRoot.appendChild(document.createTextNode(""));
      morph(prev, vdom, dispatch);
    }
    #flush(effects2 = []) {
      while (this.#queue.length > 0) {
        const msg = this.#queue.shift();
        const [next, effect] = update2(this.#model, msg);
        effects2 = effects2.concat(effect.all.toArray());
        this.#model = next;
      }
      while (effects2.length > 0) {
        const effect = effects2.shift();
        const dispatch = (msg) => this.send(new Dispatch(msg));
        const emit3 = (event2, data) => this.dispatchEvent(
          new CustomEvent(event2, {
            detail: data,
            bubbles: true,
            composed: true
          })
        );
        const select = () => {
        };
        const root = this.shadowRoot;
        effect({ dispatch, emit: emit3, select, root });
      }
      if (this.#queue.length > 0) {
        this.#flush(effects2);
      }
    }
    async #adoptStyleSheets() {
      const pendingParentStylesheets = [];
      for (const link of document.querySelectorAll("link[rel=stylesheet]")) {
        if (link.sheet)
          continue;
        pendingParentStylesheets.push(
          new Promise((resolve, reject) => {
            link.addEventListener("load", resolve);
            link.addEventListener("error", reject);
          })
        );
      }
      await Promise.allSettled(pendingParentStylesheets);
      while (this.#adoptedStyleElements.length) {
        this.#adoptedStyleElements.shift().remove();
        this.shadowRoot.firstChild.remove();
      }
      this.shadowRoot.adoptedStyleSheets = this.getRootNode().adoptedStyleSheets;
      const pending = [];
      for (const sheet of document.styleSheets) {
        try {
          this.shadowRoot.adoptedStyleSheets.push(sheet);
        } catch {
          try {
            const adoptedSheet = new CSSStyleSheet();
            for (const rule of sheet.cssRules) {
              adoptedSheet.insertRule(
                rule.cssText,
                adoptedSheet.cssRules.length
              );
            }
            this.shadowRoot.adoptedStyleSheets.push(adoptedSheet);
          } catch {
            const node = sheet.ownerNode.cloneNode();
            this.shadowRoot.prepend(node);
            this.#adoptedStyleElements.push(node);
            pending.push(
              new Promise((resolve, reject) => {
                node.onload = resolve;
                node.onerror = reject;
              })
            );
          }
        }
      }
      return Promise.allSettled(pending);
    }
  };
  window.customElements.define(name2, component3);
  return new Ok(void 0);
};
var LustreServerApplication = class _LustreServerApplication {
  static start({ init: init3, update: update2, view: view2, on_attribute_change }, flags) {
    const app = new _LustreServerApplication(
      init3(flags),
      update2,
      view2,
      on_attribute_change
    );
    return new Ok((action) => app.send(action));
  }
  constructor([model, effects], update2, view2, on_attribute_change) {
    this.#model = model;
    this.#update = update2;
    this.#view = view2;
    this.#html = view2(model);
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
      const event2 = new Emit(action[0], action[1]);
      for (const [_, renderer] of this.#renderers) {
        renderer(event2);
      }
    } else if (action instanceof Event2) {
      const handler = this.#handlers.get(action[0]);
      if (!handler)
        return;
      const msg = handler(action[1]);
      if (msg instanceof Error)
        return;
      this.#queue.push(msg[0]);
      this.#tick();
    } else if (action instanceof Subscribe) {
      const attrs = keys(this.#onAttributeChange);
      const patch = new Init(attrs, this.#html);
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
      const emit3 = (event2, data) => this.root.dispatchEvent(
        new CustomEvent(event2, {
          detail: data,
          bubbles: true,
          composed: true
        })
      );
      const select = () => {
      };
      const root = null;
      effect({ dispatch, emit: emit3, select, root });
    }
    if (this.#queue.length > 0) {
      this.#flush(effects);
    }
  }
};
var start_server_application = LustreServerApplication.start;
var is_browser = () => globalThis.window && window.document;

// build/dev/javascript/given/given.mjs
function that(requirement, consequence, alternative) {
  if (requirement) {
    return consequence();
  } else {
    return alternative();
  }
}

// build/dev/javascript/gleam_time/gleam/time/duration.mjs
var Duration = class extends CustomType {
  constructor(seconds3, nanoseconds2) {
    super();
    this.seconds = seconds3;
    this.nanoseconds = nanoseconds2;
  }
};
function normalise(duration) {
  let multiplier = 1e9;
  let nanoseconds$1 = remainderInt(duration.nanoseconds, multiplier);
  let overflow = duration.nanoseconds - nanoseconds$1;
  let seconds$1 = duration.seconds + divideInt(overflow, multiplier);
  let $ = nanoseconds$1 >= 0;
  if ($) {
    return new Duration(seconds$1, nanoseconds$1);
  } else {
    return new Duration(seconds$1 - 1, multiplier + nanoseconds$1);
  }
}
function difference(left, right) {
  let _pipe = new Duration(
    right.seconds - left.seconds,
    right.nanoseconds - left.nanoseconds
  );
  return normalise(_pipe);
}
function add2(left, right) {
  let _pipe = new Duration(
    left.seconds + right.seconds,
    left.nanoseconds + right.nanoseconds
  );
  return normalise(_pipe);
}
function seconds(amount) {
  return new Duration(amount, 0);
}
function nanoseconds(amount) {
  let _pipe = new Duration(0, amount);
  return normalise(_pipe);
}
function to_seconds_and_nanoseconds(duration) {
  return [duration.seconds, duration.nanoseconds];
}

// build/dev/javascript/gtempo/gtempo/internal.mjs
var day_microseconds = 864e8;
function imprecise_days(days2) {
  return days2 * day_microseconds;
}
function as_days_imprecise(microseconds2) {
  return divideInt(microseconds2, day_microseconds);
}

// build/dev/javascript/gtempo/tempo_ffi.mjs
var speedup = 1;
var referenceTime = 0;
var referenceStart = 0;
var referenceMonotonicStart = 0;
var mockTime = false;
var freezeTime = false;
var warpTime = 0;
function warped_now() {
  return Date.now() * 1e3 + warpTime;
}
function warped_now_monotonic() {
  return Math.trunc(performance.now() * 1e3) + warpTime;
}
function now() {
  if (freezeTime) {
    return referenceTime + warpTime;
  } else if (mockTime) {
    let realElaposed = warped_now() - referenceStart;
    let spedupElapsed = Math.trunc(realElaposed * speedup);
    return referenceTime + spedupElapsed;
  }
  return warped_now();
}
function local_offset() {
  return -(/* @__PURE__ */ new Date()).getTimezoneOffset();
}
function now_monotonic() {
  if (freezeTime) {
    return referenceTime + warpTime;
  } else if (mockTime) {
    let realElapsed = warped_now_monotonic() - referenceMonotonicStart;
    let spedupElapsed = Math.trunc(realElapsed * speedup);
    return referenceTime + spedupElapsed;
  }
  return warped_now_monotonic();
}
var unique = 1;
function now_unique() {
  return unique++;
}

// build/dev/javascript/gtempo/tempo.mjs
var Instant = class extends CustomType {
  constructor(timestamp_utc_us, offset_local_us, monotonic_us, unique2) {
    super();
    this.timestamp_utc_us = timestamp_utc_us;
    this.offset_local_us = offset_local_us;
    this.monotonic_us = monotonic_us;
    this.unique = unique2;
  }
};
var DateTime = class extends CustomType {
  constructor(date, time, offset2) {
    super();
    this.date = date;
    this.time = time;
    this.offset = offset2;
  }
};
var NaiveDateTime = class extends CustomType {
  constructor(date, time) {
    super();
    this.date = date;
    this.time = time;
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
var TimeOfDay2 = class extends CustomType {
  constructor(microseconds2) {
    super();
    this.microseconds = microseconds2;
  }
};
var LastInstantOfDay = class extends CustomType {
};
var EndOfDayLeapSecond = class extends CustomType {
  constructor(microseconds2) {
    super();
    this.microseconds = microseconds2;
  }
};
function datetime(date, time, offset2) {
  return new DateTime(date, time, offset2);
}
function datetime_drop_offset(datetime2) {
  return new NaiveDateTime(datetime2.date, datetime2.time);
}
function naive_datetime_get_date(naive_datetime2) {
  return naive_datetime2.date;
}
function naive_datetime_get_time(naive_datetime2) {
  return naive_datetime2.time;
}
function date_from_unix_seconds(unix_ts) {
  return new Date3(divideInt(unix_ts, 86400));
}
function date_from_unix_micro(unix_micro) {
  return new Date3(divideInt(unix_micro, day_microseconds));
}
function instant_as_utc_date(instant) {
  return date_from_unix_micro(instant.timestamp_utc_us);
}
function date_to_unix_seconds(date) {
  return date.unix_days * 86400;
}
function date_add(date, days2) {
  return new Date3(date.unix_days + days2);
}
function date_subtract(date, days2) {
  return new Date3(date.unix_days - days2);
}
function time_normalise(time) {
  if (time instanceof TimeOfDay2 && time.microseconds < 0) {
    let microseconds2 = time.microseconds;
    return new TimeOfDay2(
      day_microseconds + remainderInt(
        microseconds2,
        day_microseconds
      )
    );
  } else if (time instanceof TimeOfDay2 && time.microseconds >= day_microseconds) {
    let microseconds2 = time.microseconds;
    return new TimeOfDay2(remainderInt(microseconds2, day_microseconds));
  } else {
    return time;
  }
}
function time_from_microseconds(microseconds2) {
  return new TimeOfDay2(microseconds2);
}
function time_to_microseconds(time) {
  let $ = time_normalise(time);
  if ($ instanceof TimeOfDay2) {
    let microseconds2 = $.microseconds;
    return microseconds2;
  } else if ($ instanceof LastInstantOfDay) {
    return day_microseconds;
  } else {
    let microsecond = $.microseconds;
    return day_microseconds + microsecond;
  }
}
function time_from_unix_micro(unix_ts) {
  return time_from_microseconds(remainderInt(unix_ts, day_microseconds));
}
function instant_as_utc_time(instant) {
  return time_from_unix_micro(instant.timestamp_utc_us);
}
function duration_microseconds(microseconds2) {
  return nanoseconds(microseconds2 * 1e3);
}
function offset_to_duration(offset2) {
  let _pipe = -offset2.minutes * 6e7;
  return duration_microseconds(_pipe);
}
function time_to_duration(time) {
  let _pipe = time_to_microseconds(time);
  return duration_microseconds(_pipe);
}
function duration_get_microseconds(duration) {
  let $ = to_seconds_and_nanoseconds(duration);
  let seconds3 = $[0];
  let nanoseconds2 = $[1];
  return seconds3 * 1e6 + divideInt(nanoseconds2, 1e3);
}
function time_add(a, b) {
  let b_microseconds = duration_get_microseconds(b);
  let $ = b_microseconds === 0;
  if ($) {
    return a;
  } else {
    if (a instanceof EndOfDayLeapSecond && b_microseconds + a.microseconds < 1e6) {
      let microsecond = a.microseconds;
      return new EndOfDayLeapSecond(microsecond + b_microseconds);
    } else if (a instanceof EndOfDayLeapSecond) {
      let _pipe = time_to_microseconds(a) + (b_microseconds - 1e6);
      let _pipe$1 = time_from_microseconds(_pipe);
      return time_normalise(_pipe$1);
    } else {
      let _pipe = time_to_microseconds(a) + b_microseconds;
      let _pipe$1 = time_from_microseconds(_pipe);
      return time_normalise(_pipe$1);
    }
  }
}
function time_subtract(a, b) {
  let $ = duration_get_microseconds(b) === 0;
  if ($) {
    return a;
  } else {
    let _pipe = time_to_microseconds(a) - duration_get_microseconds(b);
    let _pipe$1 = time_from_microseconds(_pipe);
    return time_normalise(_pipe$1);
  }
}
function duration_seconds_and_nanoseconds(seconds3, nanoseconds2) {
  let _pipe = seconds(seconds3);
  return add2(_pipe, nanoseconds(nanoseconds2));
}
function duration_days(days2) {
  let _pipe = days2;
  let _pipe$1 = imprecise_days(_pipe);
  return duration_microseconds(_pipe$1);
}
function duration_increase(a, b) {
  return add2(a, b);
}
function duration_absolute(duration) {
  let $ = to_seconds_and_nanoseconds(duration);
  let seconds3 = $[0];
  let nanoseconds2 = $[1];
  let $1 = seconds3 >= 0 && nanoseconds2 >= 0;
  if ($1) {
    return duration;
  } else {
    let seconds$1 = (() => {
      let $2 = seconds3 < 0;
      if ($2) {
        return -seconds3;
      } else {
        return seconds3;
      }
    })();
    let nanoseconds$1 = (() => {
      let $2 = nanoseconds2 < 0;
      if ($2) {
        return -nanoseconds2;
      } else {
        return nanoseconds2;
      }
    })();
    return duration_seconds_and_nanoseconds(seconds$1, nanoseconds$1);
  }
}
function duration_inverse(dur) {
  return difference(dur, seconds(0));
}
function duration_decrease(a, b) {
  return add2(a, duration_inverse(b));
}
function duration_is_positive(dur) {
  let $ = to_seconds_and_nanoseconds(dur);
  let seconds3 = $[0];
  let nanoseconds2 = $[1];
  return seconds3 >= 0 && nanoseconds2 >= 0;
}
function duration_as_days(duration) {
  let _pipe = duration_get_microseconds(duration);
  return as_days_imprecise(_pipe);
}
function duration_as_microseconds(duration) {
  return duration_get_microseconds(duration);
}
function offset_local_micro() {
  return local_offset() * 6e7;
}
function now2() {
  return new Instant(
    now(),
    offset_local_micro(),
    now_monotonic(),
    now_unique()
  );
}
var utc = /* @__PURE__ */ new Offset(0);
function instant_as_utc_datetime(instant) {
  return new DateTime(
    instant_as_utc_date(instant),
    instant_as_utc_time(instant),
    utc
  );
}
function naive_datetime_subtract(datetime2, duration_to_subtract) {
  return lazy_guard(
    !duration_is_positive(duration_to_subtract),
    () => {
      let _pipe = datetime2;
      return naive_datetime_add(_pipe, duration_absolute(duration_to_subtract));
    },
    () => {
      let days_to_sub = duration_as_days(duration_to_subtract);
      let time_to_sub = duration_decrease(
        duration_to_subtract,
        duration_days(days_to_sub)
      );
      let new_time_as_micro = (() => {
        let _pipe = datetime2.time;
        let _pipe$1 = time_to_duration(_pipe);
        let _pipe$2 = duration_decrease(_pipe$1, time_to_sub);
        return duration_as_microseconds(_pipe$2);
      })();
      let $ = (() => {
        let $1 = new_time_as_micro < 0;
        if ($1) {
          return [new_time_as_micro + day_microseconds, days_to_sub + 1];
        } else {
          return [new_time_as_micro, days_to_sub];
        }
      })();
      let new_time_as_micro$1 = $[0];
      let days_to_sub$1 = $[1];
      let time_to_sub$1 = duration_microseconds(
        time_to_microseconds(datetime2.time) - new_time_as_micro$1
      );
      let new_date$1 = (() => {
        let _pipe = datetime2.date;
        return date_subtract(_pipe, days_to_sub$1);
      })();
      let new_time$1 = (() => {
        let _pipe = datetime2.time;
        return time_subtract(_pipe, time_to_sub$1);
      })();
      return new NaiveDateTime(new_date$1, new_time$1);
    }
  );
}
function naive_datetime_add(datetime2, duration_to_add) {
  return lazy_guard(
    !duration_is_positive(duration_to_add),
    () => {
      let _pipe = datetime2;
      return naive_datetime_subtract(_pipe, duration_absolute(duration_to_add));
    },
    () => {
      let days_to_add = duration_as_days(duration_to_add);
      let time_to_add = duration_decrease(
        duration_to_add,
        duration_days(days_to_add)
      );
      let new_time_as_micro = (() => {
        let _pipe = datetime2.time;
        let _pipe$1 = time_to_duration(_pipe);
        let _pipe$2 = duration_increase(_pipe$1, time_to_add);
        return duration_as_microseconds(_pipe$2);
      })();
      let $ = (() => {
        let $1 = new_time_as_micro >= day_microseconds;
        if ($1) {
          return [new_time_as_micro - day_microseconds, days_to_add + 1];
        } else {
          return [new_time_as_micro, days_to_add];
        }
      })();
      let new_time_as_micro$1 = $[0];
      let days_to_add$1 = $[1];
      let time_to_add$1 = duration_microseconds(
        new_time_as_micro$1 - time_to_microseconds(datetime2.time)
      );
      let new_date$1 = (() => {
        let _pipe = datetime2.date;
        return date_add(_pipe, days_to_add$1);
      })();
      let new_time$1 = (() => {
        let _pipe = datetime2.time;
        return time_add(_pipe, time_to_add$1);
      })();
      return new NaiveDateTime(new_date$1, new_time$1);
    }
  );
}
function datetime_apply_offset(datetime2) {
  let applied = (() => {
    let _pipe = datetime2;
    let _pipe$1 = datetime_drop_offset(_pipe);
    return naive_datetime_add(_pipe$1, offset_to_duration(datetime2.offset));
  })();
  return new NaiveDateTime(applied.date, applied.time);
}

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
function apply_offset(datetime2) {
  return datetime_apply_offset(datetime2);
}
function to_unix_milli2(datetime2) {
  let utc_dt = (() => {
    let _pipe = datetime2;
    return apply_offset(_pipe);
  })();
  return to_unix_milli(
    (() => {
      let _pipe = utc_dt;
      return naive_datetime_get_date(_pipe);
    })()
  ) + divideInt(
    time_to_microseconds(
      (() => {
        let _pipe = utc_dt;
        return naive_datetime_get_time(_pipe);
      })()
    ),
    1e3
  );
}

// build/dev/javascript/gtempo/tempo/instant.mjs
function now3() {
  return now2();
}
function as_utc_datetime(instant) {
  return instant_as_utc_datetime(instant);
}

// build/dev/javascript/lustre/lustre/element/html.mjs
function text2(content) {
  return text(content);
}
function style2(attrs, css) {
  return element("style", attrs, toList([text2(css)]));
}
function div(attrs, children2) {
  return element("div", attrs, children2);
}
function hr(attrs) {
  return element("hr", attrs, toList([]));
}
function p(attrs, children2) {
  return element("p", attrs, children2);
}
function br(attrs) {
  return element("br", attrs, toList([]));
}
function span(attrs, children2) {
  return element("span", attrs, children2);
}
function button(attrs, children2) {
  return element("button", attrs, children2);
}
function input(attrs) {
  return element("input", attrs, toList([]));
}
function textarea(attrs, content) {
  return element("textarea", attrs, toList([text(content)]));
}

// build/dev/javascript/lustre/lustre/event.mjs
function emit2(event2, data) {
  return event(event2, data);
}
function on2(name2, handler) {
  return on(name2, handler);
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
function value2(event2) {
  let _pipe = event2;
  return field("target", field("value", string))(
    _pipe
  );
}
function on_input(msg) {
  return on2(
    "input",
    (event2) => {
      let _pipe = value2(event2);
      return map3(_pipe, msg);
    }
  );
}

// build/dev/javascript/o11a_common/o11a/components.mjs
var line_discussion = "line-discussion";

// build/dev/javascript/o11a_common/o11a/events.mjs
var user_submitted_note = "user-submitted-line-note";
var user_clicked_discussion_preview = "user-clicked-discussion-preview";
var user_focused_input = "user-focused-input";
var user_unfocused_input = "user-unfocused-input";

// build/dev/javascript/o11a_common/o11a/note.mjs
var Note = class extends CustomType {
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
var Comment = class extends CustomType {
};
var Question = class extends CustomType {
};
var Answer = class extends CustomType {
};
var ToDo = class extends CustomType {
};
var ToDoDone = class extends CustomType {
};
var FindingLead = class extends CustomType {
};
var FindingConfirmation = class extends CustomType {
};
var FindingRejection = class extends CustomType {
};
var DevelperQuestion = class extends CustomType {
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
  } else if (note_significance instanceof ToDoDone) {
    return 5;
  } else if (note_significance instanceof FindingLead) {
    return 6;
  } else if (note_significance instanceof FindingConfirmation) {
    return 7;
  } else if (note_significance instanceof FindingRejection) {
    return 8;
  } else {
    return 9;
  }
}
function significance_to_string(note_significance, thread_notes) {
  if (note_significance instanceof Comment) {
    return new None();
  } else if (note_significance instanceof Question) {
    let $ = find2(
      thread_notes,
      (thread_note) => {
        return isEqual(thread_note.significance, new Answer());
      }
    );
    if ($.isOk()) {
      return new Some("Answered");
    } else {
      return new Some("Unanswered");
    }
  } else if (note_significance instanceof DevelperQuestion) {
    let $ = find2(
      thread_notes,
      (thread_note) => {
        return isEqual(thread_note.significance, new Answer());
      }
    );
    if ($.isOk()) {
      return new Some("Answered");
    } else {
      return new Some("Dev Question");
    }
  } else if (note_significance instanceof Answer) {
    return new Some("Answer");
  } else if (note_significance instanceof ToDo) {
    let $ = find2(
      thread_notes,
      (thread_note) => {
        return isEqual(thread_note.significance, new ToDoDone());
      }
    );
    if ($.isOk()) {
      return new Some("Completed");
    } else {
      return new Some("ToDo");
    }
  } else if (note_significance instanceof ToDoDone) {
    return new Some("Completion");
  } else if (note_significance instanceof FindingLead) {
    let $ = find_map(
      thread_notes,
      (thread_note) => {
        let $1 = thread_note.significance;
        if ($1 instanceof FindingRejection) {
          return new Ok(new FindingRejection());
        } else if ($1 instanceof FindingConfirmation) {
          return new Ok(new FindingConfirmation());
        } else {
          return new Error(void 0);
        }
      }
    );
    if ($.isOk() && $[0] instanceof FindingRejection) {
      return new Some("Rejected");
    } else if ($.isOk() && $[0] instanceof FindingConfirmation) {
      return new Some("Confirmed");
    } else if ($.isOk()) {
      return new Some("Unconfirmed");
    } else {
      return new Some("Unconfirmed");
    }
  } else if (note_significance instanceof FindingConfirmation) {
    return new Some("Confirmation");
  } else {
    return new Some("Rejection");
  }
}
function note_significance_from_int(note_significance) {
  if (note_significance === 1) {
    return new Comment();
  } else if (note_significance === 2) {
    return new Question();
  } else if (note_significance === 3) {
    return new Answer();
  } else if (note_significance === 4) {
    return new ToDo();
  } else if (note_significance === 5) {
    return new ToDoDone();
  } else if (note_significance === 6) {
    return new FindingLead();
  } else if (note_significance === 7) {
    return new FindingConfirmation();
  } else if (note_significance === 8) {
    return new FindingRejection();
  } else if (note_significance === 9) {
    return new DevelperQuestion();
  } else {
    throw makeError(
      "panic",
      "o11a/note",
      120,
      "note_significance_from_int",
      "Invalid note significance found",
      {}
    );
  }
}
function encode_note(note) {
  return object2(
    toList([
      ["note_id", string4(note.note_id)],
      ["parent_id", string4(note.parent_id)],
      [
        "significance",
        int3(
          (() => {
            let _pipe = note.significance;
            return note_significance_to_int(_pipe);
          })()
        )
      ],
      ["user_name", string4(note.user_name)],
      ["message", string4(note.message)],
      ["expanded_message", nullable(note.expanded_message, string4)],
      [
        "time",
        int3(
          (() => {
            let _pipe = note.time;
            return to_unix_milli2(_pipe);
          })()
        )
      ],
      ["edited", bool2(note.edited)]
    ])
  );
}
function note_decoder() {
  return field2(
    "note_id",
    string3,
    (note_id) => {
      return field2(
        "parent_id",
        string3,
        (parent_id) => {
          return field2(
            "significance",
            int2,
            (significance) => {
              return field2(
                "user_name",
                string3,
                (user_name) => {
                  return field2(
                    "message",
                    string3,
                    (message) => {
                      return field2(
                        "expanded_message",
                        optional(string3),
                        (expanded_message) => {
                          return field2(
                            "time",
                            int2,
                            (time) => {
                              return field2(
                                "edited",
                                bool,
                                (edited) => {
                                  let _pipe = new Note(
                                    note_id,
                                    parent_id,
                                    note_significance_from_int(significance),
                                    user_name,
                                    message,
                                    expanded_message,
                                    from_unix_milli3(time),
                                    edited
                                  );
                                  return success(_pipe);
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
function structured_note_decoder() {
  return field2(
    "note_id",
    string3,
    (note_id) => {
      return field2(
        "thread_notes",
        list2(note_decoder()),
        (thread_notes) => {
          let _pipe = [note_id, thread_notes];
          return success(_pipe);
        }
      );
    }
  );
}
function decode_structured_notes(notes) {
  return try$(
    run(notes, string3),
    (notes2) => {
      let _pipe = parse(notes2, list2(structured_note_decoder()));
      return replace_error(
        _pipe,
        toList([
          new DecodeError2(
            "json-encoded note",
            inspect2(notes2),
            toList([])
          )
        ])
      );
    }
  );
}

// build/dev/javascript/o11a_client/lib/eventx.mjs
function on_ctrl_enter(msg) {
  return on2(
    "keydown",
    (event2) => {
      let decoder = field2(
        "ctrlKey",
        bool,
        (ctrl_key) => {
          return field2(
            "key",
            string3,
            (key) => {
              return success([ctrl_key, key]);
            }
          );
        }
      );
      let empty_error = toList([new DecodeError("", "", toList([]))]);
      return try$(
        (() => {
          let _pipe = run(event2, decoder);
          return replace_error(_pipe, empty_error);
        })(),
        (_use0) => {
          let ctrl_key = _use0[0];
          let key = _use0[1];
          if (ctrl_key && key === "Enter") {
            return new Ok(msg);
          } else {
            return new Error(empty_error);
          }
        }
      );
    }
  );
}

// build/dev/javascript/lustre/lustre/element/svg.mjs
var namespace = "http://www.w3.org/2000/svg";
function svg(attrs, children2) {
  return namespaced(namespace, "svg", attrs, children2);
}
function path(attrs) {
  return namespaced(namespace, "path", attrs, toList([]));
}

// build/dev/javascript/o11a_client/lib/lucide.mjs
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

// build/dev/javascript/o11a_client/o11a/ui/line_discussion.mjs
var Model2 = class extends CustomType {
  constructor(user_name, line_number, line_id, line_text, line_tag, line_number_text, keep_notes_open, notes, current_note_draft, current_thread_id, current_thread_notes, active_thread, show_expanded_message_box, current_expanded_message_draft, expanded_messages) {
    super();
    this.user_name = user_name;
    this.line_number = line_number;
    this.line_id = line_id;
    this.line_text = line_text;
    this.line_tag = line_tag;
    this.line_number_text = line_number_text;
    this.keep_notes_open = keep_notes_open;
    this.notes = notes;
    this.current_note_draft = current_note_draft;
    this.current_thread_id = current_thread_id;
    this.current_thread_notes = current_thread_notes;
    this.active_thread = active_thread;
    this.show_expanded_message_box = show_expanded_message_box;
    this.current_expanded_message_draft = current_expanded_message_draft;
    this.expanded_messages = expanded_messages;
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
var ServerSetLineId = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var ServerSetLineNumber = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var ServerSetLineText = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var ServerUpdatedNotes = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
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
var UserToggledKeepNotesOpen = class extends CustomType {
};
var UserToggledCloseNotes = class extends CustomType {
};
var UserEnteredDiscussionPreview = class extends CustomType {
};
var UserFocusedInput = class extends CustomType {
};
var UserFocusedExpandedInput = class extends CustomType {
};
var UserUnfocusedInput = class extends CustomType {
};
function init2(_) {
  return [
    new Model2(
      "guest",
      0,
      "",
      "",
      "",
      "",
      false,
      new_map(),
      "",
      "",
      toList([]),
      new None(),
      false,
      new None(),
      new$2()
    ),
    none()
  ];
}
function inline_comment_preview_view(model) {
  let _pipe = map_get(model.notes, model.line_id);
  let _pipe$1 = try$(_pipe, first);
  let _pipe$2 = map3(
    _pipe$1,
    (note) => {
      return span(
        toList([
          class$("select-none italic comment font-code fade-in"),
          class$("comment-preview"),
          id("discussion-entry"),
          attribute("tabindex", "0"),
          on_click(new UserEnteredDiscussionPreview()),
          style(
            toList([
              ["animation-delay", to_string(model.line_number * 4) + "ms"]
            ])
          )
        ]),
        toList([
          text2(
            (() => {
              let $ = string_length(note.message) > 40;
              if ($) {
                return (() => {
                  let _pipe$22 = note.message;
                  return slice(_pipe$22, 0, 37);
                })() + "...";
              } else {
                let _pipe$22 = note.message;
                return slice(_pipe$22, 0, 40);
              }
            })()
          )
        ])
      );
    }
  );
  return unwrap2(
    _pipe$2,
    span(
      toList([
        class$("select-none italic comment"),
        class$("new-thread-preview"),
        id("discussion-entry"),
        attribute("tabindex", "0"),
        on_click(new UserEnteredDiscussionPreview())
      ]),
      toList([text2("Start new thread")])
    )
  );
}
function thread_header_view(model) {
  let $ = model.active_thread;
  if ($ instanceof Some) {
    let active_thread = $[0];
    return div(
      toList([]),
      toList([
        button(
          toList([on_click(new UserClosedThread())]),
          toList([text2("Close Thread")])
        ),
        br(toList([])),
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
    return fragment(toList([]));
  }
}
function significance_badge_view(model, note) {
  let badge_style = "input-border rounded-md text-[0.65rem] pb-[0.15rem] pt-1 px-[0.5rem]";
  let $ = significance_to_string(
    note.significance,
    (() => {
      let _pipe = map_get(model.notes, note.note_id);
      return unwrap2(_pipe, toList([]));
    })()
  );
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
function comments_view(model) {
  return map2(
    model.current_thread_notes,
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
                  significance_badge_view(model, note)
                ])
              ),
              div(
                toList([class$("flex gap-[.5rem]")]),
                toList([
                  (() => {
                    let $ = note.expanded_message;
                    if ($ instanceof Some) {
                      return button(
                        toList([
                          id("expand-message-button"),
                          class$("icon-button"),
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
                  button(
                    toList([
                      id("switch-thread-button"),
                      class$("icon-button"),
                      on_click(
                        new UserSwitchedToThread(note.note_id, note)
                      )
                    ]),
                    toList([messages_square(toList([]))])
                  )
                ])
              )
            ])
          ),
          p(toList([]), toList([text2(note.message)])),
          (() => {
            let $ = contains(model.expanded_messages, note.note_id);
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
function new_message_input_view(model) {
  return div(
    toList([class$("flex justify-between items-center gap-[.35rem]")]),
    toList([
      button(
        toList([
          id("toggle-expanded-message-button"),
          class$("icon-button"),
          on_click(
            new UserToggledExpandedMessageBox(!model.show_expanded_message_box)
          )
        ]),
        toList([pencil_ruler(toList([]))])
      ),
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
          on_ctrl_enter(new UserSubmittedNote()),
          value(model.current_note_draft)
        ])
      )
    ])
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
function discussion_overlay_view(model) {
  return div(
    toList([
      id("line-discussion-overlay"),
      class$(
        "absolute z-[3] w-[30rem] invisible not-italic text-wrap select-text left-[-.3rem] bottom-[1.4rem]"
      ),
      on_click(new UserToggledKeepNotesOpen())
    ]),
    toList([
      div(
        toList([class$("overlay p-[.5rem]")]),
        toList([
          (() => {
            let $ = is_some(model.active_thread) || length(
              model.current_thread_notes
            ) > 0;
            if ($) {
              return div(
                toList([
                  id("comment-list"),
                  class$(
                    "flex flex-col-reverse overflow-auto max-h-[30rem] gap-[.5rem] mb-[.5rem]"
                  )
                ]),
                toList([
                  fragment(comments_view(model)),
                  thread_header_view(model)
                ])
              );
            } else {
              return fragment(toList([]));
            }
          })(),
          new_message_input_view(model)
        ])
      ),
      expanded_message_view(model)
    ])
  );
}
function classify_message(message, is_thread_open) {
  if (!is_thread_open) {
    if (message.startsWith("todo ")) {
      let rest = message.slice(5);
      return [new ToDo(), rest];
    } else if (message.startsWith("todo: ")) {
      let rest = message.slice(6);
      return [new ToDo(), rest];
    } else if (message.startsWith("? ")) {
      let rest = message.slice(2);
      return [new Question(), rest];
    } else if (message.startsWith("! ")) {
      let rest = message.slice(2);
      return [new FindingLead(), rest];
    } else if (message.startsWith("@dev ")) {
      let rest = message.slice(5);
      return [new DevelperQuestion(), rest];
    } else {
      return [new Comment(), message];
    }
  } else {
    if (message.startsWith("done ")) {
      let rest = message.slice(5);
      return [new ToDoDone(), rest];
    } else if (message === "done") {
      return [new ToDoDone(), "done"];
    } else if (message.startsWith(": ")) {
      let rest = message.slice(2);
      return [new Answer(), rest];
    } else if (message.startsWith(". ")) {
      let rest = message.slice(2);
      return [new FindingRejection(), rest];
    } else if (message.startsWith("!! ")) {
      let rest = message.slice(3);
      return [new FindingConfirmation(), rest];
    } else {
      return [new Comment(), message];
    }
  }
}
function update(model, msg) {
  if (msg instanceof ServerSetLineId) {
    let line_id = msg[0];
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_name,
          _record.line_number,
          line_id,
          _record.line_text,
          _record.line_tag,
          _record.line_number_text,
          _record.keep_notes_open,
          _record.notes,
          _record.current_note_draft,
          line_id,
          (() => {
            let _pipe = map_get(model.notes, line_id);
            return unwrap2(_pipe, toList([]));
          })(),
          _record.active_thread,
          _record.show_expanded_message_box,
          _record.current_expanded_message_draft,
          _record.expanded_messages
        );
      })(),
      none()
    ];
  } else if (msg instanceof ServerSetLineNumber) {
    let line_number = msg[0];
    let line_number_text = to_string(line_number);
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_name,
          line_number,
          _record.line_id,
          _record.line_text,
          "L" + line_number_text,
          line_number_text,
          _record.keep_notes_open,
          _record.notes,
          _record.current_note_draft,
          _record.current_thread_id,
          _record.current_thread_notes,
          _record.active_thread,
          _record.show_expanded_message_box,
          _record.current_expanded_message_draft,
          _record.expanded_messages
        );
      })(),
      none()
    ];
  } else if (msg instanceof ServerSetLineText) {
    let line_text = msg[0];
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_name,
          _record.line_number,
          _record.line_id,
          line_text,
          _record.line_tag,
          _record.line_number_text,
          _record.keep_notes_open,
          _record.notes,
          _record.current_note_draft,
          _record.current_thread_id,
          _record.current_thread_notes,
          _record.active_thread,
          _record.show_expanded_message_box,
          _record.current_expanded_message_draft,
          _record.expanded_messages
        );
      })(),
      none()
    ];
  } else if (msg instanceof ServerUpdatedNotes) {
    let notes = msg[0];
    let updated_notes = from_list(notes);
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_name,
          _record.line_number,
          _record.line_id,
          _record.line_text,
          _record.line_tag,
          _record.line_number_text,
          _record.keep_notes_open,
          updated_notes,
          _record.current_note_draft,
          _record.current_thread_id,
          (() => {
            let _pipe = map_get(updated_notes, model.current_thread_id);
            return unwrap2(_pipe, toList([]));
          })(),
          _record.active_thread,
          _record.show_expanded_message_box,
          _record.current_expanded_message_draft,
          _record.expanded_messages
        );
      })(),
      none()
    ];
  } else if (msg instanceof UserWroteNote) {
    let draft = msg[0];
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_name,
          _record.line_number,
          _record.line_id,
          _record.line_text,
          _record.line_tag,
          _record.line_number_text,
          _record.keep_notes_open,
          _record.notes,
          draft,
          _record.current_thread_id,
          _record.current_thread_notes,
          _record.active_thread,
          _record.show_expanded_message_box,
          _record.current_expanded_message_draft,
          _record.expanded_messages
        );
      })(),
      none()
    ];
  } else if (msg instanceof UserSubmittedNote) {
    return that(
      model.current_note_draft === "",
      () => {
        return [model, none()];
      },
      () => {
        let now4 = (() => {
          let _pipe = now3();
          return as_utc_datetime(_pipe);
        })();
        let note_id = model.user_name + (() => {
          let _pipe = now4;
          let _pipe$1 = to_unix_milli2(_pipe);
          return to_string(_pipe$1);
        })();
        let $ = classify_message(
          model.current_note_draft,
          is_some(model.active_thread)
        );
        let significance = $[0];
        let message = $[1];
        let note = new Note(
          note_id,
          model.current_thread_id,
          significance,
          "user" + (() => {
            let _pipe = random(100);
            return to_string(_pipe);
          })(),
          message,
          model.current_expanded_message_draft,
          now4,
          false
        );
        return [
          (() => {
            let _record = model;
            return new Model2(
              _record.user_name,
              _record.line_number,
              _record.line_id,
              _record.line_text,
              _record.line_tag,
              _record.line_number_text,
              _record.keep_notes_open,
              _record.notes,
              "",
              _record.current_thread_id,
              _record.current_thread_notes,
              _record.active_thread,
              false,
              new None(),
              _record.expanded_messages
            );
          })(),
          emit2(user_submitted_note, encode_note(note))
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
          _record.user_name,
          _record.line_number,
          _record.line_id,
          _record.line_text,
          _record.line_tag,
          _record.line_number_text,
          _record.keep_notes_open,
          _record.notes,
          _record.current_note_draft,
          new_thread_id,
          (() => {
            let _pipe = map_get(model.notes, new_thread_id);
            return unwrap2(_pipe, toList([]));
          })(),
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
          _record.expanded_messages
        );
      })(),
      none()
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
      return unwrap(_pipe, model.line_id);
    })();
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_name,
          _record.line_number,
          _record.line_id,
          _record.line_text,
          _record.line_tag,
          _record.line_number_text,
          _record.keep_notes_open,
          _record.notes,
          _record.current_note_draft,
          new_current_thread_id,
          (() => {
            let _pipe = map_get(model.notes, new_current_thread_id);
            return unwrap2(_pipe, toList([]));
          })(),
          new_active_thread,
          _record.show_expanded_message_box,
          _record.current_expanded_message_draft,
          _record.expanded_messages
        );
      })(),
      none()
    ];
  } else if (msg instanceof UserToggledExpandedMessageBox) {
    let show_expanded_message_box = msg[0];
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_name,
          _record.line_number,
          _record.line_id,
          _record.line_text,
          _record.line_tag,
          _record.line_number_text,
          _record.keep_notes_open,
          _record.notes,
          _record.current_note_draft,
          _record.current_thread_id,
          _record.current_thread_notes,
          _record.active_thread,
          show_expanded_message_box,
          _record.current_expanded_message_draft,
          _record.expanded_messages
        );
      })(),
      none()
    ];
  } else if (msg instanceof UserWroteExpandedMessage) {
    let expanded_message = msg[0];
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_name,
          _record.line_number,
          _record.line_id,
          _record.line_text,
          _record.line_tag,
          _record.line_number_text,
          _record.keep_notes_open,
          _record.notes,
          _record.current_note_draft,
          _record.current_thread_id,
          _record.current_thread_notes,
          _record.active_thread,
          _record.show_expanded_message_box,
          new Some(expanded_message),
          _record.expanded_messages
        );
      })(),
      none()
    ];
  } else if (msg instanceof UserToggledExpandedMessage) {
    let for_note_id = msg.for_note_id;
    let $ = contains(model.expanded_messages, for_note_id);
    if ($) {
      return [
        (() => {
          let _record = model;
          return new Model2(
            _record.user_name,
            _record.line_number,
            _record.line_id,
            _record.line_text,
            _record.line_tag,
            _record.line_number_text,
            _record.keep_notes_open,
            _record.notes,
            _record.current_note_draft,
            _record.current_thread_id,
            _record.current_thread_notes,
            _record.active_thread,
            _record.show_expanded_message_box,
            _record.current_expanded_message_draft,
            delete$2(model.expanded_messages, for_note_id)
          );
        })(),
        none()
      ];
    } else {
      return [
        (() => {
          let _record = model;
          return new Model2(
            _record.user_name,
            _record.line_number,
            _record.line_id,
            _record.line_text,
            _record.line_tag,
            _record.line_number_text,
            _record.keep_notes_open,
            _record.notes,
            _record.current_note_draft,
            _record.current_thread_id,
            _record.current_thread_notes,
            _record.active_thread,
            _record.show_expanded_message_box,
            _record.current_expanded_message_draft,
            insert2(model.expanded_messages, for_note_id)
          );
        })(),
        none()
      ];
    }
  } else if (msg instanceof UserToggledKeepNotesOpen) {
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_name,
          _record.line_number,
          _record.line_id,
          _record.line_text,
          _record.line_tag,
          _record.line_number_text,
          true,
          _record.notes,
          _record.current_note_draft,
          _record.current_thread_id,
          _record.current_thread_notes,
          _record.active_thread,
          _record.show_expanded_message_box,
          _record.current_expanded_message_draft,
          _record.expanded_messages
        );
      })(),
      none()
    ];
  } else if (msg instanceof UserToggledCloseNotes) {
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_name,
          _record.line_number,
          _record.line_id,
          _record.line_text,
          _record.line_tag,
          _record.line_number_text,
          false,
          _record.notes,
          _record.current_note_draft,
          _record.current_thread_id,
          _record.current_thread_notes,
          _record.active_thread,
          _record.show_expanded_message_box,
          _record.current_expanded_message_draft,
          _record.expanded_messages
        );
      })(),
      none()
    ];
  } else if (msg instanceof UserEnteredDiscussionPreview) {
    return [
      model,
      emit2(
        user_clicked_discussion_preview,
        object2(
          toList([
            ["line_number", int3(model.line_number)],
            ["discussion_lane", int3(1)]
          ])
        )
      )
    ];
  } else if (msg instanceof UserFocusedInput) {
    return [
      model,
      emit2(
        user_focused_input,
        object2(
          toList([
            ["line_number", int3(model.line_number)],
            ["discussion_lane", int3(1)]
          ])
        )
      )
    ];
  } else if (msg instanceof UserFocusedExpandedInput) {
    return [
      (() => {
        let _record = model;
        return new Model2(
          _record.user_name,
          _record.line_number,
          _record.line_id,
          _record.line_text,
          _record.line_tag,
          _record.line_number_text,
          _record.keep_notes_open,
          _record.notes,
          _record.current_note_draft,
          _record.current_thread_id,
          _record.current_thread_notes,
          _record.active_thread,
          true,
          _record.current_expanded_message_draft,
          _record.expanded_messages
        );
      })(),
      emit2(
        user_focused_input,
        object2(
          toList([
            ["line_number", int3(model.line_number)],
            ["discussion_lane", int3(1)]
          ])
        )
      )
    ];
  } else {
    return [
      model,
      emit2(
        user_unfocused_input,
        object2(
          toList([
            ["line_number", int3(model.line_number)],
            ["discussion_lane", int3(1)]
          ])
        )
      )
    ];
  }
}
var name = line_discussion;
var component_style = "\n:host {\n  display: inline-block;\n}\n\n/* Delay the overlay transitions by 1ms to they are done last, and any \n  actions on them can be done first (like focusing the input) */\n\n.new-thread-preview {\n  opacity: 0;\n  transition-property: opacity;\n  transition-delay: 1ms;\n}\n\n.comment-preview:focus,\n.new-thread-preview:focus {\n  outline: none;\n  text-decoration: underline;\n}\n\n#line-discussion-overlay {\n  visibility: hidden;\n  opacity: 0;\n  transition-property: opacity, visibility;\n  transition-delay: 1ms, 1ms;\n}\n\n#expanded-message {\n  visibility: hidden;\n  opacity: 0;\n  transition-property: opacity, visibility;\n  transition-delay: 1ms, 1ms;\n}\n\n/* When the new thread preview is hovered */\n\np.loc:hover .new-thread-preview {\n  opacity: 1;\n}\n\n#line-discussion-overlay.show-dis,\n.comment-preview:hover + #line-discussion-overlay {\n  visibility: visible;\n  opacity: 1;\n}\n\n.new-thread-preview:hover + #line-discussion-overlay #expanded-message.show-exp,\n.comment-preview:hover + #line-discussion-overlay #expanded-message.show-exp {\n  visibility: visible;\n  opacity: 1;\n  transition-property: opacity, visible;\n  transition-delay: 25ms, 25ms;\n}\n\n/* When the new thread preview is focused, immediately show the overlay to\n  provide snappy feedback. */\n\n.new-thread-preview:focus,\n.new-thread-preview:has(+ #line-discussion-overlay:hover),\n.new-thread-preview:has(+ #line-discussion-overlay:focus-within) {\n  opacity: 1;\n}\n\n.new-thread-preview:focus + #line-discussion-overlay,\n.comment-preview:focus + #line-discussion-overlay,\n#line-discussion-overlay:hover,\n#line-discussion-overlay:focus-within {\n  visibility: visible;\n  opacity: 1;\n}\n\n.new-thread-preview:focus + #line-discussion-overlay #expanded-message.show-exp,\n.comment-preview:focus + #line-discussion-overlay #expanded-message.show-exp,\n#line-discussion-overlay:hover #expanded-message.show-exp,\n#line-discussion-overlay:focus-within #expanded-message.show-exp,\n#expanded-message:hover,\n#expanded-message:focus-within {\n  visibility: visible;\n  opacity: 1;\n}\n\nbutton.icon-button {\n  background-color: var(--overlay-background-color);\n  color: var(--text-color);\n  border-radius: 4px;\n  border: none;\n  cursor: pointer;\n  padding: 0.3rem;\n}\n\nbutton.icon-button:hover {\n  background-color: var(--input-background-color);\n}\n\nbutton.icon-button svg {\n  height: 1.25rem;\n  width: 1.25rem;\n}\n\ninput, textarea {\n  background-color: var(--input-background-color);\n  color: var(--text-color);\n  border-radius: 6px;\n}\n\ninput, textarea {\n  border: 1px solid var(--input-border-color);\n}\n\nhr {\n  border: 1px solid var(--comment-color);\n}\n\n.overlay {\n  background-color: var(--overlay-background-color);\n  border: 1px solid var(--input-border-color);\n  border-radius: 6px;\n}\n\np.loc {\n  margin: 0;\n  white-space: pre;\n  height: 1.1875rem;\n  display: flex;\n  align-items: center;\n}\n\n.line-number {\n  display: inline-block;\n  margin-right: 1rem;\n  width: 2.5rem;\n  text-align: right;\n  flex-shrink: 0;\n}\n\n.inline-comment {\n  margin-left: 2.5rem;\n}\n\n.absolute {\n  position: absolute;\n}\n";
function view(model) {
  console_log("Rendering line discussion " + model.line_tag);
  return p(
    toList([
      class$("loc flex"),
      id(model.line_tag),
      on_mouse_enter(new UserEnteredDiscussionPreview())
    ]),
    toList([
      span(
        toList([class$("line-number code-extras")]),
        toList([text2(model.line_number_text)])
      ),
      span(
        toList([
          attribute("dangerous-unescaped-html", model.line_text)
        ]),
        toList([])
      ),
      span(
        toList([class$("inline-comment")]),
        toList([
          div(
            toList([
              id("line-discussion-container"),
              class$("relative font-code")
            ]),
            toList([
              style2(toList([]), component_style),
              inline_comment_preview_view(model),
              discussion_overlay_view(model)
            ])
          )
        ])
      )
    ])
  );
}
function component2() {
  return component(
    init2,
    update,
    view,
    from_list(
      toList([
        [
          "line-discussion",
          (dy) => {
            let $ = decode_structured_notes(dy);
            if ($.isOk()) {
              let notes = $[0];
              return new Ok(new ServerUpdatedNotes(notes));
            } else {
              return new Error(
                toList([
                  new DecodeError(
                    "line-discussion",
                    inspect2(dy),
                    toList([])
                  )
                ])
              );
            }
          }
        ],
        [
          "line-id",
          (dy) => {
            let $ = run(dy, string3);
            if ($.isOk()) {
              let line_id = $[0];
              return new Ok(new ServerSetLineId(line_id));
            } else {
              return new Error(
                toList([
                  new DecodeError(
                    "line-id",
                    inspect2(dy),
                    toList([])
                  )
                ])
              );
            }
          }
        ],
        [
          "line-number",
          (dy) => {
            let $ = run(dy, string3);
            if ($.isOk()) {
              let line_number = $[0];
              let $1 = parse_int(line_number);
              if ($1.isOk()) {
                let line_number$1 = $1[0];
                return new Ok(new ServerSetLineNumber(line_number$1));
              } else {
                return new Error(
                  toList([
                    new DecodeError(
                      "line-number",
                      line_number,
                      toList([])
                    )
                  ])
                );
              }
            } else {
              return new Error(
                toList([
                  new DecodeError(
                    "line-number",
                    inspect2(dy),
                    toList([])
                  )
                ])
              );
            }
          }
        ],
        [
          "line-text",
          (dy) => {
            let $ = run(dy, string3);
            if ($.isOk()) {
              let line_text = $[0];
              return new Ok(new ServerSetLineText(line_text));
            } else {
              return new Error(
                toList([
                  new DecodeError(
                    "line-text",
                    inspect2(dy),
                    toList([])
                  )
                ])
              );
            }
          }
        ]
      ])
    )
  );
}

// build/.lustre/entry.mjs
make_lustre_client_component(component2(), name);
